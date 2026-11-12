import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api.dart';
import '../otp.dart';
import '../session.dart';
import '../ui.dart';

/// Step 1: verify the shop's mobile number by SMS code. The free trial is tied to this number and this phone.
class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});
  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final phone = TextEditingController();
  final code = TextEditingController();
  String? reqId;
  bool _busy = false;

  @override
  void dispose() {
    phone.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone.text)) {
      toast(context, tr('Enter a valid 10-digit mobile number.'));
      return;
    }
    setState(() => _busy = true);
    try {
      reqId = await otpService.send(phone.text);
      if (mounted) toast(context, tr('Code sent to +91 {0}', [phone.text]));
    } on OtpException catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _verify() async {
    if (code.text.length != otpService.codeLength) {
      toast(context, tr('Enter the {0}-digit code.', [otpService.codeLength]));
      return;
    }
    setState(() => _busy = true);
    try {
      final ok = await otpService.verify(reqId!, code.text);
      if (!ok) {
        if (mounted) toast(context, tr('Wrong code. Check the SMS and try again.'));
      } else {
        final r = await api.call('POST', '/v1/partner/phone', {
          'phone': phone.text,
          'accessToken': otpService.lastAccessToken,
          'deviceId': await session.deviceId(),
        });
        await session.refresh();
        if (mounted && r['trialAvailable'] == false) {
          toast(context, tr('Number verified. The free trial was already used on this number or this phone.'));
        }
      }
    } on OtpException catch (e) {
      if (mounted) toast(context, e.message);
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: bar(tr('Verify your phone'), actions: [
        PopupMenuButton<String>(
          onSelected: (_) => session.signOut(),
          itemBuilder: (_) => [PopupMenuItem(value: 'out', child: Text(tr('Log out')))],
        ),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(tr('Step 1 of 5'), style: tx(12, color: kMute)),
        const SizedBox(height: 10),
        Text(tr('Mobile number of the shop'), style: tx(12.5, color: kMute, weight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextField(
          controller: phone,
          enabled: reqId == null,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
          decoration: field(tr('10-digit mobile number')).copyWith(prefixText: '+91 '),
        ),
        if (reqId != null) ...[
          const SizedBox(height: 14),
          Text(tr('{0}-digit code sent by SMS', [otpService.codeLength]), style: tx(12.5, color: kMute, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          TextField(
            controller: code,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(otpService.codeLength)],
            style: tx(22, weight: FontWeight.w800),
            textAlign: TextAlign.center,
            decoration: field('• ' * otpService.codeLength),
          ),
          Row(children: [
            TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          reqId = null;
                          code.clear();
                        }),
                child: Text(tr('Change number'))),
            const Spacer(),
            TextButton(
                onPressed: _busy
                    ? null
                    : () async {
                        try {
                          await otpService.resend(reqId!);
                          if (context.mounted) toast(context, tr('Code sent again'));
                        } on OtpException catch (e) {
                          if (context.mounted) toast(context, e.message);
                        }
                      },
                child: Text(tr('Resend'))),
          ]),
        ],
        const SizedBox(height: 12),
        Box(
          color: kOkBg,
          border: kOkBg,
          child: Row(children: [
            Icon(Icons.card_giftcard, color: kAct),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                  tr('7-day free trial after Nukad team approves your shop. One trial per mobile number and one per phone.'),
                  style: tx(12.5)),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Btn(_busy ? tr('Please wait…') : (reqId == null ? tr('Send code') : tr('Verify')), onTap: _busy ? null : (reqId == null ? _send : _verify)),
      ]),
    );
  }
}
