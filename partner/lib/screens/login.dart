import 'package:flutter/material.dart';
import '../api.dart';
import '../session.dart';
import '../prefs.dart';
import '../ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;

  Future<void> _login() async {
    setState(() => _busy = true);
    try {
      final ok = await session.signIn();
      if (ok && mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on ApiError catch (e) {
      if (mounted) toast(context, e.code.startsWith('google_') ? '${t('Google sign-in failed. Try again.')} (${e.code.substring(7)})' : e.message);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBrand,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Align(
              alignment: Alignment.topRight,
              child: IconTheme(data: const IconThemeData(color: Color(0xFF21331B)), child: const PrefsButtons()),
            ),
            const Spacer(),
            ClipRRect(borderRadius: BorderRadius.circular(36), child: Image.asset('assets/logo.png', width: 200)),
            const SizedBox(height: 20),
            Text(tr('Nukad Partner'), style: tx(28, color: const Color(0xFF21331B), weight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(t('Get orders from customers within 500 m.'), textAlign: TextAlign.center, style: tx(14.5, color: const Color(0xFF21331B))),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => Navigator.maybePop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(20)),
                child: Text('${prefs.kind == 'thela' ? t('Thela (moving)') : t('Shop / kirana')} · ${t('Change')}',
                    style: tx(13, color: const Color(0xFF21331B), weight: FontWeight.w700)),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: _busy ? null : _login,
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: Text(_busy ? t('Signing in…') : t('Continue with Google'), style: tx(16, color: const Color(0xFF21331B), weight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 12),
            Text(t('By continuing you agree to the Nukad Kart partner terms.'), style: tx(11.5, color: const Color(0xFF21331B))),
          ]),
        ),
      ),
    );
  }
}
