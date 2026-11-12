import '../data/demo_data.dart';

/// One row on a shop's bill. Prices on Nukad Kart include GST, so tax is worked out backwards.
class BillLine {
  final String name, hsn;
  final double gstRate; // %
  final int qty;
  final double rate; // price per unit, incl. GST
  final double amount; // rate × qty, incl. GST
  final double taxable; // amount without GST (= amount when no GST is charged)
  final double cgst, sgst, igst;
  const BillLine(this.name, this.hsn, this.gstRate, this.qty, this.rate, this.amount, this.taxable, this.cgst,
      this.sgst, this.igst);
}

class Bill {
  final Store store;
  final String number, orderId, title, note;
  final DateTime date;
  final String customerName, customerPhone, customerAddress, placeOfSupply;
  final String buyerGstin, buyerBusiness;
  final bool chargesGst, interState;
  final List<BillLine> lines;
  const Bill({
    required this.store,
    required this.number,
    required this.orderId,
    required this.title,
    required this.note,
    required this.date,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    required this.placeOfSupply,
    this.buyerGstin = '',
    this.buyerBusiness = '',
    required this.chargesGst,
    required this.interState,
    required this.lines,
  });

  double get taxable => lines.fold(0, (s, l) => s + l.taxable);
  double get cgst => lines.fold(0, (s, l) => s + l.cgst);
  double get sgst => lines.fold(0, (s, l) => s + l.sgst);
  double get igst => lines.fold(0, (s, l) => s + l.igst);
  double get total => lines.fold(0, (s, l) => s + l.amount);
}

double _r2(double v) => (v * 100).roundToDouble() / 100;

/// Financial year label for bill numbers, e.g. 12 Nov 2026 → "26-27". A new series starts every 1 April.
String financialYear(DateTime d) {
  final start = d.month >= 4 ? d.year : d.year - 1;
  String yy(int y) => (y % 100).toString().padLeft(2, '0');
  return '${yy(start)}-${yy(start + 1)}';
}

String billNumber(Store s, DateTime d, int seq) => '${s.billPrefix}/${financialYear(d)}/${seq.toString().padLeft(6, '0')}';

/// Two-letter GST state codes for the states in the address form.
const Map<String, String> kGstStateCodes = {
  'Delhi': '07', 'Haryana': '06', 'Uttar Pradesh': '09', 'Maharashtra': '27', 'Karnataka': '29',
  'Tamil Nadu': '33', 'Telangana': '36', 'West Bengal': '19', 'Gujarat': '24', 'Rajasthan': '08',
  'Punjab': '03', 'Bihar': '10', 'Madhya Pradesh': '23', 'Kerala': '32', 'Uttarakhand': '05',
};

/// Builds the bill for a delivered order.
/// - GST (Regular) shop: "Tax Invoice" with CGST + SGST inside the state, IGST across states.
/// - Composition shop or shop without GST: "Bill of Supply", tax columns show NA.
/// The delivery fee is billed at the highest GST rate among the items (it goes with the main supply).
Bill buildBill({
  required Store store,
  required String orderId,
  required String number,
  required DateTime date,
  required List<(Product, int qty, int price)> items,
  required int deliveryFee,
  required String customerName,
  required String customerPhone,
  required String customerAddress,
  required String customerState,
  String buyerGstin = '',
  String buyerBusiness = '',
}) {
  final gst = store.gst == BillGst.regular;
  final inter = gst && customerState.isNotEmpty && customerState != store.stateName;
  BillLine line(String name, String hsn, double r, int q, double rate) {
    final amount = _r2(rate * q);
    if (!gst) return BillLine(name, hsn, 0, q, rate, amount, amount, 0, 0, 0);
    final taxable = _r2(amount / (1 + r / 100));
    final tax = _r2(amount - taxable);
    if (inter) return BillLine(name, hsn, r, q, rate, amount, taxable, 0, 0, tax);
    final half = _r2(tax / 2);
    return BillLine(name, hsn, r, q, rate, amount, taxable, half, _r2(tax - half), 0);
  }

  var maxRate = 0.0;
  final lines = <BillLine>[];
  for (final (p, q, price) in items) {
    final (hsn, r) = p.hsnGst;
    if (r > maxRate) maxRate = r;
    lines.add(line('${p.name} ${p.size}', hsn, r, q, price.toDouble()));
  }
  if (deliveryFee > 0) lines.add(line('Delivery fee', '9968', maxRate, 1, deliveryFee.toDouble()));

  final code = kGstStateCodes[customerState];
  return Bill(
    store: store,
    number: number,
    orderId: orderId,
    title: gst ? 'Tax Invoice' : 'Bill of Supply',
    note: switch (store.gst) {
      BillGst.regular => 'Tax is not payable on reverse charge.',
      BillGst.composition => 'Composition taxable person, not eligible to collect tax on supplies.',
      BillGst.none => 'Seller is not registered under GST. No GST charged.',
    },
    date: date,
    customerName: customerName,
    customerPhone: customerPhone,
    customerAddress: customerAddress,
    buyerGstin: gst ? buyerGstin : '',
    buyerBusiness: gst ? buyerBusiness : '',
    placeOfSupply: customerState.isEmpty ? store.stateName : '$customerState${code == null ? '' : ' ($code)'}',
    chargesGst: gst,
    interState: inter,
    lines: lines,
  );
}

// ---------- amount in words (Indian system) ----------
const _ones = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten', 'Eleven', 'Twelve',
  'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
const _tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

String _below100(int n) => n < 20 ? _ones[n] : '${_tens[n ~/ 10]}${n % 10 == 0 ? '' : ' ${_ones[n % 10]}'}';
String _below1000(int n) {
  final h = n ~/ 100, r = n % 100;
  return [if (h > 0) '${_ones[h]} Hundred', if (r > 0) _below100(r)].join(' ');
}

String _words(int n) {
  if (n == 0) return 'Zero';
  final parts = <String>[];
  final crore = n ~/ 10000000, lakh = (n ~/ 100000) % 100, thousand = (n ~/ 1000) % 100, rest = n % 1000;
  if (crore > 0) parts.add('${_words(crore)} Crore');
  if (lakh > 0) parts.add('${_below100(lakh)} Lakh');
  if (thousand > 0) parts.add('${_below100(thousand)} Thousand');
  if (rest > 0) parts.add(_below1000(rest));
  return parts.join(' ');
}

/// 438.5 → "Rupees Four Hundred Thirty Eight and Fifty Paise Only"
String amountInWords(double amount) {
  final rupees = amount.floor();
  final paise = ((amount - rupees) * 100).round();
  return 'Rupees ${_words(rupees)}${paise > 0 ? ' and ${_below100(paise)} Paise' : ''} Only';
}
