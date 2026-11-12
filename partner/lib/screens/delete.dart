import 'package:flutter/material.dart';
import '../api.dart';
import '../session.dart';
import '../ui.dart';

/// Delete the partner account (same idea as the customer app).
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});
  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  static const reasons = ['Not getting enough orders', 'Pass is too costly', 'Closing my shop', 'Too hard to use', 'Other'];
  String? reason;
  final feedback = TextEditingController();
  final confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    feedback.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    try {
      await api.call('POST', '/v1/partner/delete', {'reason': reason ?? '', 'feedback': feedback.text.trim()});
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
      await session.signOut();
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ok = confirm.text.trim().toUpperCase() == 'DELETE';
    return Scaffold(
      appBar: bar('Delete account'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Box(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Deleted right away', style: tx(14.5, weight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Your shop, shop photo, documents (PAN, Aadhaar, GST, FSSAI), and login on all phones. Customers stop seeing your shop.',
                style: tx(12.5, color: kMute)),
          ]),
        ),
        const SizedBox(height: 10),
        Box(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Kept because the law requires it', style: tx(14.5, weight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Your signed agreement and pass payment records (up to 8 years). The free-trial record is kept only as a code that can’t be read back, so a new account doesn’t get another trial.',
                style: tx(12.5, color: kMute)),
          ]),
        ),
        const SizedBox(height: 10),
        Box(
          color: kRedBg,
          border: const Color(0xFFF7C1C1),
          child: Text('Any pass days left are lost and are not refunded. This can’t be undone.',
              style: tx(12.5, color: kRed, weight: FontWeight.w700)),
        ),
        const SizedBox(height: 16),
        Text('Why are you leaving? (optional)', style: tx(12.5, color: kMute, weight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final r in reasons)
            ChoiceChip(label: Text(r), selected: reason == r, onSelected: (_) => setState(() => reason = r)),
        ]),
        const SizedBox(height: 10),
        TextField(controller: feedback, maxLines: 3, decoration: field('Anything we could do better?')),
        const SizedBox(height: 16),
        Text('Type DELETE to confirm', style: tx(12.5, color: kMute, weight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextField(controller: confirm, onChanged: (_) => setState(() {}), textCapitalization: TextCapitalization.characters, decoration: field('DELETE')),
        const SizedBox(height: 16),
        Btn(_busy ? 'Deleting…' : 'Delete my account', color: kRed, onTap: ok && !_busy ? _delete : null),
      ]),
    );
  }
}
