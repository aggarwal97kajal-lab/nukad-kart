import 'package:flutter/material.dart';

// Golden Corner colours (same brand as the customer app).
const kBrand = Color(0xFFF8CB46);
const kInk = Color(0xFF21331B);
const kAct = Color(0xFF315426);
const kBg = Color(0xFFFBF8EF);
const kCard = Colors.white;
const kSurf = Color(0xFFFFF8DE);
const kLine = Color(0xFFEDE5C8);
const kMute = Color(0xFF5E6A55);
const kRed = Color(0xFFB42318);
const kRedBg = Color(0xFFFDECEA);
const kAmb = Color(0xFF8A4B00);
const kAmbBg = Color(0xFFFFF1DC);
const kOkBg = Color(0xFFE8F0E0);

TextStyle tx(double size, {Color color = kInk, FontWeight weight = FontWeight.w400}) =>
    TextStyle(fontFamily: 'NotoSans', fontSize: size, fontWeight: weight, color: color, height: 1.35);

void toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text, style: tx(13.5, color: Colors.white, weight: FontWeight.w600)),
      backgroundColor: const Color(0xFF1B1B1B),
      behavior: SnackBarBehavior.floating,
    ));
}

class Box extends StatelessWidget {
  final Widget child;
  final Color color;
  final Color border;
  final EdgeInsets padding;
  const Box({super.key, required this.child, this.color = kCard, this.border = kLine, this.padding = const EdgeInsets.all(14)});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
        child: child,
      );
}

class Btn extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool outline;
  final Color color;
  const Btn(this.text, {super.key, this.onTap, this.outline = false, this.color = kAct});
  @override
  Widget build(BuildContext context) => SizedBox(
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
                child: Text(text, style: tx(15.5, color: onTap == null ? kMute : Colors.white, weight: FontWeight.w700)),
              ),
      );
}

PreferredSizeWidget bar(String title, {List<Widget>? actions}) => AppBar(
      backgroundColor: kBrand,
      foregroundColor: kInk,
      elevation: 0,
      title: Text(title, style: tx(18, weight: FontWeight.w800)),
      actions: actions,
    );

InputDecoration field(String hint, {String? error, String? label}) => InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: error,
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLine)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kAct, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kRed)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kRed, width: 2)),
    );

Widget pill(String t, {Color color = kAct, Color bg = kOkBg}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(t, style: tx(11, color: color, weight: FontWeight.w800)),
    );

void showToastAction(BuildContext context, String text, String action, VoidCallback onAction) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text, style: tx(13.5, color: Colors.white, weight: FontWeight.w600)),
      backgroundColor: const Color(0xFF1B1B1B),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 6),
      action: SnackBarAction(label: action, textColor: kBrand, onPressed: onAction),
    ));
}
