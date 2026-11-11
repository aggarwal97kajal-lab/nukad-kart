import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../widgets/ui.dart';
import 'login_screen.dart';
import 'home_shell.dart';

/// 2.5 second animated splash: cart slides in, groceries drop in, the sparrow
/// lands, a pin drops with a 500 m ripple, then the logo opens.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

double seg(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0).toDouble();

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController c;
  bool _left = false;

  @override
  void initState() {
    super.initState();
    c = AnimationController(vsync: this, duration: Duration(milliseconds: 2500))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _go();
      })
      ..forward();
  }

  void _go() {
    if (_left || !mounted) return;
    _left = true;
    final state = AppScope.read(context);
    final next = (state.signedIn || state.guest) ? HomeShell() : LoginScreen();
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) => next,
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0E6326),
      // Fades in over the plain green launch screen so there is no jump.
      body: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: 220),
        builder: (context, v, child) => Opacity(opacity: v, child: child),
        child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.22),
            radius: 1.1,
            colors: [Color(0xFF1E8A35), Color(0xFF0E6326), Color(0xFF08441B), Color(0xFF052E13)],
            stops: [0, 0.38, 0.7, 1],
          ),
        ),
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: 390,
            height: 844,
            child: AnimatedBuilder(
              animation: c,
              builder: (context, _) => _Scene(t: c.value * 2.5),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _Scene extends StatelessWidget {
  final double t; // seconds 0..2.5
  const _Scene({required this.t});

  @override
  Widget build(BuildContext context) {
    // ---- timeline (seconds) ----
    final slide = seg(t, 0.12, 0.60);
    final glow = Curves.easeOut.transform(seg(t, 0.42, 1.16));
    final pinDrop = Curves.elasticOut.transform(seg(t, 1.06, 1.38));
    final sceneOut = Curves.easeIn.transform(seg(t, 1.46, 1.71));
    final reveal = Curves.easeOutCubic.transform(seg(t, 1.46, 1.78));
    final halo = Curves.easeOut.transform(seg(t, 1.62, 1.90));
    final tag = Curves.easeOut.transform(seg(t, 1.67, 1.92));
    final barIn = seg(t, 1.85, 1.95);
    final barFill = Curves.easeInOut.transform(seg(t, 1.875, 2.34));
    final shine = seg(t, 1.78, 2.15);

    // cart slide with a braking lean
    double cx;
    double rot;
    if (slide < 0.62) {
      final p = Curves.easeOut.transform(slide / 0.62);
      cx = -470 + (488 * p);
      rot = 5 * p;
    } else if (slide < 0.8) {
      final p = (slide - 0.62) / 0.18;
      cx = 18 - 23 * p;
      rot = 5 - 6.5 * p;
    } else {
      final p = (slide - 0.8) / 0.2;
      cx = -5 + 5 * p;
      rot = -1.5 + 1.5 * p;
    }
    final wheelAngle = -(1 - Curves.easeOut.transform(slide)) * 7 * math.pi;
    final speed = slide <= 0 ? 0.0 : (slide < 0.15 ? slide / 0.15 : (slide < 0.55 ? 1.0 : (1 - (slide - 0.55) / 0.3).clamp(0.0, 1.0).toDouble()));
    final dust = seg(t, 0.46, 0.74);

    final items = [
      ['🥛', 0.60, 64.0],
      ['🍞', 0.72, 104.0],
      ['🍅', 0.83, 146.0],
      ['🥬', 0.95, 182.0],
    ];

    // sparrow flight
    final fly = Curves.easeOutCubic.transform(seg(t, 0.81, 1.27));
    final bx = 330 * (1 - fly) - 40 * math.sin(fly * math.pi);
    final by = -260 * (1 - fly) + 60 * math.sin(fly * math.pi) * (1 - fly);
    final flapping = t > 0.81 && t < 1.27;
    final wing = flapping ? math.sin(t * 52) * 0.6 : 0.0;
    final hop = math.sin(seg(t, 1.32, 1.53) * math.pi) * -9;

    final double sceneLeft = 75, sceneTop = 232;

    final scene = Opacity(
      opacity: 1 - sceneOut,
      child: Transform.scale(
        scale: 1.18 * (1 + 0.25 * sceneOut),
        alignment: Alignment(0, 0.1),
        child: SizedBox(
          width: 240,
          height: 190,
          child: Stack(clipBehavior: Clip.none, children: [
            // ripples
            for (final r in [
              [1.18, 1.92],
              [1.27, 2.01]
            ])
              _ripple(seg(t, r[0], r[1])),
            Transform.translate(
              offset: Offset(cx, 0),
              child: Transform.rotate(
                angle: rot * math.pi / 180,
                alignment: Alignment(0.2, 0.9),
                child: SizedBox(
                  width: 240,
                  height: 190,
                  child: Stack(clipBehavior: Clip.none, children: [
                    // groceries (behind the basket front)
                    for (final it in items)
                      _item(it[0] as String, it[1] as double, it[2] as double),
                    CustomPaint(
                      size: Size(240, 190),
                      painter: _CartPainter(wheelAngle: wheelAngle, speed: speed, dust: dust),
                    ),
                    // sparrow on the handle
                    Positioned(
                      left: -14,
                      top: -30,
                      child: Opacity(
                        opacity: t < 0.81 ? 0.0 : 1.0,
                        child: Transform.translate(
                          offset: Offset(bx, by + hop),
                          child: Transform.scale(
                            scale: 0.6 + 0.4 * fly,
                            child: CustomPaint(size: Size(60, 44), painter: _SparrowPainter(wing)),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
            // location pin
            Positioned(
              left: 102,
              top: -86,
              child: Opacity(
                opacity: t < 1.06 ? 0.0 : 1.0,
                child: Transform.translate(
                  offset: Offset(0, -200 * (1 - pinDrop)),
                  child: Icon(Icons.location_on, size: 44, color: kLime, shadows: [
                    Shadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 3))
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );

    return Stack(clipBehavior: Clip.hardEdge, children: [
      Positioned.fill(child: CustomPaint(painter: _GridPainter())),
      // glow
      Positioned(
        left: 195 - 280,
        top: 330 - 280,
        child: Opacity(
          opacity: glow,
          child: Transform.scale(
            scale: 0.4 + 0.6 * glow,
            child: Container(
              width: 560,
              height: 560,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [Color(0x60A0E65A), Color(0x1A7CC242), Color(0x00000000)], stops: [0, 0.4, 0.68]),
              ),
            ),
          ),
        ),
      ),
      Positioned(left: 0, right: 0, bottom: 0, height: 190, child: CustomPaint(painter: _SkylinePainter(t))),
      Positioned(left: sceneLeft, top: sceneTop, child: scene),
      // ---- logo reveal ----
      if (t >= 1.46) ..._finish(reveal, halo, tag, barIn, barFill, shine),
    ]);
  }

  Widget _ripple(double p) {
    if (p <= 0 || p >= 1) return SizedBox.shrink();
    final op = p < 0.15 ? p / 0.15 * 0.9 : 0.9 * (1 - (p - 0.15) / 0.85);
    final size = 300 * (0.2 + 1.4 * Curves.easeOut.transform(p));
    return Positioned(
      left: 120 - size / 2,
      top: 98 - size / 2,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Color(0xFFBDE89A).withAlpha((op * 204).round()), width: 2),
          ),
        ),
      ),
    );
  }

  Widget _item(String emoji, double start, double x) {
    final p = seg(t, start, start + 0.23);
    if (p <= 0) return SizedBox.shrink();
    final y = -330 * (1 - Curves.bounceOut.transform(p));
    return Positioned(
      left: x,
      top: 14,
      child: Transform.translate(
        offset: Offset(0, y),
        child: Transform.rotate(
          angle: (1 - p) * -0.25,
          child: Text(emoji, style: TextStyle(fontSize: 36)),
        ),
      ),
    );
  }

  List<Widget> _finish(double reveal, double halo, double tag, double barIn, double barFill, double shine) {
    final out = <Widget>[];
    // dashed 500 m halo
    out.add(Positioned(
      left: 195 - 165,
      top: 330 - 165,
      child: Opacity(
        opacity: halo,
        child: Transform.rotate(
          angle: (t - 1.62).clamp(0.0, 10.0).toDouble() * 0.3,
          child: Transform.scale(
            scale: 0.85 + 0.15 * halo,
            child: CustomPaint(size: Size(330, 330), painter: _DashedCircle()),
          ),
        ),
      ),
    ));
    final km = seg(t, 1.69, 1.90);
    out.add(Positioned(
      left: 0,
      right: 0,
      top: 153 + 10 * (1 - km),
      child: Opacity(
        opacity: km,
        child: Center(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: kGD,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0x80BDE89A))),
            child: Text('500 M',
                style: body(11, color: Color(0xFFBDE89A), weight: FontWeight.w700)
                    .copyWith(letterSpacing: 1.5)),
          ),
        ),
      ),
    ));
    // map pins around the logo
    final pins = [
      ['🏪', 40.0, 274.0, 1.67],
      ['🥬', 350.0, 274.0, 1.72],
      ['🍎', 40.0, 392.0, 1.78],
      ['🥛', 350.0, 392.0, 1.83],
    ];
    for (final p in pins) {
      final pr = seg(t, p[3] as double, (p[3] as double) + 0.23);
      if (pr <= 0) continue;
      final e = Curves.elasticOut.transform(pr);
      out.add(Positioned(
        left: (p[1] as double) - 19,
        top: (p[2] as double) - 38 - 18 * (1 - pr),
        child: Transform.scale(
          scale: 0.3 + 0.7 * e,
          alignment: Alignment.bottomCenter,
          child: _MapPin(p[0] as String),
        ),
      ));
    }
    // logo card with circular reveal
    out.add(Positioned(
      left: 195 - 125,
      top: 330 - 125,
      child: Transform.scale(
        scale: 0.85 + 0.15 * reveal,
        child: ClipPath(
          clipper: _CircleReveal(reveal),
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(58),
              boxShadow: [BoxShadow(color: Color(0x59000000), blurRadius: 60, offset: Offset(0, 30))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(58),
              child: Stack(children: [
                Center(child: Image.asset('assets/images/logo.png', width: 232, filterQuality: FilterQuality.high)),
                if (shine > 0 && shine < 1)
                  Positioned(
                    left: -150 + 500 * shine,
                    top: -40,
                    child: Transform.rotate(
                      angle: 0.3,
                      child: Container(
                        width: 90,
                        height: 340,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Color(0x00FFFFFF),
                            Color(0xD9FFFFFF),
                            Color(0x00FFFFFF),
                          ]),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),
    ));
    // tagline
    out.add(Positioned(
      left: 0,
      right: 0,
      top: 530 + 12 * (1 - tag),
      child: Opacity(
        opacity: tag,
        child: Text.rich(
          TextSpan(children: [
            TextSpan(text: 'Kirana se sabzi tak, ', style: body(16, color: Color(0xFFEAF6E3), weight: FontWeight.w600)),
            TextSpan(text: 'sab 500 m ke andar', style: body(16, color: Color(0xFFBDE89A), weight: FontWeight.w700)),
          ]),
          textAlign: TextAlign.center,
        ),
      ),
    ));
    // chips
    final chips = [
      ['Kirana', 1.76],
      ['Sabzi & Phal', 1.81],
      ['Thele wale', 1.87],
    ];
    out.add(Positioned(
      left: 0,
      right: 0,
      top: 570,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (final ch in chips)
          Builder(builder: (_) {
            final p = seg(t, ch[1] as double, (ch[1] as double) + 0.19);
            return Opacity(
              opacity: p,
              child: Transform.translate(
                offset: Offset(0, 10 * (1 - p)),
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  padding: EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                  decoration: BoxDecoration(
                    color: Color(0x1AFFFFFF),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Color(0x59BDE89A)),
                  ),
                  child: Text(ch[0] as String,
                      style: body(12.5, color: Color(0xFFEAF6E3), weight: FontWeight.w600)),
                ),
              ),
            );
          }),
      ]),
    ));
    // loading bar
    out.add(Positioned(
      left: 195 - 70,
      top: 628,
      child: Opacity(
        opacity: barIn,
        child: Container(
          width: 140,
          height: 5,
          decoration: BoxDecoration(color: Color(0x26FFFFFF), borderRadius: BorderRadius.circular(3)),
          alignment: Alignment.centerLeft,
          child: Container(
            width: 140 * barFill,
            height: 5,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: LinearGradient(colors: [kLime, Color(0xFFD4F5A8)]),
            ),
          ),
        ),
      ),
    ));
    return out;
  }
}

class _MapPin extends StatelessWidget {
  final String emoji;
  const _MapPin(this.emoji);
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 44,
      child: Stack(alignment: Alignment.topCenter, children: [
        Icon(Icons.location_on, size: 46, color: Colors.white, shadows: [
          Shadow(color: Color(0x59000000), blurRadius: 10, offset: Offset(0, 4))
        ]),
        Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(emoji, style: TextStyle(fontSize: 15)),
        ),
      ]),
    );
  }
}

class _CircleReveal extends CustomClipper<Path> {
  final double p;
  _CircleReveal(this.p);
  @override
  Path getClip(Size size) {
    final r = size.width * 0.8 * p;
    return Path()..addOval(Rect.fromCircle(center: Offset(size.width / 2, size.height * (0.58 - 0.08 * p)), radius: r));
  }

  @override
  bool shouldReclip(_CircleReveal old) => old.p != p;
}

class _DashedCircle extends CustomPainter {
  _DashedCircle();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color(0x73BDE89A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final r = size.width / 2;
    final dashes = 60;
    for (var i = 0; i < dashes; i++) {
      final a0 = i * 2 * math.pi / dashes;
      canvas.drawArc(Rect.fromCircle(center: Offset(r, r), radius: r), a0, math.pi / dashes, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GridPainter extends CustomPainter {
  _GridPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Color(0x0EFFFFFF)
      ..strokeWidth = 1.5;
    // simple perspective street grid in the lower half
    final horizon = 300.0;
    for (var i = 0; i < 14; i++) {
      final y = horizon + math.pow(i / 13, 1.6) * (size.height - horizon);
      canvas.drawLine(Offset(0, y.toDouble()), Offset(size.width, y.toDouble()), p);
    }
    for (var i = -10; i <= 10; i++) {
      final xTop = size.width / 2 + i * 26;
      final xBot = size.width / 2 + i * 70;
      canvas.drawLine(Offset(xTop, horizon), Offset(xBot, size.height), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SkylinePainter extends CustomPainter {
  final double t;
  _SkylinePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final bld = Paint()
      ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0F5A24), Color(0xFF073317)])
          .createShader(Offset.zero & size);
    final awning = Paint()..color = Color(0xFF1E7A2E);
    final scallop = Paint()..color = Color(0xD9E9F5DE);
    Paint win(double at) {
      final on = seg(t, at, at + 0.12);
      return Paint()..color = Color.lerp(Color(0xFF0A3D18), Color(0xFFFFD86B), on)!;
    }

    void scallops(double x0, double y, int n, double w) {
      for (var i = 0; i < n; i++) {
        final x = x0 + i * 24;
        canvas.drawRRect(
            RRect.fromRectAndCorners(Rect.fromLTWH(x, y, w, 12),
                bottomLeft: Radius.circular(6), bottomRight: Radius.circular(6)),
            scallop);
      }
    }

    // building 1
    canvas.drawRect(Rect.fromLTWH(0, 70, 88, 120), bld);
    canvas.drawPath(Path()..moveTo(-4, 70)..lineTo(92, 70)..lineTo(84, 88)..lineTo(4, 88)..close(), awning);
    scallops(4, 88, 4, 12);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(12, 112, 26, 22), Radius.circular(3)), win(0.25));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(50, 112, 26, 22), Radius.circular(3)), win(0.39));
    // building 2
    canvas.drawRect(Rect.fromLTWH(96, 40, 70, 150), bld);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(106, 58, 20, 20), Radius.circular(3)), win(0.32));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(136, 58, 20, 20), Radius.circular(3)), win(0.53));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(106, 96, 20, 20), Radius.circular(3)), win(0.46));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(136, 96, 20, 20), Radius.circular(3)), win(9));
    canvas.drawPath(Path()..moveTo(92, 132)..lineTo(170, 132)..lineTo(164, 146)..lineTo(98, 146)..close(), Paint()..color = kLime);
    scallops(98, 146, 3, 12);
    // lamp
    final lampOn = seg(t, 0.1, 0.3);
    canvas.drawCircle(Offset(184.5, 68), 22, Paint()..color = Color.fromRGBO(255, 216, 107, 0.18 * lampOn));
    canvas.drawRect(Rect.fromLTWH(182, 70, 5, 120), Paint()..color = Color(0xFF0A3D18));
    canvas.drawRect(Rect.fromLTWH(179, 64, 11, 8), Paint()..color = Color.lerp(Color(0xFF0A3D18), Color(0xFFFFD86B), 0.35 + 0.65 * lampOn)!);
    // building 3
    canvas.drawRect(Rect.fromLTWH(200, 80, 92, 110), bld);
    canvas.drawPath(Path()..moveTo(196, 80)..lineTo(296, 80)..lineTo(288, 98)..lineTo(204, 98)..close(), awning);
    scallops(204, 98, 4, 12);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(212, 122, 30, 26), Radius.circular(3)), win(0.60));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(252, 122, 30, 26), Radius.circular(3)), win(0.32));
    // building 4
    canvas.drawRect(Rect.fromLTWH(300, 56, 90, 134), bld);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(312, 72, 22, 20), Radius.circular(3)), win(0.53));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(348, 72, 22, 20), Radius.circular(3)), win(0.25));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(312, 108, 22, 20), Radius.circular(3)), win(0.39));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(348, 108, 22, 20), Radius.circular(3)), win(0.60));
    // tree
    canvas.drawCircle(Offset(300, 150), 20, Paint()..color = Color(0xFF2E7D32));
    canvas.drawCircle(Offset(286, 160), 15, Paint()..color = Color(0xFF388E3C));
    canvas.drawRect(Rect.fromLTWH(297, 160, 5, 30), Paint()..color = Color(0xFF0A3D18));
    // road
    canvas.drawRect(Rect.fromLTWH(0, 176, 390, 14), Paint()..color = Color(0xFF04240F));
  }

  @override
  bool shouldRepaint(_SkylinePainter old) => old.t != t;
}

class _CartPainter extends CustomPainter {
  final double wheelAngle;
  final double speed;
  final double dust;
  _CartPainter({required this.wheelAngle, required this.speed, required this.dust});

  @override
  void paint(Canvas canvas, Size size) {
    // speed lines
    if (speed > 0) {
      final sp = Paint()
        ..color = Color.fromRGBO(155, 224, 90, speed)
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(-90, 70), Offset(-20, 70), sp);
      canvas.drawLine(Offset(-120, 95), Offset(-30, 95), sp);
      canvas.drawLine(Offset(-80, 120), Offset(-15, 120), sp);
    }
    // basket fill + mesh
    final basket = Path()
      ..moveTo(44, 52)
      ..lineTo(228, 52)
      ..lineTo(206, 122)
      ..lineTo(66, 122)
      ..close();
    canvas.drawPath(basket, Paint()..color = Color(0xFFEAF6E3));
    final mesh = Paint()
      ..color = Color(0xFFB8DFA0)
      ..strokeWidth = 5;
    canvas.drawLine(Offset(54, 76), Offset(220, 76), mesh);
    canvas.drawLine(Offset(60, 99), Offset(212, 99), mesh);
    canvas.drawLine(Offset(100, 52), Offset(94, 122), mesh);
    canvas.drawLine(Offset(146, 52), Offset(148, 122), mesh);
    canvas.drawLine(Offset(190, 52), Offset(178, 122), mesh);
    final frame = Paint()
      ..color = kGD
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(basket, frame);
    // handle + base
    final handle = Path()
      ..moveTo(6, 34)
      ..lineTo(32, 34)
      ..lineTo(66, 140)
      ..lineTo(208, 140);
    canvas.drawPath(handle, frame..strokeWidth = 13);
    // wheels
    for (final wx in [92.0, 188.0]) {
      canvas.save();
      canvas.translate(wx, 164);
      canvas.rotate(wheelAngle);
      canvas.drawCircle(Offset.zero, 19, Paint()..color = kGD);
      canvas.drawCircle(Offset.zero, 8, Paint()..color = Colors.white);
      final sp = Paint()
        ..color = Color(0xFF4CAF50)
        ..strokeWidth = 3;
      canvas.drawLine(Offset(0, -15), Offset(0, 15), sp);
      canvas.drawLine(Offset(-15, 0), Offset(15, 0), sp);
      canvas.drawCircle(Offset.zero, 4, Paint()..color = kGD);
      canvas.restore();
    }
    // dust puffs when braking
    if (dust > 0 && dust < 1) {
      final d = Paint()..color = Color.fromRGBO(215, 238, 208, 0.9 * (1 - dust));
      final s = 0.2 + 1.6 * dust;
      for (final c in [Offset(60, 178), Offset(48, 172), Offset(70, 170), Offset(220, 178), Offset(232, 172)]) {
        canvas.drawCircle(c.translate(0, -6 * dust), 5 * s, d);
      }
    }
  }

  @override
  bool shouldRepaint(_CartPainter old) =>
      old.wheelAngle != wheelAngle || old.speed != speed || old.dust != dust;
}

class _SparrowPainter extends CustomPainter {
  final double wing;
  _SparrowPainter(this.wing);
  @override
  void paint(Canvas canvas, Size size) {
    final brown = Paint()..color = Color(0xFF8D5A32);
    final dark = Paint()..color = Color(0xFF6D4426);
    canvas.drawPath(Path()..moveTo(14, 24)..lineTo(0, 18)..lineTo(2, 31)..lineTo(16, 30)..close(), dark);
    canvas.drawOval(Rect.fromCenter(center: Offset(30, 26), width: 36, height: 24), brown);
    canvas.drawOval(Rect.fromCenter(center: Offset(31, 31), width: 26, height: 13), Paint()..color = Color(0xFFEAD7B7));
    canvas.save();
    canvas.translate(36, 22);
    canvas.rotate(wing);
    canvas.drawOval(Rect.fromCenter(center: Offset(-11, 0), width: 26, height: 15), dark);
    canvas.restore();
    canvas.drawCircle(Offset(44, 15), 9.5, brown);
    canvas.drawPath(Path()..moveTo(36, 11)..quadraticBezierTo(42, 3, 51, 9)..lineTo(45, 12)..close(), Paint()..color = Color(0xFF5D3A1A));
    canvas.drawOval(Rect.fromCenter(center: Offset(46, 19), width: 10, height: 7.6), Paint()..color = Colors.white);
    canvas.drawCircle(Offset(47.5, 13.5), 1.8, Paint()..color = Color(0xFF111111));
    canvas.drawPath(Path()..moveTo(52, 14)..lineTo(59, 16.5)..lineTo(52, 19)..close(), Paint()..color = Color(0xFF3E2A1A));
    final leg = Paint()
      ..color = Color(0xFF5D3A1A)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(28, 37), Offset(28, 43), leg);
    canvas.drawLine(Offset(34, 37), Offset(34, 43), leg);
  }

  @override
  bool shouldRepaint(_SparrowPainter old) => old.wing != wing;
}
