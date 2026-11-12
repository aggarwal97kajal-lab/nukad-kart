import 'dart:convert';
import 'package:archive/archive.dart';

/// Tiny .xlsx writer / reader (text and number cells only) — enough for the products sheet,
/// without a big Excel library (the usual one clashes with the image library this app needs).

String _esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

String _col(int i) {
  var n = i + 1, s = '';
  while (n > 0) {
    final r = (n - 1) % 26;
    s = String.fromCharCode(65 + r) + s;
    n = (n - 1) ~/ 26;
  }
  return s;
}

String _sheetXml(List<List<Object?>> rows) {
  final b = StringBuffer('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>');
  for (var r = 0; r < rows.length; r++) {
    b.write('<row r="${r + 1}">');
    for (var c = 0; c < rows[r].length; c++) {
      final v = rows[r][c];
      if (v == null || v == '') continue;
      final ref = '${_col(c)}${r + 1}';
      if (v is num) {
        b.write('<c r="$ref"><v>$v</v></c>');
      } else {
        b.write('<c r="$ref" t="inlineStr"><is><t xml:space="preserve">${_esc('$v')}</t></is></c>');
      }
    }
    b.write('</row>');
  }
  b.write('</sheetData></worksheet>');
  return b.toString();
}

/// Builds an .xlsx with the given sheets (name → rows).
List<int> buildXlsx(Map<String, List<List<Object?>>> sheets) {
  final names = sheets.keys.toList();
  final a = Archive();
  void add(String name, String text) {
    final bytes = utf8.encode(text);
    a.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  add('[Content_Types].xml', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
      '${[for (var i = 0; i < names.length; i++) '<Override PartName="/xl/worksheets/sheet${i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'].join()}'
      '</Types>');
  add('_rels/.rels', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
      '</Relationships>');
  add('xl/workbook.xml', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>'
      '${[for (var i = 0; i < names.length; i++) '<sheet name="${_esc(names[i])}" sheetId="${i + 1}" r:id="rId${i + 1}"/>'].join()}'
      '</sheets></workbook>');
  add('xl/_rels/workbook.xml.rels', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '${[for (var i = 0; i < names.length; i++) '<Relationship Id="rId${i + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${i + 1}.xml"/>'].join()}'
      '</Relationships>');
  for (var i = 0; i < names.length; i++) {
    add('xl/worksheets/sheet${i + 1}.xml', _sheetXml(sheets[names[i]]!));
  }
  return ZipEncoder().encode(a) as List<int>;
}

String _unesc(String s) => s
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAllMapped(RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.parse(m[1]!)))
    .replaceAll('&amp;', '&');

String? _file(Archive a, String name) {
  final f = a.findFile(name);
  if (f == null) return null;
  return utf8.decode((f.content as List).cast<int>(), allowMalformed: true);
}

int _colIndex(String ref) {
  var n = 0;
  for (final ch in ref.replaceAll(RegExp(r'\d'), '').codeUnits) {
    n = n * 26 + (ch - 64);
  }
  return n - 1;
}

/// Reads the first sheet (or the one named [prefer]) of an .xlsx as rows of text.
List<List<String>> readXlsx(List<int> bytes, {String prefer = 'Products'}) {
  final a = ZipDecoder().decodeBytes(bytes);
  final shared = <String>[];
  final ss = _file(a, 'xl/sharedStrings.xml');
  if (ss != null) {
    for (final si in RegExp(r'<si>([\s\S]*?)</si>').allMatches(ss)) {
      shared.add(_unesc(RegExp(r'<t[^>]*>([\s\S]*?)</t>').allMatches(si[1]!).map((m) => m[1]!).join()));
    }
  }
  // Which sheet file is "Products"? (workbook order → sheetN.xml in Excel-made files)
  var sheet = 'xl/worksheets/sheet1.xml';
  final wb = _file(a, 'xl/workbook.xml') ?? '';
  final names = RegExp(r'<sheet [^>]*name="([^"]*)"').allMatches(wb).map((m) => _unesc(m[1]!)).toList();
  final i = names.indexOf(prefer);
  if (i > 0 && a.findFile('xl/worksheets/sheet${i + 1}.xml') != null) sheet = 'xl/worksheets/sheet${i + 1}.xml';
  final xml = _file(a, sheet) ?? '';
  final out = <List<String>>[];
  for (final row in RegExp(r'<row[^>]*>([\s\S]*?)</row>').allMatches(xml)) {
    final cells = <String>[];
    for (final c in RegExp(r'<c ([^>]*?)(?:/>|>([\s\S]*?)</c>)').allMatches(row[1]!)) {
      final attrs = c[1]!, inner = c[2] ?? '';
      final ref = RegExp(r'r="([A-Z]+\d+)"').firstMatch(attrs)?[1];
      final type = RegExp(r't="(\w+)"').firstMatch(attrs)?[1] ?? 'n';
      String v;
      if (type == 's') {
        final k = int.tryParse(RegExp(r'<v>([\s\S]*?)</v>').firstMatch(inner)?[1] ?? '');
        v = k != null && k < shared.length ? shared[k] : '';
      } else if (type == 'inlineStr') {
        v = _unesc(RegExp(r'<t[^>]*>([\s\S]*?)</t>').allMatches(inner).map((m) => m[1]!).join());
      } else {
        v = _unesc(RegExp(r'<v>([\s\S]*?)</v>').firstMatch(inner)?[1] ?? '');
        final n = double.tryParse(v);
        if (n != null && n == n.roundToDouble() && !v.contains('E')) v = '${n.toInt()}';
      }
      final idx = ref == null ? cells.length : _colIndex(ref);
      while (cells.length < idx) {
        cells.add('');
      }
      cells.add(v.trim());
    }
    out.add(cells);
  }
  return out;
}
