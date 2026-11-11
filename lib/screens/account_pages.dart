import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/demo_data.dart';
import '../l10n.dart';
import '../state/app_state.dart';
import '../widgets/ui.dart';
import 'address_screen.dart';
import 'orders_tab.dart';
import 'product_screen.dart';
import 'store_screen.dart';
import 'login_screen.dart';

// ---------------- bottom-sheet chooser ----------------
class ChoiceOption {
  final String value;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool danger;
  const ChoiceOption(this.value, this.title, this.subtitle, this.icon, {this.danger = false});
}

Future<String?> showChoiceSheet(BuildContext context,
    {required String title,
    required String subtitle,
    required List<ChoiceOption> options,
    String? selected,
    bool showCancel = false}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: kCard,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: Container(
                width: 44, height: 5, decoration: BoxDecoration(color: kLine, borderRadius: BorderRadius.circular(3))),
          ),
          const SizedBox(height: 14),
          Text(title, style: head(20)),
          const SizedBox(height: 4),
          Text(subtitle, style: body(13, color: kMute)),
          const SizedBox(height: 6),
          for (var i = 0; i < options.length; i++)
            InkWell(
              onTap: () => Navigator.pop(ctx, options[i].value),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                decoration: BoxDecoration(
                    border: i < options.length - 1 ? Border(bottom: BorderSide(color: kLine)) : null),
                child: Row(children: [
                  if (options[i].icon != null) ...[
                    Icon(options[i].icon, color: options[i].danger ? kRed : kG),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(options[i].title,
                          style: body(15.5,
                              color: options[i].danger ? kRed : kInk,
                              weight: options[i].value == selected ? FontWeight.w700 : FontWeight.w500)),
                      if (options[i].subtitle != null)
                        Text(options[i].subtitle!, style: body(12.5, color: kMute)),
                    ]),
                  ),
                  if (options[i].value == selected) Icon(Icons.check, color: kG),
                ]),
              ),
            ),
          if (showCancel) ...[
            const SizedBox(height: 12),
            PrimaryButton(t('Cancel'), outline: true, color: kInk, onTap: () => Navigator.pop(ctx)),
          ],
        ]),
      ),
    ),
  );
}

Future<void> showAppearanceSheet(BuildContext context) async {
  final s = AppScope.read(context);
  final v = await showChoiceSheet(context,
      title: t('Appearance'),
      subtitle: t('Choose how Nukad Kart looks'),
      selected: s.theme.name,
      options: [
        ChoiceOption('light', t('Light'), null, Icons.light_mode_outlined),
        ChoiceOption('dark', t('Dark'), null, Icons.dark_mode_outlined),
        ChoiceOption('system', t('Same as phone'), t('Follows your phone’s setting'), Icons.smartphone),
      ]);
  if (v == null) return;
  s.setTheme(AppTheme.values.firstWhere((e) => e.name == v));
}

Future<void> showLanguageSheet(BuildContext context) async {
  final s = AppScope.read(context);
  final v = await showChoiceSheet(context,
      title: t('Language'),
      subtitle: t('App text changes right away'),
      selected: s.lang,
      options: const [
        ChoiceOption('en', 'English', 'Order groceries from shops near you', null),
        ChoiceOption('hi', 'हिन्दी (Hindi)', 'पास की दुकानों से सामान मँगाइए', null),
        ChoiceOption('hg', 'Hinglish', 'Paas ki dukaanon se saamaan mangaiye', null),
      ]);
  if (v == null) return;
  s.setLang(v);
}

Future<void> shareApp(BuildContext context) async {
  const text = 'Nukad Kart: apne nukkad ki har dukaan, 500 m ke andar. '
      'Download: https://github.com/aggarwal97kajal-lab/nukad-kart/releases/latest';
  await Clipboard.setData(const ClipboardData(text: text));
  if (context.mounted) showToast(context, 'App link copied. Paste it in WhatsApp to share.');
}

// ---------------- simple page scaffold ----------------
class _Page extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? bottom;
  const _Page({required this.title, required this.children, this.bottom});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: simpleAppBar(title),
      bottomNavigationBar: bottom,
      body: ListView(padding: const EdgeInsets.all(16), children: children),
    );
  }
}

Widget _empty(String emoji, String title, String sub) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Text(emoji, style: const TextStyle(fontSize: 56)),
        const SizedBox(height: 10),
        Text(title, textAlign: TextAlign.center, style: head(18)),
        const SizedBox(height: 4),
        Text(sub, textAlign: TextAlign.center, style: body(13, color: kMute)),
      ]),
    );

// ---------------- Edit profile ----------------
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController name;
  late final TextEditingController phone;

  @override
  void initState() {
    super.initState();
    final s = AppScope.read(context);
    name = TextEditingController(text: s.name);
    phone = TextEditingController(text: s.phone);
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return _Page(title: t('Edit profile'), children: [
      _field('Name', name),
      const SizedBox(height: 12),
      _field('Mobile number', phone, phoneKb: true),
      const SizedBox(height: 12),
      Text('Google account: ${s.email}', style: body(12.5, color: kMute)),
      const SizedBox(height: 20),
      PrimaryButton('Save', onTap: () {
        if (name.text.trim().length < 2 || phone.text.length != 10) {
          showToast(context, 'Enter your name and a 10-digit number');
          return;
        }
        s.saveProfile(name.text.trim(), phone.text);
        showToast(context, 'Profile saved');
        Navigator.pop(context);
      }),
    ]);
  }

  Widget _field(String label, TextEditingController c, {bool phoneKb = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: body(12.5, color: kMute, weight: FontWeight.w700)),
      const SizedBox(height: 6),
      TextField(
        controller: c,
        keyboardType: phoneKb ? TextInputType.phone : TextInputType.name,
        inputFormatters: phoneKb ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)] : null,
        style: body(15, weight: FontWeight.w600),
        decoration: InputDecoration(
          prefixText: phoneKb ? '+91  ' : null,
          filled: true,
          fillColor: kCard,
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kLine)),
          focusedBorder:
              OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kG, width: 2)),
        ),
      ),
    ]);
  }
}

// ---------------- Address book ----------------
class AddressBookScreen extends StatelessWidget {
  const AddressBookScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return _Page(
      title: t('Address book'),
      bottom: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: PrimaryButton('+ Add new address',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddressFormScreen()))),
        ),
      ),
      children: [
        if (s.addresses.isEmpty) _empty('📍', 'No saved addresses', 'Add your home or shop address to see stores near it.'),
        for (final a in s.addresses)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CardBox(
              border: a == s.current ? kG : null,
              child: Row(children: [
                Icon(labelIcon(a.label), color: kG),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.label.toUpperCase(), style: body(11.5, color: kG, weight: FontWeight.w800)),
                    Text(a.short, style: body(14, weight: FontWeight.w600)),
                    Text('${a.city}, ${a.state} ${a.pin}', style: body(12, color: kMute)),
                    if (a.name.isNotEmpty) Text('${a.name} · +91 ${a.phone}', style: body(12, color: kMute)),
                    if (a == s.current) Text('Delivering here', style: body(12, color: kG, weight: FontWeight.w700)),
                  ]),
                ),
                IconButton(
                    onPressed: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => AddressFormScreen(editing: a))),
                    icon: Icon(Icons.edit_outlined, color: kMute)),
                if (a != s.current)
                  TextButton(onPressed: () => s.useAddress(a), child: Text('Use', style: body(13, color: kG, weight: FontWeight.w700))),
                if (a != s.current)
                  IconButton(onPressed: () => s.removeAddress(a), icon: Icon(Icons.delete_outline, color: kMute)),
              ]),
            ),
          ),
        const SizedBox(height: 6),
        if (s.addresses.isNotEmpty)
          Text('Only shops within 500 m of the selected address are shown.',
              textAlign: TextAlign.center, style: body(12, color: kMute)),
      ],
    );
  }
}

// ---------------- Bookmarks & wishlist ----------------
class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final list = kStores.where((st) => s.bookmarks.contains(st.id)).toList();
    return _Page(title: t('Bookmarked stores'), children: [
      if (list.isEmpty) _empty('🔖', 'No bookmarked stores', 'Tap the bookmark icon on a store page to save it here.'),
      for (final st in list)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StoreScreen(store: st))),
            child: CardBox(
              child: Row(children: [
                Icon(Icons.storefront, color: kG, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(st.name, style: head(15)),
                    Text('${st.distanceM} m · ★ ${st.rating}', style: body(12, color: kMute)),
                  ]),
                ),
                IconButton(onPressed: () => s.toggleBookmark(st.id), icon: Icon(Icons.bookmark, color: kG)),
              ]),
            ),
          ),
        ),
    ]);
  }
}

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final list = kProducts.where((p) => s.wishlist.contains(p.id)).toList();
    return _Page(title: t('Your wishlist'), children: [
      if (list.isEmpty) _empty('🤍', 'Your wishlist is empty', 'Tap the heart on any product to save it here.'),
      for (final p in list)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductScreen(product: p))),
            child: CardBox(
              padding: const EdgeInsets.all(10),
              child: Row(children: [
                EmojiTile(p.emoji, size: 50),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.name, style: body(14, weight: FontWeight.w700)),
                    Text('${p.size} · MRP ${rupees(p.mrp)}', style: body(12, color: kMute)),
                  ]),
                ),
                IconButton(onPressed: () => s.toggleWishlist(p.id), icon: Icon(Icons.favorite, color: kRed)),
              ]),
            ),
          ),
        ),
    ]);
  }
}

class YourOrdersScreen extends StatelessWidget {
  const YourOrdersScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: kBg, appBar: simpleAppBar(t('Your orders')), body: const OrdersTab(header: false));
  }
}

// ---------------- About, privacy, notifications, FAQ ----------------
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) {
    Widget item(String a, String b) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a, style: body(14, weight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(b, style: body(13, color: kMute)),
          ]),
        );
    return _Page(title: t('About us'), children: [
      Center(
        child: Container(
          width: 110,
          height: 110,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: const Color(0xFFFDC732), borderRadius: BorderRadius.circular(26)),
          child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
        ),
      ),
      const SizedBox(height: 14),
      Center(child: Text('Apne Nukkad Ki Har Dukaan!', style: head(17, color: kGText))),
      const SizedBox(height: 16),
      CardBox(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          item('What we do', 'Nukad Kart lists kirana shops and moving sabzi/phal sellers within 500 m of you.'),
          item('Payments', 'You pay the shop or seller directly at delivery. Nukad Kart does not hold your money and does not give refunds.'),
          item('Complaints', 'We take your complaint, pass it to the store, keep a record, and can suspend stores found at fault.'),
          item('Grievance officer', '[Name] · [email] · [phone]'),
        ]),
      ),
      const SizedBox(height: 12),
      CardBox(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(children: [
          ListTile(title: Text('Terms of use', style: body(14, weight: FontWeight.w600)), trailing: Icon(Icons.chevron_right, color: kMute)),
          ListTile(title: Text('Privacy policy', style: body(14, weight: FontWeight.w600)), trailing: Icon(Icons.chevron_right, color: kMute)),
        ]),
      ),
      const SizedBox(height: 12),
      Center(child: Text('Version 0.2 (demo)', style: body(12, color: kMute))),
    ]);
  }
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return _Page(title: t('Account privacy'), children: [
      CardBox(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Orders not taken', style: body(14, weight: FontWeight.w700)),
            const Spacer(),
            Text('${s.strikes} of 3', style: body(13, color: s.strikes == 0 ? kG : kRed, weight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            for (var i = 0; i < 3; i++)
              Expanded(
                child: Container(
                  height: 8,
                  margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                  decoration: BoxDecoration(color: i < s.strikes ? kRed : kLine, borderRadius: BorderRadius.circular(4)),
                ),
              ),
          ]),
          const SizedBox(height: 8),
          Text('3 in 90 days blocks ordering on your Google account, this phone and your number.',
              style: body(12, color: kMute)),
        ]),
      ),
      const SizedBox(height: 12),
      CardBox(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Who sees your details', style: body(14, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('A store sees your name, number and address only after it accepts your order. '
              'A thela seller sees them only when you call or WhatsApp, or after they accept your request.',
              style: body(12.5, color: kMute)),
        ]),
      ),
      const SizedBox(height: 12),
      CardBox(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Moving sellers’ location', style: body(14, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('A thela’s live location is shown only while the seller has turned on “Live” in the Partner app, '
              'and only to customers within 500 m. The seller’s home or saved address is never shown. '
              'When they leave your 500 m, the map stops.',
              style: body(12.5, color: kMute)),
        ]),
      ),
      const SizedBox(height: 12),
      CardBox(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(children: [
          ListTile(
            leading: Icon(Icons.download_outlined, color: kG),
            title: Text('Download my data', style: body(14, weight: FontWeight.w600)),
            onTap: () => showToast(context, 'Request recorded. We’ll email your data.'),
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: kRed),
            title: Text('Request to delete account', style: body(14, color: kRed, weight: FontWeight.w600)),
            subtitle: Text('Pick a reason, then send the request', style: body(12, color: kMute)),
            trailing: Icon(Icons.chevron_right, color: kMute),
            onTap: () {
              if (!s.signedIn) {
                showToast(context, 'Log in first — guests have no account to delete.');
                return;
              }
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DeleteReasonsScreen()));
            },
          ),
        ]),
      ),
    ]);
  }
}

class NotificationPrefsScreen extends StatelessWidget {
  const NotificationPrefsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return _Page(title: t('Notification preferences'), children: [
      CardBox(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(children: [
          for (final e in s.notifPrefs.entries)
            SwitchListTile(
              value: e.value,
              title: Text(e.key, style: body(14.5, weight: FontWeight.w600)),
              onChanged: (v) => s.setNotif(e.key, v),
            ),
        ]),
      ),
      const SizedBox(height: 10),
      Text('Order updates can’t be fully turned off while an order is open.', style: body(12, color: kMute)),
    ]);
  }
}

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});
  static const faqs = [
    ['How do I pay?', 'You pay the store at delivery, by cash or the store’s UPI QR. There is no online payment in the app.'],
    ['Why only shops within 500 m?', 'Nukad Kart is for your own nukkad. Nearby shops deliver faster and you can also walk over to pick up.'],
    ['Can I cancel my order?', 'Yes, but only while the order is Placed (waiting for the store) or Accepted. Once the store marks it Packed, it can’t be cancelled from the app — call the store if you need a change. Cancelling after the store has accepted counts as 1 of the 3 “not taken” orders. You pay only at delivery, so there is nothing to refund.'],
    ['Why is there a ₹20 delivery fee?', 'Orders below ₹199 for home delivery have a ₹20 fee, paid to the store with your order. From ₹199 delivery is free. Pickup is always free.'],
    ['How do I delete my account?', 'Account → Account privacy → Request to delete account. Pick a reason and send the request. Order and complaint records are kept as the law requires.'],
    ['What if the store doesn’t accept?', 'If the store doesn’t accept within 5 minutes, the order is cancelled automatically. It is not counted against you.'],
    ['Can I order from two shops together?', 'No. One cart holds items from one shop. Adding from another shop asks you to start a new cart.'],
    ['Why does a thela show “Moving away” or “Not available”?', 'Thelas move. “Here now” means the seller is inside 500 m of your address and you can see them on the map. “Moving away” means they are past 400 m and getting further. “Not available” means they left your 500 m; the map stops and you get a notification when they come back. Their location is shown only while they are Live.'],
    ['How do I order from a thela?', 'Open Moving sellers, then call or WhatsApp the seller and pay in person. You can also request them for tomorrow.'],
    ['Who gives refunds?', 'The store. Nukad Kart passes your complaint to the store and records it, and can suspend stores at fault.'],
    ['Why was my account blocked?', '3 orders not taken (or cancelled after the store accepted) in 90 days block ordering. You can appeal to the grievance officer.'],
  ];
  @override
  Widget build(BuildContext context) {
    return _Page(title: t('FAQ'), children: [
      for (final f in faqs)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: CardBox(
            padding: EdgeInsets.zero,
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                iconColor: kG,
                collapsedIconColor: kMute,
                title: Text(f[0], style: body(14.5, weight: FontWeight.w700)),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                children: [Text(f[1], style: body(13, color: kMute))],
              ),
            ),
          ),
        ),
    ]);
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final AppState _s;

  @override
  void initState() {
    super.initState();
    _s = AppScope.read(context);
  }

  @override
  void dispose() {
    // Seen = read. The red count on the bell fades out when you go back.
    WidgetsBinding.instance.addPostFrameCallback((_) => _s.markAllRead());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return _Page(title: t('Notifications'), children: [
      if (s.notifications.isEmpty) _empty('🔔', 'No notifications yet', 'Order updates and thela replies show up here.'),
      for (final n in s.notifications)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: CardBox(
            border: n.read ? null : kG,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(backgroundColor: kGBg, child: Icon(Icons.notifications_none, color: kG)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(n.title, style: body(14, weight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(n.body, style: body(12.5, color: kMute)),
                  const SizedBox(height: 4),
                  Text(TimeOfDay.fromDateTime(n.at).format(context), style: body(11, color: kMute)),
                ]),
              ),
            ]),
          ),
        ),
    ]);
  }
}


// ---------------- Request to delete account ----------------
class DeleteReasonsScreen extends StatelessWidget {
  const DeleteReasonsScreen({super.key});
  static const reasons = [
    'I don’t want to use Nukad Kart anymore',
    'I’m using a different account',
    'I’m worried about my privacy',
    'Too many notifications',
    'The app isn’t working properly',
    'No shops near me',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    return _Page(title: 'Delete account', children: [
      Text('Request to delete account', style: head(24)),
      const SizedBox(height: 4),
      Text('Why would you like to delete your account?', style: body(13.5, color: kMute)),
      const SizedBox(height: 14),
      CardBox(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(children: [
          for (var i = 0; i < reasons.length; i++) ...[
            if (i > 0) Divider(height: 1, color: kLine, indent: 14, endIndent: 14),
            ListTile(
              title: Text(reasons[i], style: body(15)),
              trailing: Icon(Icons.chevron_right, color: kInk),
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => DeleteFeedbackScreen(reason: reasons[i]))),
            ),
          ],
        ]),
      ),
    ]);
  }
}

class DeleteFeedbackScreen extends StatefulWidget {
  final String reason;
  const DeleteFeedbackScreen({super.key, required this.reason});
  @override
  State<DeleteFeedbackScreen> createState() => _DeleteFeedbackScreenState();
}

class _DeleteFeedbackScreenState extends State<DeleteFeedbackScreen> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final open = s.orders.where((o) => o.isOpen).length;
    return _Page(title: 'Delete account', children: [
      Text(widget.reason, style: head(24)),
      const SizedBox(height: 6),
      Text('We hope to see you back. Tell us what we could do better.', style: body(13.5, color: kMute)),
      const SizedBox(height: 16),
      TextField(
        controller: _c,
        maxLines: 6,
        style: body(14),
        decoration: InputDecoration(
          labelText: 'Please share your feedback (optional)',
          alignLabelWithHint: true,
          filled: true,
          fillColor: kCard,
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: kLine)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: kG, width: 2)),
        ),
      ),
      const SizedBox(height: 16),
      PrimaryButton('Send delete request', color: kRed, onTap: open > 0 ? null : () => _send(context, s)),
      if (open > 0) ...[
        const SizedBox(height: 8),
        Text('You have $open open order${open > 1 ? 's' : ''}. Wait until it is delivered or cancelled.',
            style: body(12.5, color: kRed, weight: FontWeight.w600)),
      ],
      const SizedBox(height: 14),
      Text.rich(TextSpan(children: [
        TextSpan(text: 'Note*: ', style: body(12.5, color: kRed, weight: FontWeight.w700)),
        TextSpan(
            text: 'Your profile, addresses, wishlist and saved stores are removed from this phone and you are logged out. '
                'Order and complaint records are kept as the law requires.',
            style: body(12.5, color: kMute)),
      ])),
    ]);
  }

  Future<void> _send(BuildContext context, AppState s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        surfaceTintColor: kCard,
        title: Text('Delete your account?', style: head(18)),
        content: Text('This can’t be undone. You’ll need to sign up again to order.', style: body(14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('Cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Delete', style: body(14, color: kRed, weight: FontWeight.w700))),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    s.requestDeleteAccount(widget.reason, _c.text.trim());
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
    messenger.showSnackBar(const SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text('Delete request sent. Your data was removed from this phone.'),
    ));
  }
}


// ---------------- Terms & conditions ----------------
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});
  static const sections = [
    ['What Nukad Kart is', 'Nukad Kart lists registered kirana stores and moving sellers (thelas) within 500 m of your address. Orders are between you and the store or seller.'],
    ['Payment', 'You pay the store or seller directly at delivery or pickup — cash or their UPI. Nukad Kart does not collect payment and gives no refunds; any refund comes from the store. A ₹20 delivery fee below ₹199 is charged by the store.'],
    ['Orders and cancelling', 'A store has 5 minutes to accept, otherwise the order is cancelled. You can cancel while the order is Placed or Accepted. Cancelling after the store accepted, or not taking an order, counts towards the limit: 3 in 90 days blocks ordering on your Google account, phone and number.'],
    ['Moving sellers (thelas) and location', 'A thela seller sets a default address once, using the address form and the map. That address is never shown to customers. While the seller has turned on “Live” in the Partner app, their phone shares its current location with Nukad Kart, and customers within 500 m see where the thela is right now on a map. When the seller turns Live off, or moves outside a customer’s 500 m, the location is no longer shown to that customer. Customers must not use a seller’s location for anything other than buying from them.'],
    ['Seller obligations', 'Stores must upload a real photo of their own shop taken in the app at the shop’s location. A false photo or details can lead to suspension. Sellers set their own prices, which must not exceed MRP.'],
    ['Complaints', 'Report a problem from the order screen. We pass it to the store or seller, keep a record and may suspend those at fault. Our grievance officer acknowledges within 48 hours and resolves within one month.'],
    ['Your account', 'You can request to delete your account from Account privacy. Order and complaint records are kept as the law requires.'],
  ];
  @override
  Widget build(BuildContext context) {
    return _Page(title: 'Terms & conditions', children: [
      Text('Demo build — final wording to be reviewed by a lawyer.', style: body(12, color: kMute)),
      const SizedBox(height: 10),
      for (final sct in sections)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: CardBox(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(sct[0], style: body(14.5, weight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(sct[1], style: body(13, color: kMute)),
            ]),
          ),
        ),
    ]);
  }
}
