import 'dart:io';
import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../data/demo_data.dart';
import '../state/app_state.dart';
import 'bill.dart';

/// Bill for a delivered order, from the shop's own bill settings.
Bill billFor(Order o) {
  final st = storeById(o.storeId);
  return buildBill(
    store: st,
    orderId: o.id,
    number: o.billNo.isEmpty ? '${st.billPrefix}/${financialYear(o.placedAt)}/—' : o.billNo,
    date: o.times[OrderStatus.delivered] ?? o.placedAt,
    items: [for (final l in o.lines) (productById(l.productId), l.qty, l.price)],
    deliveryFee: o.fee,
    customerName: o.toName,
    customerPhone: o.toPhone,
    customerAddress: o.toAddress,
    customerState: o.toState,
    buyerGstin: o.buyerGstin,
    buyerBusiness: o.buyerBusiness,
    payMode: o.payMode,
  );
}

String _fileName(Order o) => 'Nukad-Kart-Bill-${o.id}.pdf';

/// Saves the bill PDF in the phone's Downloads folder. Returns (path of a copy the app can open, saved to Downloads?).
Future<(String, bool)> downloadBill(Order o) async {
  final bytes = await billPdf(billFor(o));
  final dir = await getApplicationDocumentsDirectory();
  final f = File('${dir.path}/${_fileName(o)}');
  await f.writeAsBytes(bytes, flush: true);
  var inDownloads = true;
  try {
    await FileSaver.instance.saveToDownloads(
      name: _fileName(o).replaceAll('.pdf', ''),
      bytes: bytes,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );
  } catch (_) {
    inDownloads = false; // still saved inside the app; Open works
  }
  return (f.path, inDownloads);
}

/// Opens a saved bill in the phone's PDF viewer.
Future<bool> openBillFile(String path) async {
  final r = await OpenFilex.open(path, type: 'application/pdf');
  return r.type == ResultType.done;
}

/// Opens the share sheet (WhatsApp, Gmail, Drive…).
Future<void> shareBill(Order o) async {
  final bytes = await billPdf(billFor(o));
  await Printing.sharePdf(bytes: bytes, filename: _fileName(o));
}

String _m(double v) => v.toStringAsFixed(2);
String _pct(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _date(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}, $h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'am' : 'pm'}';
}

Future<Uint8List> billPdf(Bill b) async {
  final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'));
  pw.MemoryImage? logo;
  if (b.store.logo != null) {
    try {
      logo = pw.MemoryImage((await rootBundle.load(b.store.logo!)).buffer.asUint8List());
    } catch (_) {}
  }
  final ink = PdfColor.fromInt(0xFF21331B);
  final head = PdfColor.fromInt(0xFFF6F2E2);
  final grey = PdfColor.fromInt(0xFF777777);
  final st = b.store;
  final gst = b.chargesGst;
  final inter = b.interState;

  pw.Widget cell(String t, {bool right = true, bool boldText = false, bool header = false, PdfColor? color}) => pw.Container(
        color: header ? head : null,
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        alignment: right ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        child: pw.Text(t,
            style: pw.TextStyle(fontSize: header ? 7.5 : 8.5, font: boldText || header ? bold : regular, color: color)),
      );
  pw.Widget na() => cell('NA', color: grey);

  final headers = <String>[
    '#', 'Item', 'Rate', 'Qty', gst ? 'Taxable value' : 'Value',
    if (inter) ...['IGST %', 'IGST'] else ...['CGST %', 'CGST', 'SGST %', 'SGST'],
    'Amount',
  ];
  final rows = <pw.TableRow>[
    pw.TableRow(children: [for (final h in headers) cell(h, header: true, right: h != 'Item')]),
  ];
  var i = 0;
  for (final l in b.lines) {
    final isFee = l.name == 'Delivery fee';
    if (!isFee) i++;
    rows.add(pw.TableRow(children: [
      cell(isFee ? '' : '$i'),
      pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(l.name, style: pw.TextStyle(fontSize: 8.5)),
          if (gst) pw.Text(isFee ? 'SAC ${l.hsn}' : 'HSN ${l.hsn}', style: pw.TextStyle(fontSize: 7, color: grey)),
        ]),
      ),
      cell(isFee ? '—' : _m(l.rate)),
      cell(isFee ? '—' : '${l.qty}'),
      cell(_m(l.taxable)),
      if (inter) ...[
        cell(_pct(l.gstRate)),
        cell(_m(l.igst)),
      ] else if (gst) ...[
        cell(_pct(l.gstRate / 2)),
        cell(_m(l.cgst)),
        cell(_pct(l.gstRate / 2)),
        cell(_m(l.sgst)),
      ] else ...[
        na(), na(), na(), na(),
      ],
      cell(_m(l.amount), boldText: true),
    ]));
  }
  rows.add(pw.TableRow(children: [
    cell(''), cell('Total', right: false, boldText: true), cell(''), cell(''),
    cell(_m(b.taxable), boldText: true),
    if (inter) ...[
      cell(''),
      cell(_m(b.igst), boldText: true),
    ] else if (gst) ...[
      cell(''), cell(_m(b.cgst), boldText: true), cell(''), cell(_m(b.sgst), boldText: true),
    ] else ...[
      na(), na(), na(), na(),
    ],
    cell(_m(b.total), boldText: true),
  ]));

  pw.Widget kv(String k, String v) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 1.5),
        child: pw.Row(children: [
          pw.SizedBox(width: 44, child: pw.Text(k, style: pw.TextStyle(font: bold, fontSize: 8.5))),
          pw.Text(v, style: const pw.TextStyle(fontSize: 8.5)),
        ]),
      );

  final doc = pw.Document(theme: pw.ThemeData.withFont(base: regular, bold: bold));
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(28),
    build: (ctx) => [
      pw.Container(
        decoration: pw.BoxDecoration(border: pw.Border.all(color: ink, width: 1)),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            flex: 16,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(color: ink, width: 1))),
              child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                if (logo != null) ...[
                  pw.ClipRRect(horizontalRadius: 8, verticalRadius: 8, child: pw.Image(logo, width: 48, height: 48)),
                  pw.SizedBox(width: 10),
                ],
                pw.Expanded(
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text(st.name, style: pw.TextStyle(font: bold, fontSize: 14)),
                    pw.SizedBox(height: 3),
                    pw.Text('${st.address} · ${st.phone}', style: const pw.TextStyle(fontSize: 8.5)),
                    pw.SizedBox(height: 5),
                    kv('GSTIN', st.gst == BillGst.none || st.gstin.isEmpty ? 'NA' : st.gstin),
                    kv('FSSAI', st.fssai.isEmpty ? 'NA' : st.fssai),
                    kv('State', '${st.stateName} (${st.stateCode})'),
                  ]),
                ),
              ]),
            ),
          ),
          pw.Expanded(
            flex: 10,
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: ink, width: 1))),
                child: pw.Text(b.title, textAlign: pw.TextAlign.center, style: pw.TextStyle(font: bold, fontSize: 16)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(10),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('Bill no: ${b.number}', style: pw.TextStyle(font: bold, fontSize: 8.5)),
                  pw.Text('Date: ${_date(b.date)}', style: const pw.TextStyle(fontSize: 8.5)),
                  pw.Text('Order: #${b.orderId}', style: const pw.TextStyle(fontSize: 8.5)),
                  pw.Text('Place of supply: ${b.placeOfSupply}', style: const pw.TextStyle(fontSize: 8.5)),
                ]),
              ),
            ]),
          ),
        ]),
      ),
      pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
            border: pw.Border(
                left: pw.BorderSide(color: ink), right: pw.BorderSide(color: ink), bottom: pw.BorderSide(color: ink))),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('Bill to', style: pw.TextStyle(font: bold, fontSize: 9)),
          if (b.buyerBusiness.isNotEmpty) pw.Text(b.buyerBusiness, style: pw.TextStyle(font: bold, fontSize: 9.5)),
          if (b.buyerGstin.isNotEmpty) pw.Text('GSTIN: ${b.buyerGstin}', style: pw.TextStyle(font: bold, fontSize: 8.5)),
          pw.Text('${b.customerName}${b.customerPhone.isEmpty ? '' : ' · +91 ${b.customerPhone}'}',
              style: const pw.TextStyle(fontSize: 8.5)),
          pw.Text(b.customerAddress, style: const pw.TextStyle(fontSize: 8.5)),
        ]),
      ),
      pw.SizedBox(height: 10),
      pw.Table(
        border: pw.TableBorder.all(color: ink, width: .6),
        columnWidths: {1: const pw.FlexColumnWidth(3.2)},
        defaultColumnWidth: const pw.FlexColumnWidth(1),
        children: rows,
      ),
      if (gst)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.Text(
              inter
                  ? 'Delivery to another state: IGST.'
                  : 'Within ${st.stateName}: CGST + SGST. Delivery fee is taxed at the highest item rate.',
              style: pw.TextStyle(fontSize: 7.5, color: grey)),
        ),
      pw.SizedBox(height: 10),
      pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: ink, width: .8)),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Expanded(
              child: pw.Text('Amount in words: ${amountInWords(b.total)}', style: pw.TextStyle(font: bold, fontSize: 8.5))),
          pw.Text(switch (b.payMode) { 'upi' => 'Paid at delivery · UPI', 'cash' => 'Paid at delivery · Cash', _ => 'Paid at delivery' },
              style: pw.TextStyle(font: bold, fontSize: 8.5)),
        ]),
      ),
      pw.SizedBox(height: 6),
      pw.Text(b.note, style: pw.TextStyle(font: bold, fontSize: 8.5)),
      if (st.billTerms.isNotEmpty) ...[
        pw.SizedBox(height: 12),
        pw.Text('Terms & Conditions', style: pw.TextStyle(font: bold, fontSize: 9)),
        for (var k = 0; k < st.billTerms.length; k++)
          pw.Text('${k + 1}. ${st.billTerms[k]}', style: const pw.TextStyle(fontSize: 8.5)),
      ],
      pw.SizedBox(height: 26),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Expanded(
          child: pw.Text(
            'This bill is issued by ${st.name}. Nukad Kart only connects you with the shop and is not the seller.\n'
            'Check the shop’s FSSAI status at foscos.fssai.gov.in.',
            style: pw.TextStyle(fontSize: 7.5, color: grey),
          ),
        ),
        pw.Column(children: [
          pw.SizedBox(height: 20),
          pw.Text('For ${st.name}', style: const pw.TextStyle(fontSize: 8)),
          pw.Text('Authorised signatory', style: pw.TextStyle(fontSize: 7.5, color: grey)),
        ]),
      ]),
      pw.SizedBox(height: 14),
      pw.Center(child: pw.Text('Order placed via Nukad Kart', style: pw.TextStyle(fontSize: 7.5, color: grey))),
    ],
  ));
  return doc.save();
}
