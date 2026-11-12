import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../api.dart';
import '../ui.dart';
import 'product_form.dart';

/// Barcode scanning that stays open: scan, set price, scan the next one.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final cam = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates, formats: const [
    BarcodeFormat.ean13,
    BarcodeFormat.ean8,
    BarcodeFormat.upcA,
    BarcodeFormat.upcE,
  ]);
  final List<Map<String, dynamic>> results = []; // newest first
  int added = 0;
  bool _busy = false;
  String _last = '';
  DateTime _lastAt = DateTime(2000);

  @override
  void dispose() {
    cam.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture cap) async {
    final code = cap.barcodes.map((b) => b.rawValue ?? '').firstWhere((v) => RegExp(r'^\d{6,14}$').hasMatch(v), orElse: () => '');
    if (code.isEmpty || _busy) return;
    if (code == _last && DateTime.now().difference(_lastAt) < const Duration(seconds: 4)) return;
    _last = code;
    _lastAt = DateTime.now();
    setState(() => _busy = true);
    try {
      final r = await api.call('GET', '/v1/partner/barcode/$code');
      if (!mounted) return;
      final row = <String, dynamic>{'code': code, ...r};
      setState(() => results.insert(0, row));
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _open(Map<String, dynamic> row) async {
    await cam.stop();
    if (!mounted) return;
    final existing = row['existing'] as Map?;
    final saved = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => existing != null
            ? ProductFormScreen(product: Map<String, dynamic>.from(existing))
            : ProductFormScreen(prefill: {
                'barcode': row['code'],
                if (row['found'] == true) ...{'name': row['name'], 'brand': row['brand'], 'size': row['size'], 'image': row['image'], 'category': row['category']},
              }),
      ),
    );
    if (saved != null && saved['deleted'] == null && mounted) {
      setState(() {
        if (existing == null) added++;
        row
          ..remove('found')
          ..['existing'] = saved;
      });
    }
    await cam.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: bar(t('Scan barcode'), actions: [
        Center(child: Padding(padding: const EdgeInsets.only(right: 8), child: Text(tr('{0} added', [added]), style: tx(13, color: kOnHeader, weight: FontWeight.w700)))),
      ]),
      body: Column(children: [
        SizedBox(
          height: 280,
          child: Stack(fit: StackFit.expand, children: [
            MobileScanner(controller: cam, onDetect: _onDetect),
            IgnorePointer(
              child: Center(
                child: Container(
                  width: 260,
                  height: 130,
                  decoration: BoxDecoration(border: Border.all(color: kBrand, width: 3), borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: IconButton.filledTonal(onPressed: () => cam.toggleTorch(), icon: const Icon(Icons.flashlight_on_outlined)),
            ),
            if (_busy) const Positioned(left: 12, top: 12, child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3))),
            Positioned(
              left: 0,
              right: 0,
              bottom: 8,
              child: Text(t('Point at the barcode'), textAlign: TextAlign.center, style: tx(12.5, color: Colors.white, weight: FontWeight.w700)),
            ),
          ]),
        ),
        Expanded(
          child: results.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(t('Scan packets one after another. Each one shows here; tap to set the price.'),
                        textAlign: TextAlign.center, style: tx(13.5, color: kMute)),
                  ),
                )
              : ListView(padding: const EdgeInsets.all(12), children: [
                  for (final r in results) _row(r),
                ]),
        ),
      ]),
    );
  }

  Widget _row(Map<String, dynamic> r) {
    final ex = r['existing'] as Map?;
    final found = r['found'] == true;
    final (title, sub, color, action) = ex != null
        ? ('${ex['name']}', tr('In your list · {0}', [money(ex['price'] as num)]), kAct, t('Edit'))
        : found
            ? ('${r['name']}', tr('Found · {0} · set the price', [r['size'] ?? '']), kAct, t('Set price'))
            : (tr('{0} not found', [r['code']]), t('Add name and photo yourself'), kAmb, t('Add'));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Box(
        color: found || ex != null ? null : kAmbBg,
        border: found ? kAct : null,
        padding: const EdgeInsets.all(10),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 44,
              height: 44,
              child: found && '${r['image']}'.isNotEmpty
                  ? Image.network('${r['image']}', fit: BoxFit.cover)
                  : ex != null
                      ? productImage(Map<String, dynamic>.from(ex), size: 44)
                      : Container(color: kSurf, child: Icon(Icons.help_outline, color: color)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx(14, weight: FontWeight.w800)),
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx(11.5, color: color)),
            ]),
          ),
          OutlinedButton(onPressed: () => _open(r), child: Text(action)),
        ]),
      ),
    );
  }
}
