import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api.dart';
import 'session.dart';
import 'prefs.dart';
import 'ui.dart';
import 'screens/login.dart';
import 'screens/register.dart';
import 'screens/shell.dart';
import 'screens/staff.dart';
import 'screens/agreement.dart';
import 'screens/docs.dart';
import 'screens/phone.dart';
import 'screens/admin.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await prefs.load();
  await session.load();
  runApp(const PartnerApp());
}

final navKey = GlobalKey<NavigatorState>();

class PartnerApp extends StatefulWidget {
  const PartnerApp({super.key});
  @override
  State<PartnerApp> createState() => _PartnerAppState();
}

class _PartnerAppState extends State<PartnerApp> with WidgetsBindingObserver {
  String _applied = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    prefs.addListener(_changed);
  }

  @override
  void dispose() {
    prefs.removeListener(_changed);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  void didChangePlatformBrightness() => setState(() {});

  /// Colours and words are read when a screen builds, so after a theme/language change every open screen is rebuilt.
  void _rebuildAll() {
    final ctx = navKey.currentContext;
    if (ctx == null) return;
    void mark(Element e) {
      e.markNeedsBuild();
      e.visitChildren(mark);
    }

    (ctx as Element).visitChildren(mark);
  }

  @override
  Widget build(BuildContext context) {
    final phoneDark = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    gDark = prefs.theme == AppTheme.dark || (prefs.theme == AppTheme.phone && phoneDark);
    gLang = prefs.lang;
    final key = '$gDark-$gLang';
    if (_applied.isNotEmpty && key != _applied) WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildAll());
    _applied = key;
    final brightness = gDark ? Brightness.dark : Brightness.light;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: gDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: kCard,
      systemNavigationBarIconBrightness: gDark ? Brightness.light : Brightness.dark,
    ));
    return MaterialApp(
      navigatorKey: navKey,
      title: tr('Nukad Partner'),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: brightness,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF315426), brightness: brightness, primary: kAct, onPrimary: kOnAct, surface: kCard)
            .copyWith(
          surfaceTint: Colors.transparent,
          surfaceContainerLowest: kBg,
          surfaceContainerLow: kCard,
          surfaceContainer: kCard,
          surfaceContainerHigh: kSurf,
          surfaceContainerHighest: kSurf,
          onSurface: kInk,
          onSurfaceVariant: kMute,
          outline: kLine,
          outlineVariant: kLine,
        ),
        // Switches readable in both themes: ON = coloured track with a contrasting knob, OFF = grey.
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected)
              ? (gDark ? const Color(0xFF21331B) : Colors.white)
              : (gDark ? const Color(0xFF9E9E9E) : const Color(0xFF8A8A8A))),
          trackColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected)
              ? (st.contains(WidgetState.disabled) ? kAct.withValues(alpha: 0.5) : kAct)
              : (gDark ? const Color(0xFF3A3A3A) : const Color(0xFFE4E1D6))),
          trackOutlineColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected)
              ? Colors.transparent
              : (gDark ? const Color(0xFF5A5A5A) : const Color(0xFFB8B4A6))),
          thumbIcon: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected)
              ? Icon(Icons.check, size: 16, color: kAct)
              : null),
        ),
        scaffoldBackgroundColor: kBg,
        canvasColor: kCard,
        dividerColor: kLine,
        fontFamily: 'NotoSans',
        fontFamilyFallback: const ['NotoSansDevanagari'],
      ),
      home: const Gate(),
    );
  }
}

/// First open: language and theme (like the customer app).
class WelcomePrefsScreen extends StatelessWidget {
  const WelcomePrefsScreen({super.key});

  Widget _seg(List<(String, String, IconData?)> opts, String value, ValueChanged<String> on) => Row(children: [
        for (final (v, label, icon) in opts)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: GestureDetector(
                onTap: () => on(v),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: v == value ? kAct : kCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: v == value ? kAct : kLine),
                  ),
                  child: Column(children: [
                    if (icon != null) Icon(icon, color: v == value ? kOnAct : kMute, size: 20),
                    Text(label, style: tx(13.5, color: v == value ? kOnAct : kInk, weight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
          ),
      ]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          const SizedBox(height: 20),
          Center(child: ClipRRect(borderRadius: BorderRadius.circular(28), child: Image.asset('assets/logo.png', width: 130))),
          const SizedBox(height: 14),
          Center(child: Text(tr('Nukad Partner'), style: tx(24, weight: FontWeight.w800))),
          const SizedBox(height: 28),
          Text(tr('Choose language · भाषा चुनें'), style: tx(15, weight: FontWeight.w800)),
          const SizedBox(height: 10),
          _seg([('en', tr('English'), null), ('hi', 'हिन्दी', null)], prefs.lang, prefs.setLang),
          const SizedBox(height: 22),
          Text(t('Theme'), style: tx(15, weight: FontWeight.w800)),
          const SizedBox(height: 10),
          _seg([
            ('light', t('Light'), Icons.light_mode_outlined),
            ('dark', t('Dark'), Icons.dark_mode_outlined),
            ('phone', t('Phone'), Icons.phone_android),
          ], prefs.theme.name, (v) => prefs.setTheme(AppTheme.values.firstWhere((x) => x.name == v))),
          const SizedBox(height: 30),
          Btn(t('Continue'), onTap: prefs.setChosen),
        ]),
      ),
    );
  }
}

/// Before login: shop or thela. Decides the whole sign-up path.
class KindScreen extends StatelessWidget {
  const KindScreen({super.key});

  Widget _card(String kind, IconData icon, String title, String sub) {
    final on = prefs.kind == kind;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => prefs.setKind(kind),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: on ? kOkBg : kCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: on ? kAct : kLine, width: 2),
          ),
          child: Row(children: [
            Icon(icon, size: 40, color: kAct),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: tx(17, weight: FontWeight.w800)),
                Text(sub, style: tx(12.5, color: kMute)),
              ]),
            ),
            Icon(on ? Icons.radio_button_checked : Icons.radio_button_off, color: kAct),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: prefs,
      builder: (context, _) => Scaffold(
        appBar: bar(t('Who are you?')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const SizedBox(height: 8),
          _card('shop', Icons.storefront_outlined, t('Shop / kirana'), t('A shop at one place · PAN, GST, FSSAI')),
          _card('thela', Icons.shopping_cart_outlined, t('Thela (moving)'), t('Vegetables, fruits, chaat · only Aadhaar')),
          const SizedBox(height: 12),
          Btn(t('Continue'), onTap: prefs.kind.isEmpty ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()))),
          const SizedBox(height: 14),
          Center(
            child: TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffLoginScreen())),
              child: Text(t('Staff login'), style: tx(15, color: kAct, weight: FontWeight.w800)),
            ),
          ),
          Center(child: Text(t('Login with the mobile number your store owner added.'), textAlign: TextAlign.center, style: tx(12, color: kMute))),
        ]),
      ),
    );
  }
}

/// Login → register the shop → home.
class Gate extends StatefulWidget {
  const Gate({super.key});
  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    session.addListener(_changed);
    prefs.addListener(_changed);
    _start();
  }

  @override
  void dispose() {
    session.removeListener(_changed);
    prefs.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _start() async {
    if (!session.signedIn) {
      setState(() => _loading = false);
      return;
    }
    // Saved details from last time: show the app at once, update in the background.
    if (session.hasCache && _loading) setState(() => _loading = false);
    try {
      await session.refresh();
      _error = null;
    } on ApiError catch (e) {
      if (e.code == 'not_signed_in') {
        await session.signOut();
      } else if (!session.hasCache) {
        _error = e.message;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: kBrand,
        body: Center(child: Image.asset('assets/logo.png', width: 180)),
      );
    }
    if (!prefs.chosen) return const WelcomePrefsScreen();
    if (!session.signedIn) return const KindScreen();
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_error!, textAlign: TextAlign.center, style: tx(15)),
              const SizedBox(height: 16),
              Btn(tr('Try again'), onTap: () {
                setState(() => _loading = true);
                _start();
              }),
            ]),
          ),
        ),
      );
    }
    // Shop staff: only orders / deliveries.
    if (session.staffInfo != null) return const StaffShell();
    // Steps: phone OTP → business details → documents → agreement → waiting for Nukad team → home.
    // Admin without a shop: straight to the admin screen.
    if (session.admin && session.store == null) return const AdminScreen(root: true);
    if (!session.phoneVerified) return const PhoneScreen();
    if (session.store == null) return const RegisterScreen();
    if (session.store!['docsComplete'] != true) return const DocsScreen();
    if (session.store!['agreementSigned'] != true) return const AgreementScreen();
    return const PartnerShell();
  }
}
