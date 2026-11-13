import 'package:flutter/material.dart';
import '../api.dart';
import '../session.dart';
import '../ui.dart';

// Draft texts: to be reviewed by a lawyer before public launch.
const kLegalDate = '13 November 2026';
const kGrievanceEmail = 'surajth3553@gmail.com';

const kPartnerTerms = [
  ['1. Who can join', 'Shops / kirana stores and moving sellers (thelas) in India, run by a person aged 18 or above. You sign up with one Google account, verify your mobile number by SMS code and complete KYC (documents as asked in the app). One Google account is for one business: either a shop or a thela.'],
  ['2. Pass and free trial', 'To be shown to customers you need an active pass. A free trial is given once per mobile number and phone. Pass prices are shown in the app before you pay. Days already used are not refunded.'],
  ['3. Orders (shops)', 'A new order rings for up to 5 minutes. If you do not accept or reject it in that time, it is marked missed. 5 missed orders in a day pause your shop for the rest of the day. After accepting, pack what you have, mark items you do not have, and hand over the order only after the customer gives the 4-digit delivery code. Mark truthfully whether you were paid by cash or UPI.'],
  ['4. Prices, MRP and bills', 'You set your own prices. They must not be more than MRP. The bill to the customer is issued in your name with your details; GST, FSSAI and other licences for what you sell are your responsibility.'],
  ['5. Thelas: location, calls and chat', 'While you are LIVE, your phone shares its location with Nukad Kart so customers within 500 m can see your thela on a map. It stops when you go offline; after 10 minutes without location you are hidden. Customers can call you to their street: answer within 3 minutes, and go if you say “Coming”. Use “Nobody there” only when it is true. Chat is text only; do not ask for or share phone numbers.'],
  ['6. Staff', 'You may add up to 5 staff by mobile number. You are responsible for what your staff do in the app, including deliveries and money they collect. Remove staff who leave.'],
  ['7. Payments', 'Customers pay you directly, in cash or to your own UPI. Nukad Kart does not collect or hold order money and is not responsible for payment disputes between you and a customer.'],
  ['8. What is not allowed', 'Fake or expired items, selling above MRP, a photo or details that are not of your own shop or thela, abusing customers, misusing a customer’s address or number, and taking orders outside the app to avoid these terms. We may pause or remove accounts that do this.'],
  ['9. Changing your details', 'A new name, address or shop photo is checked by the Nukad team. After approval, or after you change your mobile number, you must sign the updated agreement before going LIVE again. Earlier signed agreements are kept.'],
  ['10. Pausing, leaving and your data', 'You can go offline at any time and can delete your account from the app. Your documents, photos and products are then removed; the signed agreement, payment records and trial record are kept as the law requires.'],
  ['11. Complaints', 'Write to our Grievance Officer at $kGrievanceEmail. We acknowledge within 48 hours and aim to resolve within one month.'],
  ['12. Agreement', 'These terms apply together with the Vendor Partnership Agreement you sign in the app. If they differ, the signed agreement applies.'],
];

const kPartnerPrivacy = [
  ['What we collect', '• Your name and email from Google, and your mobile number (checked by SMS code).\n• Business details: shop or thela name, address and map pin, a photo of the shop or thela with where it was taken, PAN / GST / FSSAI if you give them, and the last 4 digits of Aadhaar.\n• KYC documents you upload.\n• Your products and prices, orders, bills, pass payments and signed agreements (with your signature).\n• For thelas: your phone’s location while you are LIVE. For deliveries: the delivery phone’s location while an order is out.\n• Staff you add: their name and mobile number.\n• Chat messages with customers (deleted after 24 hours) and a notification token for this phone.'],
  ['Why', 'To verify you, show you to nearby customers, send you orders, calls and messages, make bills, prevent misuse (one free trial per number and phone) and meet legal duties. We do not sell your data.'],
  ['Who sees it', '• Customers within 500 m see your business name, photo, items and prices; for shops also address and phone; for thelas the live location while LIVE (never your phone number or home address).\n• Service providers who run the app for us: Google (sign-in, notifications), Cloudflare (servers), MSG91 (SMS codes), Ola Maps (maps).\n• Authorities when the law requires.'],
  ['How long', 'Until you delete your account. Live location is removed when you go offline. Chat is deleted after 24 hours. Signed agreements, payment records and the trial record are kept as the law requires.'],
  ['Your choices', 'Edit your details from Home → My details. Delete your account from the app. Complain to the Grievance Officer at $kGrievanceEmail, and then to the Data Protection Board of India.'],
];

class LegalScreen extends StatelessWidget {
  final String title;
  final List<List<String>> sections;
  const LegalScreen({super.key, required this.title, required this.sections});
  const LegalScreen.terms({super.key}) : title = 'Nukad Kart Partner Terms', sections = kPartnerTerms;
  const LegalScreen.privacy({super.key}) : title = 'Privacy Policy', sections = kPartnerPrivacy;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: bar(t(title)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Version 1 · $kLegalDate · Draft for legal review', style: tx(12, color: kMute)),
        const SizedBox(height: 10),
        for (final s in sections)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Box(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s[0], style: tx(14.5, weight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(s[1], style: tx(13, color: kMute)),
              ]),
            ),
          ),
      ]),
    );
  }
}

const kPartnerConsentVersion = 'p-2026-11-13';

/// DPDP: a clear "yes" from partners and staff (18+, privacy notice), recorded on the server with the version.
class PartnerConsentScreen extends StatefulWidget {
  const PartnerConsentScreen({super.key});
  @override
  State<PartnerConsentScreen> createState() => _PartnerConsentScreenState();
}

class _PartnerConsentScreenState extends State<PartnerConsentScreen> {
  bool age = false, agree = false, busy = false;

  Future<void> _go() async {
    setState(() => busy = true);
    try {
      await api.call('POST', '/v1/me/consent', {'age18': true, 'agree': true, 'version': kPartnerConsentVersion});
      await session.refresh();
      return;
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: bar(t('Before you start')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        Text(t('Nukad Kart keeps your account and business details, KYC documents, products, orders and signed agreements. For thelas, your location while LIVE; for deliveries, the delivery phone’s location while an order is out. Chats are deleted after 24 hours.'),
            style: tx(13.5)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalScreen.privacy())), child: Text(t('Privacy Policy'))),
          TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalScreen.terms())), child: Text(t('Partner terms'))),
        ]),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: age,
          onChanged: (v) => setState(() => age = v == true),
          title: Text(t('I am 18 years or older'), style: tx(14.5, weight: FontWeight.w800)),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: agree,
          onChanged: (v) => setState(() => agree = v == true),
          title: Text(t('I have read the Privacy Policy and Partner Terms and agree'), style: tx(14)),
        ),
        const SizedBox(height: 12),
        Btn(busy ? '…' : t('Agree and continue'), onTap: age && agree && !busy ? _go : null),
        TextButton(onPressed: () => session.signOut(), child: Text(t('Not now (log out)'))),
      ]),
    );
  }
}
