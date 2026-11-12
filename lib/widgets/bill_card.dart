import 'package:flutter/material.dart';
import '../data/demo_data.dart';
import '../services/bill_pdf.dart';
import '../state/app_state.dart';
import 'ui.dart';

/// "Your bill is ready" with Download PDF and Share, shown on a delivered order.
class BillCard extends StatefulWidget {
  final Order order;
  const BillCard({super.key, required this.order});
  @override
  State<BillCard> createState() => _BillCardState();
}

class _BillCardState extends State<BillCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function(Order) job) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await job(widget.order);
    } catch (_) {
      if (mounted) showToast(context, 'Could not open the bill. Try again.');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final st = storeById(o.storeId);
    final title = st.gst == BillGst.regular ? 'Tax Invoice' : 'Bill of Supply';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(18), border: Border.all(color: kG, width: 2)),
      child: Column(children: [
        Row(children: [
          Container(
            width: 44,
            height: 52,
            decoration: BoxDecoration(color: kGBg, borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.receipt_long_outlined, color: kG, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Your bill is ready', style: body(15, weight: FontWeight.w800)),
              Text('$title from ${st.name}${o.billNo.isEmpty ? '' : ' · ${o.billNo}'}',
                  style: body(12.5, color: kMute)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _busy ? null : () => _run(downloadBill),
              icon: const Icon(Icons.download_rounded, size: 19),
              label: const Text('Download PDF'),
              style: FilledButton.styleFrom(
                  backgroundColor: kG,
                  foregroundColor: kOnG,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _busy ? null : () => _run(shareBill),
              icon: const Icon(Icons.share_outlined, size: 19),
              label: const Text('Share'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: kG,
                  side: BorderSide(color: kG, width: 1.5),
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
        ]),
      ]),
    );
  }
}
