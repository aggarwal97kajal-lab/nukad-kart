import 'package:flutter/material.dart';

// ---------- Brand colours (from the Nukad Kart logo) ----------
const kGD = Color(0xFF0B5D1E); // deep green
const kG = Color(0xFF1E7A2E); // primary green
const kLime = Color(0xFF7CC242);
const kGBg = Color(0xFFEAF6E3);
const kBg = Color(0xFFF5F8F2);
const kInk = Color(0xFF14201A);
const kMute = Color(0xFF56635B);
const kLine = Color(0xFFE3EADF);
const kAmb = Color(0xFF9A4A00);
const kAmbBg = Color(0xFFFFF1DC);
const kRed = Color(0xFFB42318);
const kRedBg = Color(0xFFFDECEA);
const kBlu = Color(0xFF175CD3);
const kBluBg = Color(0xFFE8F1FD);
const kCream = Color(0xFFFFF8EC);

const kHead = 'Poppins';

TextStyle head(double size, {Color color = kInk, FontWeight weight = FontWeight.w700}) =>
    TextStyle(fontFamily: kHead, fontSize: size, fontWeight: weight, color: color, height: 1.2);

TextStyle body(double size, {Color color = kInk, FontWeight weight = FontWeight.w400}) =>
    TextStyle(fontFamily: 'Inter', fontSize: size, fontWeight: weight, color: color, height: 1.35);

String rupees(num v) {
  if (v == v.roundToDouble()) return '₹${v.toInt()}';
  return '₹${v.toStringAsFixed(2)}';
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final Color bg;
  const Pill(this.text, {super.key, this.color = kG, this.bg = kGBg});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(text.toUpperCase(),
          style: body(10.5, color: color, weight: FontWeight.w700).copyWith(letterSpacing: 0.3)),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool outline;
  final Color color;
  final double height;
  const PrimaryButton(this.text,
      {super.key, this.onTap, this.outline = false, this.color = kG, this.height = 52});
  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Material(
        color: outline ? Colors.white : (enabled ? color : const Color(0xFFB8C4BB)),
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
  final Color color;
  final Color border;
  const CardBox(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(14),
      this.color = Colors.white,
      this.border = kLine});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border)),
      child: child,
    );
  }
}

class NoteBox extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  final Color bg;
  const NoteBox(this.text,
      {super.key, this.icon = Icons.info_outline, this.color = kAmb, this.bg = kAmbBg});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: body(12.5, color: color, weight: FontWeight.w500))),
      ]),
    );
  }
}

class EmojiTile extends StatelessWidget {
  final String emoji;
  final double size;
  final Color bg;
  const EmojiTile(this.emoji, {super.key, this.size = 56, this.bg = kCream});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size * 0.24)),
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
            side: const BorderSide(color: kG, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          ),
          onPressed: onAdd,
          child: Text('ADD', style: body(13, color: kG, weight: FontWeight.w700)),
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
            child: const SizedBox(
                width: 28, height: 34, child: Icon(Icons.remove, color: Colors.white, size: 18))),
        Text('$qty', style: body(14, color: Colors.white, weight: FontWeight.w700)),
        InkWell(
            onTap: onAdd,
            child: const SizedBox(
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
                size: size, color: on ? const Color(0xFFF5B400) : const Color(0xFFC5CFC6)),
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

PreferredSizeWidget simpleAppBar(String title, {String? subtitle}) {
  return AppBar(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.white,
    foregroundColor: kInk,
    elevation: 0,
    titleSpacing: 0,
    shape: const Border(bottom: BorderSide(color: kLine)),
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
