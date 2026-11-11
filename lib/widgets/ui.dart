import 'package:flutter/material.dart';
import '../l10n.dart';

// ---------- Brand colours (from the Nukad Kart logo) ----------
// Light and dark palettes. gDark is set by the root widget from the
// Appearance setting (Light / Dark / Same as phone).
bool gDark = false;
Color _p(int light, int dark) => Color(gDark ? dark : light);

const kGD = Color(0xFF0B5D1E); // deep green (headers, both modes)
const kLime = Color(0xFF7CC242);
Color get kG => _p(0xFF1E7A2E, 0xFF3A9A48);
Color get kGText => _p(0xFF0B5D1E, 0xFF9BD873);
Color get kGBg => _p(0xFFEAF6E3, 0xFF1D2E1F);
Color get kPillBg => _p(0xFFD9F0CF, 0xFF223A22);
Color get kBg => _p(0xFFF5F8F2, 0xFF0E1411);
Color get kCard => _p(0xFFFFFFFF, 0xFF18211C);
Color get kInk => _p(0xFF14201A, 0xFFEEF3EF);
Color get kMute => _p(0xFF56635B, 0xFF97A39B);
Color get kLine => _p(0xFFE3EADF, 0xFF26302A);
Color get kAmb => _p(0xFF9A4A00, 0xFFF5B25A);
Color get kAmbBg => _p(0xFFFFF1DC, 0xFF3A2A12);
Color get kRed => _p(0xFFB42318, 0xFFFF7A6E);
Color get kRedBg => _p(0xFFFDECEA, 0xFF3A1A17);
Color get kBlu => _p(0xFF175CD3, 0xFF7FB0FF);
Color get kBluBg => _p(0xFFE8F1FD, 0xFF16263D);
Color get kCream => _p(0xFFFFF8EC, 0xFF2A2A22);

const kHead = 'Poppins';

TextStyle head(double size, {Color? color, FontWeight weight = FontWeight.w700}) =>
    TextStyle(fontFamily: kHead, fontSize: size, fontWeight: weight, color: color ?? kInk, height: 1.2);

TextStyle body(double size, {Color? color, FontWeight weight = FontWeight.w400}) =>
    TextStyle(fontFamily: 'Inter', fontSize: size, fontWeight: weight, color: color ?? kInk, height: 1.35);

String rupees(num v) {
  if (v == v.roundToDouble()) return '₹${v.toInt()}';
  return '₹${v.toStringAsFixed(2)}';
}

class Pill extends StatelessWidget {
  final String text;
  final Color? color;
  final Color? bg;
  const Pill(this.text, {super.key, this.color, this.bg});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg ?? kGBg, borderRadius: BorderRadius.circular(6)),
      child: Text(text.toUpperCase(),
          style: body(10.5, color: color ?? kG, weight: FontWeight.w700).copyWith(letterSpacing: 0.3)),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool outline;
  final Color? colorOverride;
  final double height;
  const PrimaryButton(this.text,
      {super.key, this.onTap, this.outline = false, Color? color, this.height = 52})
      : colorOverride = color;
  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final color = colorOverride ?? kG;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Material(
        color: outline ? kCard : (enabled ? color : Color(0xFFB8C4BB)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: outline ? BorderSide(color: color, width: 1.6) : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Center(
            child: Text(text,
                style: head(15.5, color: outline ? color : Colors.white, weight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}

class CardBox extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color? border;
  const CardBox(
      {super.key, required this.child, this.padding = const EdgeInsets.all(14), this.color, this.border});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
          color: color ?? kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border ?? kLine)),
      child: child,
    );
  }
}

class NoteBox extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color? color;
  final Color? bg;
  const NoteBox(this.text, {super.key, this.icon = Icons.info_outline, this.color, this.bg});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg ?? kAmbBg, borderRadius: BorderRadius.circular(12)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: color ?? kAmb),
        SizedBox(width: 10),
        Expanded(child: Text(text, style: body(12.5, color: color ?? kAmb, weight: FontWeight.w500))),
      ]),
    );
  }
}

class EmojiTile extends StatelessWidget {
  final String emoji;
  final double size;
  final Color? bg;
  const EmojiTile(this.emoji, {super.key, this.size = 56, this.bg});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg ?? kCream, borderRadius: BorderRadius.circular(size * 0.24)),
      alignment: Alignment.center,
      child: Text(emoji, style: TextStyle(fontSize: size * 0.52)),
    );
  }
}

class QtyStepper extends StatelessWidget {
  final int qty;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  const QtyStepper({super.key, required this.qty, required this.onAdd, required this.onRemove});
  @override
  Widget build(BuildContext context) {
    if (qty == 0) {
      return SizedBox(
        height: 34,
        width: 78,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            side: BorderSide(color: kG, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          ),
          onPressed: onAdd,
          child: Text(t('ADD'), style: body(13, color: kG, weight: FontWeight.w700)),
        ),
      );
    }
    return Container(
      height: 34,
      width: 88,
      decoration: BoxDecoration(color: kG, borderRadius: BorderRadius.circular(9)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        InkWell(
            onTap: onRemove,
            child: SizedBox(
                width: 28, height: 34, child: Icon(Icons.remove, color: Colors.white, size: 18))),
        Text('$qty', style: body(14, color: Colors.white, weight: FontWeight.w700)),
        InkWell(
            onTap: onAdd,
            child: SizedBox(
                width: 28, height: 34, child: Icon(Icons.add, color: Colors.white, size: 18))),
      ]),
    );
  }
}

class StarRow extends StatelessWidget {
  final int value;
  final double size;
  final ValueChanged<int>? onChanged;
  const StarRow({super.key, required this.value, this.size = 36, this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final on = i < value;
        return GestureDetector(
          onTap: onChanged == null ? null : () => onChanged!(i + 1),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: size * 0.08),
            child: Icon(on ? Icons.star_rounded : Icons.star_outline_rounded,
                size: size, color: on ? Color(0xFFF5B400) : Color(0xFFC5CFC6)),
          ),
        );
      }),
    );
  }
}

String ratingWord(int v) {
  switch (v) {
    case 1:
      return 'Very poor';
    case 2:
      return 'Poor';
    case 3:
      return 'Okay';
    case 4:
      return 'Good';
    case 5:
      return 'Excellent';
  }
  return '';
}

PreferredSizeWidget simpleAppBar(String title, {String? subtitle, List<Widget>? actions}) {
  return AppBar(
    backgroundColor: kCard,
    surfaceTintColor: kCard,
    foregroundColor: kInk,
    elevation: 0,
    actions: actions,
    titleSpacing: 0,
    shape: Border(bottom: BorderSide(color: kLine)),
    title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: head(18)),
      if (subtitle != null) Text(subtitle, style: body(12, color: kMute)),
    ]),
  );
}

void showToast(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text, style: body(13.5, color: Colors.white, weight: FontWeight.w500)),
      backgroundColor: kInk,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
}
