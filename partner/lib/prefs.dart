import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ui.dart';

enum AppTheme { light, dark, phone }

/// Language, theme and "shop or thela" chosen before login. Saved on the phone.
class Prefs extends ChangeNotifier {
  SharedPreferences? _p;
  String lang = 'en';
  AppTheme theme = AppTheme.phone;
  bool chosen = false; // first-run language/theme screen done
  String kind = ''; // 'shop' | 'thela' | '' (not chosen yet)

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    lang = _p!.getString('lang') ?? 'en';
    theme = AppTheme.values.firstWhere((x) => x.name == _p!.getString('theme'), orElse: () => AppTheme.phone);
    chosen = _p!.getBool('prefs_chosen') ?? false;
    kind = _p!.getString('kind') ?? '';
  }

  void setLang(String v) {
    lang = v;
    _p?.setString('lang', v);
    notifyListeners();
  }

  void setTheme(AppTheme v) {
    theme = v;
    _p?.setString('theme', v.name);
    notifyListeners();
  }

  void setChosen() {
    chosen = true;
    _p?.setBool('prefs_chosen', true);
    notifyListeners();
  }

  void setKind(String v) {
    kind = v;
    _p?.setString('kind', v);
    notifyListeners();
  }
}

final prefs = Prefs();

/// Language + theme buttons shown in every top bar.
class PrefsButtons extends StatelessWidget {
  const PrefsButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
        tooltip: t('Language'),
        icon: const Icon(Icons.translate),
        onPressed: () => showModalBottomSheet(
          context: context,
          backgroundColor: kCard,
          builder: (ctx) => SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final (code, name) in const [('en', 'English'), ('hi', 'हिन्दी')])
                ListTile(
                  title: Text(name, style: tx(16, weight: FontWeight.w700)),
                  trailing: prefs.lang == code ? Icon(Icons.check, color: kAct) : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    prefs.setLang(code);
                  },
                ),
            ]),
          ),
        ),
      ),
      IconButton(
        tooltip: t('Theme'),
        icon: Icon(gDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
        onPressed: () => prefs.setTheme(gDark ? AppTheme.light : AppTheme.dark),
      ),
    ]);
  }
}
