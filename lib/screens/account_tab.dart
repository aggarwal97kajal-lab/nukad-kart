import 'package:flutter/material.dart';
import '../l10n.dart';
import '../state/app_state.dart';
import '../widgets/ui.dart';
import 'account_pages.dart';
import 'login_screen.dart';

class AccountTab extends StatelessWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final initials = s.name.trim().isEmpty
        ? 'NK'
        : s.name.trim().split(RegExp(r'\s+')).take(2).map((w) => w.isEmpty ? '' : w[0].toUpperCase()).join();
    final themeTag = switch (s.theme) {
      AppTheme.light => t('LIGHT'),
      AppTheme.dark => t('DARK'),
      AppTheme.system => t('PHONE'),
    };
    final langTag = switch (s.lang) { 'hi' => 'हिन्दी', 'hg' => 'HINGLISH', _ => 'ENGLISH' };
    void open(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));

    return ListView(padding: EdgeInsets.zero, children: [
      Container(
        decoration: const BoxDecoration(
          color: kBrand,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 24),
            child: Column(children: [
              Container(
                width: 100,
                height: 100,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kOnBrand,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x59FFFFFF), width: 4),
                ),
                child: Text(initials, style: head(36, color: kBrand)),
              ),
              const SizedBox(height: 10),
              Text(s.name.isEmpty ? 'Guest' : s.name, style: head(23, color: kOnBrand)),
              const SizedBox(height: 4),
              Text(s.signedIn ? '+91 ${s.phone} · ${s.email}' : 'Browsing as guest',
                  textAlign: TextAlign.center,
                  style: body(13, color: const Color(0xCC21331B), weight: FontWeight.w600)),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () async {
                  if (s.signedIn) {
                    open(const EditProfileScreen());
                  } else {
                    await googleSignInFlow(context);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0x1F21331B), borderRadius: BorderRadius.circular(16)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(s.signedIn ? Icons.edit_outlined : Icons.login, size: 14, color: kOnBrand),
                    const SizedBox(width: 6),
                    Text(s.signedIn ? t('Edit profile') : t('Log in'), style: body(12.5, color: kOnBrand, weight: FontWeight.w700)),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 26),
        child: Column(children: [
          _Section(children: [
            _Row(
              icon: s.theme == AppTheme.dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
              title: t('Appearance'),
              tag: themeTag,
              onTap: () => showAppearanceSheet(context),
            ),
            _Row(icon: Icons.translate, title: t('Language'), tag: langTag, onTap: () => showLanguageSheet(context)),
          ]),
          const SizedBox(height: 12),
          _Section(title: t('Your information'), children: [
            _Row(icon: Icons.menu_book_outlined, title: t('Address book'), onTap: () => open(const AddressBookScreen())),
            _Row(
                icon: Icons.storefront_outlined,
                title: t('Bookmarked stores'),
                onTap: () => open(const BookmarksScreen())),
            _Row(icon: Icons.favorite_border, title: t('Your wishlist'), onTap: () => open(const WishlistScreen())),
            _Row(icon: Icons.shopping_bag_outlined, title: t('Your orders'), onTap: () => open(const YourOrdersScreen())),
          ]),
          const SizedBox(height: 12),
          _Section(title: t('Other information'), children: [
            _Row(icon: Icons.ios_share, title: t('Share this app'), onTap: () => shareApp(context)),
            _Row(icon: Icons.info_outline, title: t('About us'), onTap: () => open(const AboutScreen())),
            _Row(icon: Icons.lock_outline, title: t('Account privacy'), onTap: () => open(const PrivacyScreen())),
            _Row(
                icon: Icons.notifications_none,
                title: t('Notification preferences'),
                onTap: () => open(const NotificationPrefsScreen())),
            _Row(icon: Icons.help_outline, title: t('FAQ'), onTap: () => open(const FaqScreen())),
          ]),
          const SizedBox(height: 12),
          if (s.signedIn)
            _Section(children: [
              _Row(icon: Icons.logout, title: t('Log out'), onTap: () => _logout(context)),
            ]),
          const SizedBox(height: 12),
          Text('Nukad Kart · v0.3 demo', style: body(11.5, color: kMute)),
        ]),
      ),
    ]);
  }

  Future<void> _logout(BuildContext context) async {
    final choice = await showChoiceSheet(
      context,
      title: t('Log out?'),
      subtitle: t('Choose where you want to log out'),
      options: [
        ChoiceOption('this', t('This device only'), t('You stay logged in on other phones'), Icons.smartphone,
            danger: true),
        ChoiceOption('all', t('All devices'), t('Logs out everywhere, including this phone'), Icons.devices,
            danger: true),
      ],
      showCancel: true,
    );
    if (choice == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    AppScope.read(context).signOut();
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
    messenger.showSnackBar(SnackBar(
      content: Text(choice == 'all' ? 'Logged out from all devices' : 'Logged out from this device'),
      behavior: SnackBarBehavior.floating,
    ));
  }
}

class _Section extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  const _Section({this.title, required this.children});
  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) rows.add(Divider(height: 1, color: kLine, indent: 16, endIndent: 16));
    }
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(18), border: Border.all(color: kLine)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (title != null)
          Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 4), child: Text(title!, style: head(17))),
        ...rows,
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? tag;
  final VoidCallback onTap;
  const _Row({required this.icon, required this.title, this.tag, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(children: [
          Icon(icon, color: kG, size: 22),
          const SizedBox(width: 14),
          Expanded(child: Text(title, style: body(15.5, weight: FontWeight.w500))),
          if (tag != null) ...[
            Text(tag!, style: body(12, color: kMute, weight: FontWeight.w700).copyWith(letterSpacing: 0.5)),
            Icon(Icons.keyboard_arrow_down, color: kMute, size: 18),
          ] else
            Icon(Icons.chevron_right, color: kMute, size: 20),
        ]),
      ),
    );
  }
}
