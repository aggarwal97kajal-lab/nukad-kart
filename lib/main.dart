import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'l10n.dart';
import 'state/app_state.dart';
import 'widgets/ui.dart';
import 'screens/splash_screen.dart';

final navKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(NukadKartApp(state: AppState()));
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
    return MaterialApp(
      navigatorKey: navKey,
      title: 'Nukad Kart',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: brightness,
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1E7A2E), brightness: brightness, primary: kG, surface: kCard),
        scaffoldBackgroundColor: kBg,
        canvasColor: kCard,
        dividerColor: kLine,
        fontFamily: 'Inter',
      ),
      home: const SplashScreen(),
    );
  }
}
