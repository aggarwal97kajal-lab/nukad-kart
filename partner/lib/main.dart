import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api.dart';
import 'session.dart';
import 'ui.dart';
import 'screens/login.dart';
import 'screens/register.dart';
import 'screens/home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await session.load();
  runApp(const PartnerApp());
}

class PartnerApp extends StatelessWidget {
  const PartnerApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nukad Partner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: kAct, primary: kAct, surface: kCard).copyWith(surfaceTint: Colors.transparent),
        scaffoldBackgroundColor: kBg,
        fontFamily: 'NotoSans',
      ),
      home: const Gate(),
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
    _start();
  }

  @override
  void dispose() {
    session.removeListener(_changed);
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
    try {
      await session.refresh();
      _error = null;
    } on ApiError catch (e) {
      if (e.code == 'not_signed_in') {
        await session.signOut();
      } else {
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
    if (!session.signedIn) return const LoginScreen();
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_error!, textAlign: TextAlign.center, style: tx(15)),
              const SizedBox(height: 16),
              Btn('Try again', onTap: () {
                setState(() => _loading = true);
                _start();
              }),
            ]),
          ),
        ),
      );
    }
    if (session.store == null) return const RegisterScreen();
    return const HomeScreen();
  }
}
