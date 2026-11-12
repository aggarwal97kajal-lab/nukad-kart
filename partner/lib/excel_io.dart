import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'api.dart';
import 'xlsx_lite.dart';

/// Excel columns for products (same for a shop's own upload and an admin uploading for a shop).
const kExcelHeads = ['Name', 'Brand', 'Size', 'Category', 'MRP', 'Price', 'GST %', 'HSN', 'Barcode', 'Stock', 'Loose (Y/N)', 'Unit', 'Sizes'];

const _example = ['Parle-G Gold', 'Parle', '250 g', 'Bakery & biscuits', 30, 28, 5, '1905', '8901719110047', '', 'N', '', ''];
const _exampleLoose = ['Toor Dal', '', '', 'Atta, rice & dal', '', 160, 5, '0713', '', '', 'Y', 'kg', '250,500,1000'];

Future<void> _save(String name, Map<String, List<List<Object?>>> sheets) async {
  final bytes = buildXlsx(sheets);
  await FileSaver.instance.saveToDownloads(name: name, bytes: Uint8List.fromList(bytes), fileExtension: 'xlsx', mimeType: MimeType.microsoftExcel);
}

/// Blank sheet with headings, how-to notes, and one example of each kind.
Future<void> saveTemplate(List<String> categories) async {
  await _save('Nukad products template', {
    'Products': [kExcelHeads, _example, _exampleLoose],
    'How to fill': [
      for (final line in [
        'One product per row. Keep row 1 (the headings) as it is. Delete the 2 example rows.',
        'Packed item: Name, Size, Category, MRP and Price are needed. Price can’t be more than MRP.',
        'Loose item (sold by weight): Loose = Y, Unit = kg / litre / piece / dozen / bunch, Price is per kg / litre / piece, Sizes = what customers can buy, e.g. 250,500,1000 (grams).',
        'GST % and HSN are optional: if empty, the usual one for the category is used.',
        'Stock is optional: empty = not counted.',
        'Same barcode, or same name + size, updates the product that is already there.',
        'Categories: ${categories.join(' · ')}',
      ])
        [line],
    ],
  });
}

/// Picks an .xlsx and turns its rows into the server's product format ({row, …}). Null = cancelled.
Future<List<Map<String, dynamic>>?> pickRows() async {
  final f = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx'], withData: true);
  final bytes = f?.files.single.bytes;
  if (bytes == null) return null;
  final rows = readXlsx(bytes);
  if (rows.isEmpty) return [];
  final heads = rows.first.map((c) => c.toLowerCase()).toList();
  int col(String h) => heads.indexOf(h.toLowerCase());
  final out = <Map<String, dynamic>>[];
  for (var i = 1; i < rows.length; i++) {
    final r = rows[i];
    String v(String h) {
      final c = col(h);
      return c < 0 || c >= r.length ? '' : r[c];
    }
    if (v('Name').isEmpty) continue;
    final loose = v('Loose (Y/N)').toUpperCase().startsWith('Y');
    num? n(String h) => num.tryParse(v(h).replaceAll(',', '').replaceAll('₹', ''));
    out.add({
      'row': i + 1,
      'kind': loose ? 'loose' : 'packed',
      'name': v('Name'),
      'brand': v('Brand'),
      'size': v('Size'),
      'category': v('Category'),
      'mrp': n('MRP'),
      'price': n('Price'),
      if (v('GST %').isNotEmpty) 'gst': n('GST %'),
      'hsn': v('HSN'),
      'barcode': v('Barcode'),
      'stock': v('Stock').isEmpty ? null : n('Stock'),
      if (loose) 'unit': v('Unit').toLowerCase(),
      if (loose) 'options': v('Sizes').split(RegExp(r'[,; ]+')).map(int.tryParse).whereType<int>().toList(),
    });
  }
  return out;
}

/// The shop's products as an Excel file in Downloads (same columns, so it can be edited and uploaded back).
Future<int> exportProducts() async {
  final r = await api.call('GET', '/v1/partner/products?all=1');
  final list = ((r['products'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  final rows = <List<Object?>>[kExcelHeads];
  for (final p in list) {
    final loose = p['kind'] == 'loose';
    rows.add([
      p['name'], p['brand'], p['size'], p['category'], p['mrp'], p['price'], p['gst'], p['hsn'], p['barcode'], p['stock'],
      loose ? 'Y' : 'N', loose ? p['unit'] : '', loose ? (p['options'] as List).join(',') : '',
    ]);
  }
  await _save('Nukad products ${DateTime.now().toIso8601String().substring(0, 10)}', {'Products': rows});
  return list.length;
}

/// Human text for a bulk upload result.
String uploadSummary(Map<String, dynamic> r) {
  final errs = ((r['errors'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  final b = StringBuffer('Added ${r['added']} · updated ${r['updated']}');
  if (errs.isNotEmpty) {
    b.write('\n${r['errorCount']} rows skipped:');
    for (final e in errs.take(15)) {
      b.write('\nRow ${e['row']}: ${_why('${e['error']}')}');
    }
  }
  return b.toString();
}

String _why(String code) => switch (code) {
      'name_required' => 'name missing',
      'bad_category' => 'category not in the list',
      'fssai_needed' => 'food item needs your FSSAI number first',
      'bad_price' => 'price missing or wrong',
      'bad_mrp' => 'MRP wrong',
      'mrp_required' => 'MRP missing',
      'price_above_mrp' => 'price is more than MRP',
      'bad_gst' => 'GST must be 0, 5, 18 or 40',
      'bad_unit' => 'unit must be kg, litre, piece, dozen or bunch',
      'pick_sizes' => 'sizes missing or not allowed for this unit',
      'size_required' => 'size missing',
      'bad_stock' => 'stock must be a number',
      _ => code,
    };
