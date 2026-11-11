import 'package:flutter/material.dart';
import '../l10n.dart';
import '../data/demo_data.dart';
import '../state/app_state.dart';
import '../widgets/ui.dart';

class ReportScreen extends StatefulWidget {
  final Order order;
  const ReportScreen({super.key, required this.order});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  static const reasons = [
    'Items missing or wrong',
    'Charged more than the app price',
    'Damaged or expired item',
    'Store was rude',
  ];
  int sel = 0;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = storeById(widget.order.storeId);
    return Scaffold(
      backgroundColor: kBg,
      appBar: simpleAppBar(t('Report a problem'), subtitle: 'Order #${widget.order.id} · ${st.name}'),
      body: ListView(padding: EdgeInsets.all(16), children: [
        CardBox(
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Column(children: [
            for (var i = 0; i < reasons.length; i++)
              ListTile(
                dense: true,
                onTap: () => setState(() => sel = i),
                leading: Icon(sel == i ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: sel == i ? kG : Color(0xFFC5CFC6)),
                title: Text(reasons[i], style: body(14, weight: sel == i ? FontWeight.w700 : FontWeight.w500)),
              ),
          ]),
        ),
        SizedBox(height: 12),
        TextField(
          controller: _note,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Tell us what happened (optional)',
            filled: true,
            fillColor: kCard,
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Color(0xFFCFD8D1))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kG, width: 2)),
          ),
        ),
        SizedBox(height: 12),
        CardBox(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('What happens next', style: body(13.5, weight: FontWeight.w800)),
            SizedBox(height: 6),
            Text('We send your complaint to ${st.name} and keep a record of it.', style: body(12.5)),
            SizedBox(height: 4),
            Text('You paid the store directly; Nukad Kart does not give refunds. Any money back comes from the store.',
                style: body(12.5)),
            SizedBox(height: 4),
            Text('Stores found at fault can be suspended.', style: body(12.5)),
          ]),
        ),
        SizedBox(height: 18),
        PrimaryButton('Send complaint to store', onTap: () {
          AppScope.read(context)
              .notifications
              .insert(0, AppNotification('Complaint recorded', 'Sent to ${st.name}: ${reasons[sel]}'));
          showToast(context, 'Complaint sent to ${st.name} and recorded');
          Navigator.pop(context);
        }),
      ]),
    );
  }
}
