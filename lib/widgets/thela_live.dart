import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../state/thela_tracker.dart';
import 'ui.dart';
import 'map_markers.dart';

String thelaStatusLabel(ThelaStatus s) => switch (s) {
      ThelaStatus.hereNow => '● HERE NOW',
      ThelaStatus.movingAway => '➜ MOVING AWAY',
      ThelaStatus.notAvailable => 'NOT AVAILABLE',
    };

Widget thelaStatusPill(ThelaStatus s) => switch (s) {
      ThelaStatus.hereNow => Pill(thelaStatusLabel(s), color: kGText, bg: kPillBg),
      ThelaStatus.movingAway => Pill(thelaStatusLabel(s), color: kAmb, bg: kAmbBg),
      ThelaStatus.notAvailable => Pill(thelaStatusLabel(s), color: kMute, bg: kLine),
    };

String thelaStatusLine(ThelaLive t) {
  final hh = TimeOfDay.fromDateTime(t.lastSeen);
  final m = hh.minute.toString().padLeft(2, '0');
  final h = hh.hourOfPeriod == 0 ? 12 : hh.hourOfPeriod;
  return switch (t.status) {
    ThelaStatus.hereNow => '${t.d.round()} m away · live on map',
    ThelaStatus.movingAway => '${t.d.round().clamp(0, 500)} m · heading out of your area',
    ThelaStatus.notAvailable => 'Left your 500 m · last seen $h:$m ${hh.period == DayPeriod.am ? 'am' : 'pm'}',
  };
}

/// Map with the customer's home in the middle, the 500 m circle, and the thela's live pin.
class ThelaLiveMap extends StatelessWidget {
  final String thelaId;
  final String emoji;
  const ThelaLiveMap({super.key, required this.thelaId, required this.emoji});

  @override
  Widget build(BuildContext context) {
    final tr = ThelaTracker.instance;
    return ListenableBuilder(
      listenable: tr,
      builder: (context, _) {
        final t = tr.of(thelaId);
        if (t.status == ThelaStatus.notAvailable) {
          return Container(
            height: 280,
            color: gDark ? Color(0xFF1E1E1E) : Color(0xFFECE8DA),
            padding: EdgeInsets.symmetric(horizontal: 36),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              CircleAvatar(radius: 30, backgroundColor: kCard, child: Icon(Icons.location_off_outlined, color: kMute, size: 28)),
              SizedBox(height: 10),
              Text('Location hidden', style: head(18)),
              SizedBox(height: 4),
              Text('This seller went outside your 500 m area, so the live map stopped.',
                  textAlign: TextAlign.center, style: body(13, color: kMute)),
            ]),
          );
        }
        return SizedBox(
          height: 280,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: t.d),
            duration: Duration(milliseconds: 1800),
            builder: (context, d, _) => CustomPaint(
              size: Size.infinite,
              painter: _MapPainter(d, t.angle, t.status, emoji, List.of(t.trail), gDark),
            ),
          ),
        );
      },
    );
  }
}

class _MapPainter extends CustomPainter {
  final double d, angle;
  final ThelaStatus status;
  final String emoji;
  final List<double> trail;
  final bool dark;
  _MapPainter(this.d, this.angle, this.status, this.emoji, this.trail, this.dark);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = dark ? Color(0xFF1E1E1E) : Color(0xFFF4EFDC));
    final road = Paint()
      ..color = dark ? Color(0xFF2E2E2E) : Colors.white
      ..strokeWidth = 11;
    for (var y = 24.0; y < h; y += 64) {
      canvas.drawLine(Offset(0, y), Offset(w, y), road);
    }
    for (var x = 30.0; x < w; x += 78) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), road);
    }
    final c = Offset(w / 2, h / 2);
    final scale = (h / 2 - 14) / 560; // 560 m fits the height
    final r = 500 * scale;
    canvas.drawCircle(c, r, Paint()..color = kBrand.withAlpha(40));
    _dashedCircle(canvas, c, r, Paint()
      ..color = dark ? Color(0xFFF3F0E2) : Color(0xFF21331B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    _label(canvas, c + Offset(r * 0.62, r * 0.72), '500 m', kCard, kInk);

    Offset at(double dist) => c + Offset(math.cos(angle), math.sin(angle)) * dist * scale;
    if (status == ThelaStatus.movingAway && trail.length > 1) {
      final p = Paint()
        ..color = Color(0xFF8A4B00)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < trail.length - 1; i++) {
        canvas.drawCircle(at(trail[i]), 2.5, p);
      }
    }
    // customer's home
    canvas.drawCircle(c, 15, Paint()..color = Color(0xFF21331B));
    _icon(canvas, c, Icons.home, Colors.white, 17);
    // thela
    final pos = at(d.clamp(0, 545));
    final col = status == ThelaStatus.hereNow ? Color(0xFF315426) : Color(0xFF8A4B00);
    canvas.drawCircle(pos, 25, Paint()..color = col.withAlpha(46));
    final img = MapMarkers.thela;
    var labelAt = pos - Offset(0, 36);
    if (img != null) {
      final r = MapMarkers.draw(canvas, img, pos.translate(0, -6), 70, within: size);
      labelAt = r.top > 26 ? Offset(r.center.dx, r.top - 12) : Offset(r.center.dx, r.bottom + 12);
    } else {
      canvas.drawCircle(pos, 17, Paint()..color = kBrand);
      canvas.drawCircle(
          pos,
          17,
          Paint()
            ..color = Color(0xFF21331B)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
      final tp = TextPainter(text: TextSpan(text: emoji, style: TextStyle(fontSize: 16)), textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
    _label(canvas, labelAt, '${d.round()} m · live', Color(0xFF21331B), kBrand);
  }

  void _dashedCircle(Canvas canvas, Offset c, double r, Paint p) {
    const n = 64;
    for (var i = 0; i < n; i += 2) {
      final a1 = 2 * math.pi * i / n, a2 = 2 * math.pi * (i + 1) / n;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), a1, a2 - a1, false, p);
    }
  }

  void _label(Canvas canvas, Offset center, String text, Color bg, Color fg) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontFamily: 'NotoSans', fontSize: 11, fontWeight: FontWeight.w800, color: fg)),
      textDirection: TextDirection.ltr,
    )..layout();
    final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: tp.width + 18, height: 22), Radius.circular(11));
    canvas.drawRRect(rect, Paint()..color = bg);
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  void _icon(Canvas canvas, Offset c, IconData icon, Color color, double size) {
    final tp = TextPainter(
      text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(fontFamily: icon.fontFamily, package: icon.fontPackage, fontSize: size, color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _MapPainter o) =>
      o.d != d || o.angle != angle || o.status != status || o.dark != dark || o.trail.length != trail.length;
}
