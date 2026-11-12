import 'package:flutter/material.dart';
import 'prefs.dart';
export 'l10n.dart';

// Golden Corner colours (same brand as the customer app). gDark is set by the root widget from the theme setting.
bool gDark = false;
Color _p(int light, int dark) => Color(gDark ? dark : light);

const kBrand = Color(0xFFF8CB46);
Color get kInk => _p(0xFF21331B, 0xFFF2F2F2);
Color get kAct => _p(0xFF315426, 0xFFF8CB46); // buttons, links (yellow in dark mode)
Color get kOnAct => _p(0xFFFFFFFF, 0xFF21331B); // text on kAct
Color get kBg => _p(0xFFFBF8EF, 0xFF121212);
Color get kCard => _p(0xFFFFFFFF, 0xFF1E1E1E);
Color get kSurf => _p(0xFFFFF8DE, 0xFF262626);
Color get kLine => _p(0xFFEDE5C8, 0xFF333333);
Color get kMute => _p(0xFF5E6A55, 0xFFABABAB);
Color get kRed => _p(0xFFB42318, 0xFFFF7A6E);
Color get kRedBg => _p(0xFFFDECEA, 0xFF3A1A17);
Color get kRedLine => _p(0xFFF7C1C1, 0xFF5A2A26);
Color get kAmb => _p(0xFF8A4B00, 0xFFF5B25A);
Color get kAmbBg => _p(0xFFFFF1DC, 0xFF3A2A12);
Color get kAmbLine => _p(0xFFFAC775, 0xFF5A4218);
Color get kOkBg => _p(0xFFE8F0E0, 0xFF1F2E1A);
Color get kLocked => _p(0xFFF1EFE8, 0xFF2A2A2A);
Color get kLockedLine => _p(0xFFD3D1C7, 0xFF3A3A3A);
Color get kHeader => _p(0xFFF8CB46, 0xFF1E1E1E); // app bar
Color get kOnHeader => _p(0xFF21331B, 0xFFF8CB46);

TextStyle tx(double size, {Color? color, FontWeight weight = FontWeight.w400}) => TextStyle(
    fontFamily: 'NotoSans', fontFamilyFallback: const ['NotoSansDevanagari'], fontSize: size, fontWeight: weight, color: color ?? kInk, height: 1.35);

void toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text, style: tx(13.5, color: gDark ? const Color(0xFF121212) : Colors.white, weight: FontWeight.w600)),
      backgroundColor: gDark ? const Color(0xFFF2F2F2) : const Color(0xFF1B1B1B),
      behavior: SnackBarBehavior.floating,
    ));
}

class Box extends StatelessWidget {
  final Widget child;
  final Color? color;
  final Color? border;
  final EdgeInsets padding;
  const Box({super.key, required this.child, this.color, this.border, this.padding = const EdgeInsets.all(14)});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(color: color ?? kCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: border ?? kLine)),
        child: child,
      );
}

class Btn extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool outline;
  final Color? colorOrNull;
  const Btn(this.text, {super.key, this.onTap, this.outline = false, Color? color}) : colorOrNull = color;
  @override
  Widget build(BuildContext context) {
    final color = colorOrNull ?? kAct;
    return SizedBox(
        width: double.infinity,
        height: 52,
        child: outline
            ? OutlinedButton(
                onPressed: onTap,
                style: OutlinedButton.styleFrom(
                    foregroundColor: color,
                    side: BorderSide(color: color, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: Text(text, style: tx(15.5, color: color, weight: FontWeight.w700)),
              )
            : FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                    backgroundColor: color,
                    disabledBackgroundColor: kLine,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: Text(text, style: tx(15.5, color: onTap == null ? kMute : (colorOrNull == null ? kOnAct : Colors.white), weight: FontWeight.w700)),
              ),
    );
  }
}

/// Every screen's top bar: language and theme buttons are always there.
PreferredSizeWidget bar(String title, {List<Widget>? actions}) => AppBar(
      backgroundColor: kHeader,
      foregroundColor: kOnHeader,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      title: Text(title, style: tx(18, color: kOnHeader, weight: FontWeight.w800)),
      actions: [const PrefsButtons(), ...?actions],
    );

InputDecoration field(String hint, {String? error, String? label}) => InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: error,
      isDense: true,
      filled: true,
      fillColor: kCard,
      hintStyle: tx(14, color: kMute),
      labelStyle: tx(14, color: kMute),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kLine)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kAct, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kRed)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kRed, width: 2)),
    );

Widget pill(String t, {Color? color, Color? bg}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg ?? kOkBg, borderRadius: BorderRadius.circular(8)),
      child: Text(t, style: tx(11, color: color ?? (gDark ? kInk : const Color(0xFF315426)), weight: FontWeight.w800)),
    );

void showToastAction(BuildContext context, String text, String action, VoidCallback onAction) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text, style: tx(13.5, color: gDark ? const Color(0xFF121212) : Colors.white, weight: FontWeight.w600)),
      backgroundColor: gDark ? const Color(0xFFF2F2F2) : const Color(0xFF1B1B1B),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 6),
      action: SnackBarAction(label: action, textColor: gDark ? const Color(0xFF315426) : kBrand, onPressed: onAction),
    ));
}
