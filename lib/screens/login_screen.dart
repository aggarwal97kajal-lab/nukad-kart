import 'package:flutter/material.dart';
import '../l10n.dart';
import '../state/app_state.dart';
import '../widgets/ui.dart';
import 'personal_details_screen.dart';
import 'home_shell.dart';
import 'account_pages.dart';
import '../services/api.dart';
import '../services/google_auth.dart';
import '../services/device_name.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Column(children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: kBrand,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 10, 16, 34),
              child: Column(children: [
                Row(children: [
                  _chip(
                      Icons.translate,
                      switch (AppScope.of(context).lang) { 'hi' => 'हिन्दी', 'hg' => 'Hinglish', _ => 'English' },
                      () => showLanguageSheet(context)),
                  SizedBox(width: 8),
                  _chip(
                      gDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                      switch (AppScope.of(context).theme) {
                        AppTheme.light => t('Light'),
                        AppTheme.dark => t('Dark'),
                        AppTheme.system => t('Phone'),
                      },
                      () => showAppearanceSheet(context)),
                  Spacer(),
                  TextButton(
                    onPressed: () => _skip(context),
                    style: TextButton.styleFrom(
                        backgroundColor: kOnBrand,
                        foregroundColor: kBrand,
                        shape: StadiumBorder(),
                        padding: EdgeInsets.symmetric(horizontal: 16)),
                    child: Text(t('Skip'), style: body(13.5, color: kBrand, weight: FontWeight.w700)),
                  ),
                ]),
                Container(
                  width: 120,
                  height: 120,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(color: Color(0xFFFDC732), borderRadius: BorderRadius.circular(30)),
                  child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
                ),
                SizedBox(height: 14),
                Text('Nukad Kart', style: head(28, color: kOnBrand)),
                SizedBox(height: 4),
                Text('Apne Nukkad Ki Har Dukaan!',
                    style: body(14, color: Color(0xCC21331B), weight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(22, 30, 22, 20),
            child: Column(children: [
              Text(t('Shops and sellers within 500\u00A0m of you'), textAlign: TextAlign.center, style: head(21)),
              SizedBox(height: 8),
              Text(t('Browse freely. Log in only when you place your first order.'),
                  textAlign: TextAlign.center, style: body(14, color: kMute)),
              SizedBox(height: 28),
              GoogleButton(
                text: t('Continue with Google'),
                onTap: () async {
                  final ok = await googleSignInFlow(context);
                  if (ok && context.mounted) {
                    Navigator.of(context)
                        .pushAndRemoveUntil(MaterialPageRoute(builder: (_) => HomeShell()), (_) => false);
                  }
                },
              ),
              SizedBox(height: 14),
              GestureDetector(
                onTap: () => _skip(context),
                child: Text('${t('Explore without login')} →', style: body(14, color: kG, weight: FontWeight.w700)),
              ),
              Spacer(),
              Wrap(alignment: WrapAlignment.center, children: [
                Text('By continuing you agree to the ', style: body(11.5, color: kMute)),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsScreen())),
                  child: Text('Terms', style: body(11.5, color: kG, weight: FontWeight.w700).copyWith(decoration: TextDecoration.underline)),
                ),
                Text(' and ', style: body(11.5, color: kMute)),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
                  child: Text('Privacy Policy', style: body(11.5, color: kG, weight: FontWeight.w700).copyWith(decoration: TextDecoration.underline)),
                ),
                Text('.', style: body(11.5, color: kMute)),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _chip(IconData icon, String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 36,
          padding: EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: Color(0x1A21331B), borderRadius: BorderRadius.circular(18)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: kOnBrand),
            SizedBox(width: 6),
            Text(label, style: body(13, color: kOnBrand, weight: FontWeight.w700)),
            Icon(Icons.keyboard_arrow_down, size: 16, color: kOnBrand),
          ]),
        ),
      );

  void _skip(BuildContext context) {
    AppScope.read(context).continueAsGuest();
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => HomeShell()), (_) => false);
  }
}

/// Real Google sign-in, then the server login, then the one-time details screen for new accounts.
/// Returns true when the user is signed in with a complete profile.
Future<bool> googleSignInFlow(BuildContext context) async {
  final s = AppScope.read(context);
  GoogleUser? g;
  try {
    g = await googleAuth.signIn();
  } on GoogleAuthException catch (e) {
    if (context.mounted) showToast(context, e.message);
    return false;
  }
  if (g == null || !context.mounted) return false;

  // Server login. If the server cannot be reached, carry on with what is saved on this phone.
  Map<String, dynamic>? server;
  try {
    server = await api.googleLogin(g.idToken, device: {...await deviceInfo(), 'id': s.installId});
  } on ApiException catch (e) {
    if (!e.unavailable) {
      await googleAuth.signOut();
      if (context.mounted) {
        showToast(context, e.code == 'email_used_by_partner' ? e.message : 'Sign-in was not accepted (${e.code}). Try again.');
      }
      return false;
    }
  }
  if (!context.mounted) return false;

  var known = s.signIn(g.email);
  if (server != null) {
    s.apiToken = '${server['token'] ?? ''}';
    if (s.name.isEmpty && g.name.isNotEmpty) s.name = g.name;
    s.applyServerProfile(server);
    known = s.profileComplete;
  } else if (s.name.isEmpty && g.name.isNotEmpty) {
    s.name = g.name;
  }
  if (known) {
    showToast(context, 'Welcome back${s.name.isEmpty ? '' : ', ${s.name.split(' ').first}'}');
    return true;
  }
  final ok = await Navigator.push<bool>(
      context, MaterialPageRoute(builder: (_) => PersonalDetailsScreen()));
  if (ok == true && s.profileComplete) return true;
  s.cancelSignIn();
  await googleAuth.signOut();
  return false;
}

/// Bottom sheet shown when a guest tries to order (G03).
Future<bool> requireLogin(BuildContext context) async {
  final s = AppScope.read(context);
  if (s.signedIn) return true;
  final go = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: kCard,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 14, 18, 14),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(
              child: Container(
                  width: 44, height: 5, decoration: BoxDecoration(color: kLine, borderRadius: BorderRadius.circular(3)))),
          SizedBox(height: 14),
          Text('Log in to place your order', style: head(20)),
          SizedBox(height: 6),
          Text('Your cart is saved. The store needs your name, number and address to deliver.',
              style: body(13.5, color: kMute)),
          SizedBox(height: 16),
          GoogleButton(text: t('Continue with Google'), onTap: () => Navigator.pop(ctx, true)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Keep browsing', style: body(13.5, color: kMute, weight: FontWeight.w700))),
        ]),
      ),
    ),
  );
  if (go != true || !context.mounted) return false;
  return googleSignInFlow(context);
}
