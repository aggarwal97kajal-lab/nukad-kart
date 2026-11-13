import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api.dart';
import '../otp.dart';
import '../session.dart';
import '../ui.dart';
import 'orders.dart';
import '../push.dart';
import '../open_push.dart';

/// Staff login: no Google, no Shop / Thela choice. The number must be added by a store owner,
/// checked before the SMS is sent, then verified by the SMS code.
class StaffLoginScreen extends StatefulWidget {
  const StaffLoginScreen({super.key});
  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen> {
  final phone = TextEditingController();
  final code = TextEditingController();
  String? reqId, error;
  bool busy = false;

  @override
  void dispose() {
    phone.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => error = null);
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone.text)) {
      setState(() => error = t('Enter a valid 10-digit mobile number.'));
      return;
    }
    setState(() => busy = true);
    try {
      await api.call('POST', '/v1/staff/check', {'phone': phone.text});
      reqId = await otpService.send(phone.text);
      if (mounted) toast(context, tr('Code sent to +91 {0}', [phone.text]));
    } on ApiError catch (e) {
      error = e.code == 'not_staff' ? t('Ask your store owner to add this mobile number.') : e.message;
    } on OtpException catch (e) {
      error = e.message;
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _verify() async {
    if (code.text.length != otpService.codeLength) {
      setState(() => error = tr('Enter the {0}-digit code.', [otpService.codeLength]));
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final ok = await otpService.verify(reqId!, code.text);
      if (!ok) throw OtpException(t('Wrong code. Try again.'));
      await session.staffLogin(phone.text, otpService.lastAccessToken ?? '');
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      return;
    } on OtpException catch (e) {
      error = e.message;
    } on ApiError catch (e) {
      error = e.code == 'not_staff' ? t('Ask your store owner to add this mobile number.') : e.message;
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: bar(t('Staff login')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text(t('Login with the mobile number your store owner added.'), style: tx(13.5, color: kMute)),
        const SizedBox(height: 14),
        TextField(
          controller: phone,
          enabled: reqId == null,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
          decoration: field('98765 43210').copyWith(prefixText: '+91 '),
        ),
        if (reqId != null) ...[
          const SizedBox(height: 12),
          TextField(
            controller: code,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: tx(22, weight: FontWeight.w800).copyWith(letterSpacing: 8),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(otpService.codeLength)],
            decoration: field('• ' * otpService.codeLength),
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 10),
          Box(color: kRedBg, border: kRedLine, child: Text(error!, style: tx(13, color: kRed, weight: FontWeight.w700))),
        ],
        const SizedBox(height: 16),
        Btn(busy ? '…' : (reqId == null ? t('Send OTP') : t('Verify and log in')), onTap: busy ? null : (reqId == null ? _send : _verify)),
        if (reqId != null)
          TextButton(onPressed: busy ? null : () => setState(() { reqId = null; code.clear(); }), child: Text(t('Change number'))),
      ]),
    );
  }
}

/// What a staff member sees: orders / deliveries of their store, nothing else.
class StaffShell extends StatefulWidget {
  const StaffShell({super.key});
  @override
  State<StaffShell> createState() => _StaffShellState();
}

class _StaffShellState extends State<StaffShell> {
  @override
  void initState() {
    super.initState();
    openedPush.addListener(_opened);
    if (openedPush.value.isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => _opened());
  }

  @override
  void dispose() {
    openedPush.removeListener(_opened);
    super.dispose();
  }

  void _opened() => openFromPush(context);

  @override
  Widget build(BuildContext context) {
    final st = session.staffInfo!;
    return Scaffold(
      body: Column(children: [
        Material(
          color: kSurf,
          child: SafeArea(
            bottom: false,
            child: ListTile(
              title: Text(tr('Hi {0}', [st['name']]), style: tx(16, weight: FontWeight.w800)),
              subtitle: Text('${st['storeName']} · ${st['canOrders'] == true ? t('Orders and delivery') : t('Delivery')}'),
              trailing: TextButton(onPressed: () => session.signOut(), child: Text(t('Log out'))),
            ),
          ),
        ),
        const Expanded(child: OrdersScreen()),
      ]),
    );
  }
}

/// Owner: add / remove staff (max 5). Staff log in with their own number.
class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});
  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  List<Map<String, dynamic>> staff = [];
  int max = 5;
  bool loading = true, busy = false, canOrders = false;
  final name = TextEditingController(), phone = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await api.call('GET', '/v1/partner/staff');
      staff = ((r['staff'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      max = (r['max'] as num?)?.toInt() ?? 5;
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _add() async {
    setState(() => busy = true);
    try {
      await api.call('POST', '/v1/partner/staff', {'name': name.text.trim(), 'phone': phone.text, 'canOrders': canOrders});
      if (mounted) toast(context, tr('{0} added. They can log in with Staff login.', [name.text.trim()]));
      name.clear();
      phone.clear();
      canOrders = false;
      await _load();
    } on ApiError catch (e) {
      if (mounted) {
        toast(context, switch (e.code) {
          'staff_elsewhere' => t('This number is already staff at another store.'),
          'already_staff' => t('This number is already your staff.'),
          'staff_limit' => tr('You can add up to {0} staff.', [max]),
          'own_number' => t('This is your own number.'),
          _ => e.message,
        });
      }
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _remove(Map<String, dynamic> s) async {
    try {
      await api.call('DELETE', '/v1/partner/staff/${s['id']}');
      await _load();
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: bar(t('Staff')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              for (final s in staff)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: kLine)),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${s['name']} · +91 ${s['phone']}', style: tx(14, weight: FontWeight.w800)),
                        Text('${s['canOrders'] == true ? t('Orders and delivery') : t('Delivery')} · ${s['loggedIn'] == true ? t('logged in') : t('not logged in yet')}',
                            style: tx(12, color: kMute)),
                      ]),
                    ),
                    TextButton(onPressed: () => _remove(s), child: Text(t('Remove'), style: TextStyle(color: kRed))),
                  ]),
                ),
              if (staff.length < max) ...[
                const SizedBox(height: 8),
                Text(t('Add staff'), style: tx(16, weight: FontWeight.w800)),
                const SizedBox(height: 8),
                TextField(controller: name, decoration: field(t('Name'))),
                const SizedBox(height: 8),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                  decoration: field('98765 43210').copyWith(prefixText: '+91 '),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: true,
                  onChanged: null,
                  title: Text(t('Deliver orders and enter the delivery code')),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: canOrders,
                  onChanged: (v) => setState(() => canOrders = v == true),
                  title: Text(t('Accept / reject new orders and pack')),
                ),
                Text(t('Staff never see the day’s money, products, pass, documents or settings.'), style: tx(12, color: kMute)),
                const SizedBox(height: 12),
                Btn(busy ? '…' : t('Add'), onTap: busy ? null : _add),
              ],
            ]),
    );
  }
}
