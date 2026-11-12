import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api.dart';
import '../session.dart';
import '../ui.dart';

const _deep = Color(0xFF284A1F);
const _green = Color(0xFF315426);
const _mute = Color(0xFF5E6A55);
const _ink = Color(0xFF21331B);
const _bgLight = Color(0xFFFBF8EF);
const _cream = Color(0xFFFFF8DE);
const _planDays = {'daily': 1, 'weekly': 7, 'monthly': 30, 'yearly': 365};
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

double _seg(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);
double _out(double x) => 1 - math.pow(1 - x, 3).toDouble();
double _back(double x, [double s = 1.9]) {
  final y = x - 1;
  return y * y * ((s + 1) * y + s) + 1;
}

String _till(int secs) {
  final d = DateTime.fromMillisecondsSinceEpoch(secs * 1000);
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${d.day} ${_months[d.month - 1]} ${d.year}, $h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'am' : 'pm'}';
}

/// Celebration after a pass starts: green wave, badge with a self-drawing tick, rings, confetti,
/// the pass ticket flying in with a day counter and a shine, then "Go LIVE now".
class PassActiveScreen extends StatefulWidget {
  final Map<String, dynamic> payment;
  const PassActiveScreen({super.key, required this.payment});
  @override
  State<PassActiveScreen> createState() => _PassActiveScreenState();
}

class _PassActiveScreenState extends State<PassActiveScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 6000))..forward();
  bool _busy = false;
  final _confetti = _Confetti.make();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1050), () => HapticFeedback.mediumImpact());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _goLive() async {
    setState(() => _busy = true);
    try {
      final r = await api.call('POST', '/v1/partner/live', {'on': true});
      session.setStore(Map<String, dynamic>.from(r['store'] as Map));
      if (mounted) Navigator.pop(context);
    } on ApiError catch (e) {
      if (!mounted) return;
      toast(context, e.message);
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.payment;
    final days = _planDays['${p['plan']}'] ?? 30;
    final until = ((session.store?['passUntil'] as num?) ?? 0).toInt();
    final size = MediaQuery.sizeOf(context);
    final badgeY = size.height * 0.24;
    return Scaffold(
      backgroundColor: _deep,
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value * 6.0; // seconds
          return Stack(children: [
            Positioned.fill(child: CustomPaint(painter: _BackPainter(t, badgeY))),
            // headline
            Positioned(
              left: 0,
              right: 0,
              top: badgeY + 110 + (1 - _out(_seg(t, 1.3, 1.7))) * 30,
              child: Opacity(
                opacity: _seg(t, 1.3, 1.7),
                child: Column(children: [
                  Text(t('Pass active!'), style: tx(34, color: Colors.white, weight: FontWeight.w800)),
                  Text(t('Your shop can go LIVE now'), style: tx(15, color: const Color(0xFFE1ECD7))),
                ]),
              ),
            ),
            // the pass ticket
            if (t > 1.55)
              Positioned(
                left: 28,
                right: 28,
                top: badgeY + 210 + (1 - _back(_seg(t, 1.55, 2.15), 1.4)) * size.height * 0.4,
                child: Transform.rotate(
                  angle: (1 - _seg(t, 1.55, 2.3)) * -7 * math.pi / 180,
                  child: _Ticket(
                    plan: t('${p['planName'] ?? 'Pass'}'),
                    days: (days * _out(_seg(t, 2.0, 2.9))).round(),
                    price: '₹${p['amount']}',
                    till: until > 0 ? tr('Valid till {0}', [_till(until)]) : '',
                    id: tr('Payment ID {0}', [p['id']]),
                    shine: _seg(t, 2.25, 2.9),
                  ),
                ),
              ),
            Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _ConfettiPainter(_confetti, t, Offset(size.width / 2, badgeY))))),
            // buttons
            Positioned(
              left: 28,
              right: 28,
              bottom: 24 + MediaQuery.paddingOf(context).bottom - (1 - _out(_seg(t, 2.7, 3.1))) * 40,
              child: Opacity(
                opacity: _seg(t, 2.7, 3.1),
                child: Column(children: [
                  Transform.scale(
                    scale: t > 3.1 ? 1 + 0.035 * math.sin((t - 3.1) * 6) : 1,
                    child: SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: FilledButton(
                        onPressed: _busy || t < 2.7 ? null : _goLive,
                        style: FilledButton.styleFrom(
                          backgroundColor: kBrand,
                          disabledBackgroundColor: kBrand,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        child: Text(_busy ? t('Going LIVE…') : t('Go LIVE now'), style: tx(19, weight: FontWeight.w800, color: _ink)),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: t < 2.7 ? null : () => Navigator.pop(context),
                    child: Text(t('Done'), style: tx(15, color: const Color(0xFFE1ECD7), weight: FontWeight.w700)),
                  ),
                ]),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _Ticket extends StatelessWidget {
  final String plan, price, till, id;
  final int days;
  final double shine;
  const _Ticket({required this.plan, required this.days, required this.price, required this.till, required this.id, required this.shine});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Color(0x55000000), blurRadius: 24, offset: Offset(0, 12))]),
      child: ClipPath(
        clipper: _TicketClip(),
        child: Stack(children: [
          Container(
            color: _cream,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                color: kBrand,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                child: Text('NUKAD KART  ·  PARTNER PASS', style: tx(13, weight: FontWeight.w800, color: _ink)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(plan, style: tx(30, weight: FontWeight.w800, color: _ink)),
                      Text(days == 1 ? t('1 day') : tr('{0} days', [days]), style: tx(17, color: _green, weight: FontWeight.w800)),
                    ]),
                  ),
                  Text(price, style: tx(28, weight: FontWeight.w800, color: _ink)),
                ]),
              ),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12), child: _Dots()),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (till.isNotEmpty) Text(till, style: tx(13, color: _mute)),
                  Text(id, style: tx(12, color: _mute)),
                ]),
              ),
            ]),
          ),
          if (shine > 0 && shine < 1)
            Positioned.fill(
              child: LayoutBuilder(builder: (context, box) {
                final x = -160 + shine * (box.maxWidth + 320);
                return Transform.translate(
                  offset: Offset(x, 0),
                  child: Transform(
                    transform: Matrix4.skewX(-0.35),
                    child: Align(alignment: Alignment.centerLeft, child: Container(width: 60, color: Colors.white.withValues(alpha: 0.45))),
                  ),
                );
              }),
            ),
        ]),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots();
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate((box.maxWidth / 16).floor(),
              (_) => Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFFE1D6AA), shape: BoxShape.circle))),
        ),
      );
}

/// Rounded ticket with a half-circle notch on each side at the perforation.
class _TicketClip extends CustomClipper<Path> {
  @override
  Path getClip(Size s) {
    final notchY = s.height * 0.66;
    final card = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(22)));
    final holes = Path()
      ..addOval(Rect.fromCircle(center: Offset(0, notchY), radius: 16))
      ..addOval(Rect.fromCircle(center: Offset(s.width, notchY), radius: 16));
    return Path.combine(PathOperation.difference, card, holes);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Green wave from the bottom, turning rays, twinkles, rings, and the badge with its tick.
class _BackPainter extends CustomPainter {
  final double t, badgeY;
  _BackPainter(this.t, this.badgeY);
  static final _spark = List.generate(40, (i) {
    final r = math.Random(i * 31 + 7);
    return (r.nextDouble(), r.nextDouble(), r.nextDouble() * 6.28, 1.5 + r.nextDouble() * 2);
  });

  @override
  void paint(Canvas canvas, Size s) {
    final center = Offset(s.width / 2, badgeY);
    // wave
    final k = _seg(t, 0, 0.75);
    canvas.drawRect(Offset.zero & s, Paint()..color = _bgLight);
    canvas.drawCircle(Offset(s.width / 2, s.height * 0.86), (3 * k * k - 2 * k * k * k) * s.height * 1.25, Paint()..color = _green);
    if (t > 0.75) {
      canvas.drawRect(Offset.zero & s, Paint()..color = _deep);
      // rays
      final ray = Paint()..color = Colors.white.withValues(alpha: 0.065 * _seg(t, 0.8, 1.4));
      for (var i = 0; i < 12; i++) {
        final a = t * 0.35 + i * math.pi / 6;
        final path = Path()
          ..moveTo(center.dx, center.dy)
          ..lineTo(center.dx + math.cos(a - 0.09) * 2000, center.dy + math.sin(a - 0.09) * 2000)
          ..lineTo(center.dx + math.cos(a + 0.09) * 2000, center.dy + math.sin(a + 0.09) * 2000)
          ..close();
        canvas.drawPath(path, ray);
      }
      for (final (x, y, ph, r) in _spark) {
        final a = (0.5 + 0.5 * math.sin(t * 5 + ph)) * _seg(t, 1.0, 1.6) * 0.6;
        canvas.drawCircle(Offset(x * s.width, y * s.height), r, Paint()..color = const Color(0xFFFFECA0).withValues(alpha: a));
      }
    }
    if (t <= 0.7) return;
    // rings
    for (var j = 0; j < 3; j++) {
      final rt = _seg(t, 1.05 + j * 0.28, 2.2 + j * 0.28);
      if (rt > 0 && rt < 1) {
        canvas.drawCircle(center, 70 + rt * 120,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4
              ..color = kBrand.withValues(alpha: 0.8 * (1 - rt)));
      }
    }
    // badge
    final r = 70 * _back(_seg(t, 0.7, 1.15));
    if (r > 1) {
      canvas.drawCircle(center, r + 8, Paint()..color = Colors.white.withValues(alpha: 0.16));
      canvas.drawCircle(center, r, Paint()..color = kBrand);
    }
    // tick draws itself
    final ck = _out(_seg(t, 1.05, 1.5));
    if (ck > 0) {
      final tick = Path()
        ..moveTo(center.dx - 31, center.dy + 2)
        ..lineTo(center.dx - 8, center.dy + 25)
        ..lineTo(center.dx + 34, center.dy - 23);
      final m = tick.computeMetrics().first;
      canvas.drawPath(
          m.extractPath(0, m.length * ck),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 13
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = _green);
    }
  }

  @override
  bool shouldRepaint(_BackPainter old) => old.t != t;
}

class _Confetti {
  final double vx, vy, rot, vr, w, h, t0;
  final Color color;
  final bool circle;
  _Confetti(this.vx, this.vy, this.rot, this.vr, this.w, this.h, this.t0, this.color, this.circle);

  static List<_Confetti> make() {
    final r = math.Random(7);
    const colors = [kBrand, Colors.white, Color(0xFFFFAA3C), Color(0xFF8CCD6E), kBrand];
    return List.generate(140, (_) {
      final ang = -math.pi * (0.05 + r.nextDouble() * 0.9);
      final sp = 520 + r.nextDouble() * 730;
      return _Confetti(math.cos(ang) * sp, math.sin(ang) * sp, r.nextDouble() * 6.28, -9 + r.nextDouble() * 18, 9 + r.nextDouble() * 7,
          5 + r.nextDouble() * 4, 1.15 + r.nextDouble() * 0.12, colors[r.nextInt(colors.length)], r.nextDouble() < 0.25);
    });
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_Confetti> items;
  final double t;
  final Offset from;
  _ConfettiPainter(this.items, this.t, this.from);

  @override
  void paint(Canvas canvas, Size s) {
    for (final c in items) {
      final tt = t - c.t0;
      if (tt <= 0 || tt > 3.6) continue;
      final x = from.dx + c.vx * tt * 0.75 + math.sin(tt * 6 + c.rot) * 14;
      final y = from.dy + c.vy * tt * 0.75 + 0.5 * 1500 * tt * tt * 0.75;
      final paint = Paint()..color = c.color.withValues(alpha: (1.25 - tt / 3.2).clamp(0.0, 1.0));
      if (c.circle) {
        canvas.drawCircle(Offset(x, y), c.h * 0.6, paint);
      } else {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(c.rot + c.vr * tt);
        final flutter = 0.3 + 0.7 * math.cos(tt * 7 + c.rot).abs();
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: c.w * flutter, height: c.h), paint);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
