import 'package:flutter/material.dart';
import '../l10n.dart';
import '../services/api.dart';
import '../state/app_state.dart';
import '../widgets/ui.dart';
import 'account_pages.dart';

/// Version of the privacy notice the person agrees to. Change it when the policy changes: everyone is asked again.
const kConsentVersion = 'c-2026-11-14';

/// DPDP: a clear "yes" (not "by continuing…"), only for people aged 18+, recorded on the server with the version.
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});
  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool age = false, agree = false, busy = false;

  Future<void> _go() async {
    final s = AppScope.read(context);
    setState(() => busy = true);
    try {
      await api.consent(s.apiToken, kConsentVersion);
      s.setConsent(kConsentVersion);
      if (mounted) Navigator.pop(context, true);
      return;
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    }
    if (mounted) setState(() => busy = false);
  }

  Widget _point(IconData i, String text) => Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(i, size: 18, color: kG),
          SizedBox(width: 10),
          Expanded(child: Text(text, style: body(13.5))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(backgroundColor: kCard, automaticallyImplyLeading: false, title: Text(t('Before you start'), style: head(18))),
        body: ListView(padding: EdgeInsets.all(18), children: [
          Text(t('What Nukad Kart keeps about you'), style: head(16)),
          SizedBox(height: 10),
          _point(Icons.person_outline, t('Name, email and mobile number — for your account and orders.')),
          _point(Icons.location_on_outlined, t('Your delivery addresses and the map point of the one you choose — to show shops within 500 m and thelas near you.')),
          _point(Icons.storefront_outlined, t('Your orders — shared only with the shop you order from.')),
          _point(Icons.chat_bubble_outline, t('Chats with thelas — deleted after 24 hours. Your number is never shared with thelas.')),
          _point(Icons.notifications_none, t('A notification token for this phone.')),
          _point(Icons.delete_outline, t('You can delete your account any time from Account → Account privacy.')),
          SizedBox(height: 6),
          Wrap(spacing: 12, children: [
            TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())), child: Text(t('Privacy policy'))),
            TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsScreen())), child: Text(t('Terms & conditions'))),
          ]),
          Divider(),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: age,
            onChanged: (v) => setState(() => age = v == true),
            title: Text(t('I am 18 years or older'), style: body(14.5, weight: FontWeight.w700)),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: agree,
            onChanged: (v) => setState(() => agree = v == true),
            title: Text(t('I have read the privacy policy and agree to Nukad Kart using my data as described above'), style: body(14)),
          ),
          SizedBox(height: 12),
          PrimaryButton(busy ? '…' : t('Agree and continue'), onTap: age && agree && !busy ? _go : null),
          SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t('Not now (log out)'), style: body(13, color: kMute)),
            ),
          ),
          if (!age)
            Text(t('Nukad Kart is only for people aged 18 and above.'), textAlign: TextAlign.center, style: body(12, color: kMute)),
        ]),
      ),
    );
  }
}
