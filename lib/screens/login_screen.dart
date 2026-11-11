import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../widgets/ui.dart';
import 'phone_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Column(children: [
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: kGD,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 36, 24, 34),
              child: Column(children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
                  padding: const EdgeInsets.all(8),
                  child: Image.asset('assets/images/logo.png'),
                ),
                const SizedBox(height: 14),
                Text('Nukad Kart', style: head(28, color: Colors.white)),
                const SizedBox(height: 4),
                Text('Apne Nukkad Ki Har Dukaan!',
                    style: body(13.5, color: const Color(0xFFBDE89A), weight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 30, 22, 20),
            child: Column(children: [
              Text('Shops and sellers within 500 m of you', textAlign: TextAlign.center, style: head(21)),
              const SizedBox(height: 8),
              Text('Order from nearby kirana stores and find sabzi thelas on your street.',
                  textAlign: TextAlign.center, style: body(14, color: kMute)),
              const SizedBox(height: 28),
              SizedBox(
                height: 56,
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFCFD8D1), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    AppScope.read(context).signIn();
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const PhoneScreen()));
                  },
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF1F3F4)),
                      child: const Text('G',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: Color(0xFF4285F4))),
                    ),
                    const SizedBox(width: 12),
                    Text('Continue with Google', style: head(16, weight: FontWeight.w500)),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              Text('Demo build: sign-in is simulated, no real Google account is used.',
                  textAlign: TextAlign.center, style: body(11.5, color: kMute)),
              const Spacer(),
              Text('By continuing you agree to the Terms and Privacy Policy.',
                  textAlign: TextAlign.center, style: body(11.5, color: kMute)),
            ]),
          ),
        ),
      ]),
    );
  }
}
