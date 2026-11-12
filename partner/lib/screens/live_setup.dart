import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../thela_location.dart';
import '../ui.dart';

/// Before a thela goes LIVE: location on, precise location allowed, battery not limited,
/// and (on phones that need it) Autostart. Returns true when ready.
class LiveSetupScreen extends StatefulWidget {
  const LiveSetupScreen({super.key});
  @override
  State<LiveSetupScreen> createState() => _LiveSetupScreenState();
}

class _LiveSetupScreenState extends State<LiveSetupScreen> with WidgetsBindingObserver {
  bool perm = false, precise = false, gps = false, battery = false, autostartDone = false, needAuto = false, _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Coming back from Settings: check again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final p = await ThelaLocation.locationAllowed();
    var pr = false;
    if (p) {
      try {
        pr = await Geolocator.getLocationAccuracy() == LocationAccuracyStatus.precise;
      } catch (_) {
        pr = true;
      }
    }
    final g = await ThelaLocation.locationOn();
    final b = await ThelaLocation.batteryFree();
    final br = await ThelaLocation.brand();
    if (!mounted) return;
    setState(() {
      perm = p;
      precise = pr;
      gps = g;
      battery = b;
      needAuto = ThelaLocation.needsAutostart(br);
      _loading = false;
    });
  }

  Future<void> _askLocation() async {
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.deniedForever || (p != LocationPermission.denied && !precise && perm)) {
      await Geolocator.openAppSettings();
    }
    _check();
  }

  bool get ready => perm && precise && gps && battery && (!needAuto || autostartDone);

  Widget _row(bool ok, String title, String why, String button, VoidCallback onTap) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ok ? kOkBg : kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ok ? kAct : kLine),
        ),
        child: Row(children: [
          Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked, color: ok ? const Color(0xFF315426) : kMute),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: tx(14.5, weight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(why, style: tx(12, color: kMute)),
            ]),
          ),
          if (!ok) ...[const SizedBox(width: 8), FilledButton(onPressed: onTap, child: Text(button))],
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: bar(t('Set up your phone')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              Text(t('Customers see your thela on the map only while your location is coming. Do these once:'), style: tx(13.5)),
              const SizedBox(height: 14),
              _row(gps, t('Turn on location'), t('Phone location (GPS) must be on.'), t('Turn on'),
                  () async {
                await Geolocator.openLocationSettings();
              }),
              _row(perm && precise, t('Allow precise location'), t('Choose “While using the app” and keep “Precise” on.'), t('Allow'),
                  _askLocation),
              _row(battery, t('Don’t limit battery'), t('Otherwise the phone stops your location after a few minutes. Tap Allow.'), t('Allow'),
                  () async {
                await ThelaLocation.askBattery();
              }),
              if (needAuto)
                _row(autostartDone, t('Turn on Autostart'), t('Your phone has its own setting. Find Nukad Partner and turn it on, then come back.'),
                    t('Open'), () async {
                  await ThelaLocation.openAutostart();
                  if (mounted) setState(() => autostartDone = true);
                }),
              const SizedBox(height: 6),
              Box(
                color: kSurf,
                child: Text(
                    t('While you are LIVE you will see a notification “You are LIVE on Nukad Kart”. That keeps your location going. Battery use is low: the phone sends only when you move about 75 m, and once every 4 minutes when you stand.'),
                    style: tx(12.5)),
              ),
              const SizedBox(height: 16),
              Btn(ready ? t('Go LIVE') : t('Finish the steps above'), onTap: ready ? () => Navigator.pop(context, true) : null),
            ]),
    );
  }
}
