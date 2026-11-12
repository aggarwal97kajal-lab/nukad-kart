import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'screens/agreement.dart';

String _fileName(AgreementData d) => 'NukadKart_Agreement_${d.signed!['id']}.pdf';

/// Signed agreement as a PDF: both parties, full text, signature, name, date and reference.
Future<Uint8List> agreementPdf(AgreementData d) async {
  final regular = pw.Font.ttf(await rootBundle.load('assets/NotoSans-Regular.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('assets/NotoSans-Bold.ttf'));
  final s = d.signed!, p = d.party, v = d.vendor;
  final sig = pw.MemoryImage(base64Decode('${s['signature']}'));
  final green = PdfColor.fromInt(0xFF315426);
  final mute = PdfColor.fromInt(0xFF5E6A55);
  pw.TextStyle st(double size, {bool b = false, PdfColor? c}) => pw.TextStyle(font: b ? bold : regular, fontSize: size, color: c);

  pw.Widget row(String k, String val) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.SizedBox(width: 120, child: pw.Text(k, style: st(9, c: mute))),
          pw.Expanded(child: pw.Text(val.isEmpty ? '-' : val, style: st(9, b: true))),
        ]),
      );
  pw.Widget box(String title, List<pw.Widget> rows) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 8),
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColor.fromInt(0xFFDDDDDD)), borderRadius: pw.BorderRadius.circular(4)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(title, style: st(9.5, b: true, c: green)),
          pw.SizedBox(height: 4),
          ...rows,
        ]),
      );

  final paras = d.text.split(RegExp(r'\n\s*\n')).map((x) => x.trim()).where((x) => x.isNotEmpty);
  final doc = pw.Document(title: 'Nukad Kart Vendor Agreement ${s['id']}', author: 'Nukad Kart');
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 40),
    header: (ctx) => ctx.pageNumber == 1
        ? pw.SizedBox()
        : pw.Text('Nukad Kart · Vendor Agreement · Ref ${s['id']}', style: st(8, c: mute)),
    footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text('Signed electronically in the Nukad Partner app · ${s['id']}', style: st(7.5, c: mute)),
      pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: st(7.5, c: mute)),
    ]),
    build: (ctx) => [
      pw.Text('NUKAD KART', style: st(18, b: true, c: green)),
      pw.Text('Vendor Registration & Partnership Agreement', style: st(13, b: true)),
      pw.SizedBox(height: 4),
      pw.Text('Version ${s['version']} · Date ${s['date']} · Reference ${s['id']}', style: st(9, c: mute)),
      pw.SizedBox(height: 10),
      box('FIRST PARTY - PLATFORM OPERATOR', [
        row('Legal name', '${p['legalName']}'),
        row('Trading name', 'Nukad Kart'),
        row('Business constitution', 'Sole Proprietorship'),
        row('Address', '${p['address']}'),
        row('PAN', '${p['pan']}'),
        row('Email', '${p['email']}'),
      ]),
      box('SECOND PARTY - VENDOR', [
        row('Store name', '${v['storeName']}'),
        row('Type', v['kind'] == 'thela' ? 'Thela (moving)' : 'Shop'),
        row('Address', '${v['address']}'),
        row('Mobile', '${v['phone']}'),
        row('Email', '${v['email']}'),
        row('PAN', '${v['pan'] ?? ''}'),
        row('Aadhaar', '${v['aadhaarLast4'] ?? ''}'.isEmpty ? '' : 'XXXX XXXX ${v['aadhaarLast4']}'),
        row('GST', switch (v['gstType']) { 'regular' => 'Regular', 'composition' => 'Composition', _ => 'Not registered' }),
        if (v['gstType'] != 'none') row('GSTIN', '${v['gstin']}'),
        row('FSSAI', '${v['fssai']}'.isEmpty ? 'Not provided' : '${v['fssai']}'),
      ]),
      pw.SizedBox(height: 6),
      for (final x in paras)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 5),
          child: pw.Text(x, style: RegExp(r'^\d+\.\s+[A-Z]').hasMatch(x) ? st(10, b: true) : st(8.8)),
        ),
      pw.SizedBox(height: 12),
      pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: green, width: 1.2), borderRadius: pw.BorderRadius.circular(4)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('VENDOR ACCEPTANCE', style: st(10.5, b: true, c: green)),
          pw.SizedBox(height: 6),
          row('Vendor legal name', '${s['name']}'),
          row('Store name', '${v['storeName']}'),
          row('Registered mobile', '${v['phone']}'),
          row('GSTIN', '${v['gstin']}'.isEmpty ? 'Not registered' : '${v['gstin']}'),
          row('Agreement version', '${s['version']}'),
          row('Date and time', signedAtText(s)),
          row('Electronic reference', '${s['id']}'),
          pw.SizedBox(height: 6),
          pw.Text('Signature', style: st(9, c: mute)),
          pw.Container(height: 70, width: 220, child: pw.Image(sig, fit: pw.BoxFit.contain)),
          pw.Text('The vendor ticked "I have read and agree" and "I am authorised to accept for my business", typed the name above and signed with a finger in the app. The server recorded the time, account and device.',
              style: st(7.5, c: mute)),
        ]),
      ),
    ],
  ));
  return doc.save();
}

/// Saves to Downloads (and a copy inside the app for Open). Returns (path, savedInDownloads).
Future<(String, bool)> saveAgreementPdf(AgreementData d) async {
  final bytes = await agreementPdf(d);
  final dir = await getApplicationDocumentsDirectory();
  final f = File('${dir.path}/${_fileName(d)}');
  await f.writeAsBytes(bytes, flush: true);
  var inDownloads = true;
  try {
    await FileSaver.instance.saveToDownloads(
      name: _fileName(d).replaceAll('.pdf', ''),
      bytes: bytes,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );
  } catch (_) {
    inDownloads = false;
  }
  return (f.path, inDownloads);
}

Future<void> openAgreementFile(String path) => OpenFilex.open(path);

Future<void> shareAgreementPdf(AgreementData d) async {
  await Printing.sharePdf(bytes: await agreementPdf(d), filename: _fileName(d));
}
