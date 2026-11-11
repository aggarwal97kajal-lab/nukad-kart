import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'l10n.dart';
import 'state/app_state.dart';
import 'widgets/ui.dart';
import 'screens/splash_screen.dart';
import 'data/demo_data.dart';
import 'widgets/cart_widgets.dart';
import 'state/thela_tracker.dart';

final navKey = GlobalKey<NavigatorState>();
final messengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // The green launch screen stays up while saved settings load (a few ms).
  final state = AppState();
  await state.load();
  runApp(NukadKartApp(state: state));
}

class NukadKartApp extends StatelessWidget {
  final AppState state;
  const NukadKartApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) => AppScope(state: state, child: const _Root());
}

/// Applies Appearance (light / dark / same as phone) and Language, then
/// rebuilds every open screen so the change shows everywhere at once.
class _Root extends StatefulWidget {
  const _Root();
  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> with WidgetsBindingObserver {
  String _applied = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final s = AppScope.read(context);
    ThelaTracker.instance.onBackInArea = (thelaId) {
      final th = thelaById(thelaId);
      s.addNotification('${th.name} is back near you', 'Within 500 m of ${s.address} now. Call or WhatsApp to buy.');
      messengerKey.currentState?.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: gDark ? Color(0xFFF3F0E2) : Color(0xFF21331B),
        content: Text('🛒 ${th.name} is back within 500 m',
            style: TextStyle(color: gDark ? Color(0xFF21331B) : Colors.white, fontWeight: FontWeight.w600)),
      ));
    };
    s.onOtp = (o) {
      messengerKey.currentState?.showSnackBar(SnackBar(
        duration: Duration(seconds: 8),
        behavior: SnackBarBehavior.floating,
        backgroundColor: gDark ? Color(0xFFF3F0E2) : Color(0xFF21331B),
        content: Text('🔐 Order packed. Your delivery code is ${o.otp}',
            style: TextStyle(color: gDark ? Color(0xFF21331B) : Colors.white, fontWeight: FontWeight.w700)),
      ));
    };
    s.onBackInStock = (storeId, productId) {
      final p = productById(productId);
      final st = storeById(storeId);
      messengerKey.currentState?.showSnackBar(SnackBar(
        duration: Duration(seconds: 8),
        behavior: SnackBarBehavior.floating,
        backgroundColor: gDark ? Color(0xFFEEF3EF) : Color(0xFF14201A),
        content: Text('🔔 ${p.name} ${p.size} is back at ${st.name}',
            style: TextStyle(color: gDark ? Color(0xFF14201A) : Colors.white, fontWeight: FontWeight.w600)),
        action: SnackBarAction(
          label: 'Add to cart',
          textColor: kLime,
          onPressed: () {
            final ctx = navKey.currentContext;
            if (ctx != null) tryAddToCart(ctx, storeId, productId);
          },
        ),
      ));
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() => setState(() {});

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
    final s = AppScope.of(context);
    final phoneDark = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    gDark = s.theme == AppTheme.dark || (s.theme == AppTheme.system && phoneDark);
    gLang = s.lang;
    final key = '$gDark-$gLang';
    if (_applied.isNotEmpty && key != _applied) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildAll());
    }
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
      scaffoldMessengerKey: messengerKey,
      title: 'Nukad Kart',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: brightness,
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF315426), brightness: brightness, primary: kG, surface: kCard),
        scaffoldBackgroundColor: kBg,
        canvasColor: kCard,
        dividerColor: kLine,
        fontFamily: 'NotoSans',
      ),
      // Keep every screen above the phone's own buttons / gesture bar
      // (Android 15+ draws apps under them by default).
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final b = mq.viewPadding.bottom;
        // Colour behind the phone's buttons follows the app's Light / Dark setting.
        final navStyle = SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: gDark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: kCard,
          systemNavigationBarDividerColor: kLine,
          systemNavigationBarIconBrightness: gDark ? Brightness.light : Brightness.dark,
          systemNavigationBarContrastEnforced: false,
        );
        if (b == 0) return AnnotatedRegion<SystemUiOverlayStyle>(value: navStyle, child: child!);
        return AnnotatedRegion<SystemUiOverlayStyle>(value: navStyle, child: ColoredBox(
          color: kCard,
          child: Padding(
            padding: EdgeInsets.only(bottom: b),
            child: MediaQuery(
              data: mq.removePadding(removeBottom: true).removeViewPadding(removeBottom: true).copyWith(
                    viewInsets: mq.viewInsets.copyWith(bottom: (mq.viewInsets.bottom - b).clamp(0.0, double.infinity)),
                  ),
              child: child!,
            ),
          ),
        ));
      },
      home: const SplashScreen(),
    );
  }
}
