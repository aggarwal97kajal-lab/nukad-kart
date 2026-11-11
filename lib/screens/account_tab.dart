import 'package:flutter/material.dart';
import '../data/demo_data.dart';
import '../state/app_state.dart';
import '../widgets/ui.dart';
import 'login_screen.dart';

class AccountTab extends StatelessWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final initials = s.name.isEmpty
        ? 'NK'
        : s.name.trim().split(RegExp(r'\s+')).take(2).map((w) => w.isEmpty ? '' : w[0].toUpperCase()).join();
    return ListView(padding: EdgeInsets.zero, children: [
      Container(
        decoration: const BoxDecoration(color: kGD, borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Row(children: [
              CircleAvatar(
                  radius: 28,
                  backgroundColor: kLime,
                  child: Text(initials, style: head(19, color: kGD))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.name.isEmpty ? 'Guest' : s.name, style: head(18, color: Colors.white)),
                  Text('+91 ${s.phone} · ${s.email}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, color: const Color(0xFFD7EED0))),
                ]),
              ),
            ]),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CardBox(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('Not-taken orders', style: body(14, weight: FontWeight.w700)),
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
                      decoration: BoxDecoration(
                          color: i < s.strikes ? kRed : kLine, borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
              ]),
              const SizedBox(height: 8),
              Text('3 strikes in 90 days blocks ordering. Cancelling before the store accepts is not a strike.',
                  style: body(11.5, color: kMute)),
            ]),
          ),
          const SizedBox(height: 14),
          Text('Notifications', style: head(16)),
          const SizedBox(height: 8),
          if (s.notifications.isEmpty)
            Text('Nothing yet.', style: body(13, color: kMute))
          else
            CardBox(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(children: [
                for (final n in s.notifications.take(8))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                        backgroundColor: kGBg, child: Icon(Icons.notifications_none, color: kG)),
                    title: Text(n.title, style: body(13.5, weight: FontWeight.w700)),
                    subtitle: Text(n.body, style: body(12, color: kMute)),
                  ),
              ]),
            ),
          const SizedBox(height: 14),
          Text('My ratings', style: head(16)),
          const SizedBox(height: 8),
          if (s.ratings.isEmpty)
            Text('You haven’t rated any store or seller yet.', style: body(13, color: kMute))
          else
            CardBox(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(children: [
                for (final e in s.ratings.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Expanded(
                          child: Text(_vendorName(e.key), style: body(13.5, weight: FontWeight.w600))),
                      StarRow(value: e.value, size: 16),
                    ]),
                  ),
              ]),
            ),
          const SizedBox(height: 14),
          CardBox(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Column(children: [
              _tile(Icons.location_on_outlined, 'Address', s.address),
              _tile(Icons.description_outlined, 'Terms & Privacy Policy', 'Payments are between you and the store'),
              _tile(Icons.support_agent, 'Grievance officer', '[Name] · [email] · [phone]'),
              _tile(Icons.info_outline, 'About this build', 'Demo data · no real orders, payments or sign-in'),
            ]),
          ),
          const SizedBox(height: 16),
          PrimaryButton('Sign out', outline: true, color: kRed, onTap: () {
            s.signOut();
            Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
          }),
          const SizedBox(height: 10),
          Center(child: Text('Nukad Kart · v0.1 demo', style: body(11.5, color: kMute))),
        ]),
      ),
    ]);
  }

  String _vendorName(String id) {
    for (final st in kStores) {
      if (st.id == id) return st.name;
    }
    for (final t in kThelas) {
      if (t.id == id) return t.name;
    }
    return id;
  }

  Widget _tile(IconData icon, String title, String sub) => ListTile(
        leading: Icon(icon, color: kG),
        title: Text(title, style: body(14, weight: FontWeight.w600)),
        subtitle: Text(sub, style: body(12, color: kMute)),
      );
}
