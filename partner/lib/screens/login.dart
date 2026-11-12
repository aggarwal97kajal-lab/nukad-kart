import 'package:flutter/material.dart';
import '../api.dart';
import '../session.dart';
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
      await session.signIn();
    } on ApiError catch (e) {
      if (mounted) toast(context, e.code.startsWith('google_') ? 'Google sign-in failed (${e.code.substring(7)}). Try again.' : e.message);
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
            const Spacer(),
            ClipRRect(borderRadius: BorderRadius.circular(36), child: Image.asset('assets/logo.png', width: 200)),
            const SizedBox(height: 20),
            Text('Nukad Partner', style: tx(28, weight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('For kirana shops and thelas on Nukad Kart.\nGet orders from customers within 500 m.',
                textAlign: TextAlign.center, style: tx(14.5, color: kInk)),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: _busy ? null : _login,
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: Text(_busy ? 'Signing in…' : 'Continue with Google', style: tx(16, weight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 12),
            Text('By continuing you agree to the Nukad Kart partner terms.', style: tx(11.5, color: kInk)),
          ]),
        ),
      ),
    );
  }
}
