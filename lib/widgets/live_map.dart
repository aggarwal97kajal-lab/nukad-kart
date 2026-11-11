import 'dart:ui' show PathMetric;
import 'package:flutter/material.dart';
import 'ui.dart';

/// G07: live position of the delivery person while the order is out for delivery.
/// Demo: the rider moves along a drawn route. The real app reads the store
/// partner's phone GPS from the server and draws it on Google Maps.
class LiveDeliveryMap extends StatefulWidget {
  final DateTime startedAt;
  final Duration eta;
  final String riderName;
  final String storeName;
  final int payable;
  final String storePhone;
  const LiveDeliveryMap({
    super.key,
    required this.startedAt,
    required this.eta,
    required this.riderName,
    required this.storeName,
    required this.payable,
    required this.storePhone,
  });

  @override
  State<LiveDeliveryMap> createState() => _LiveDeliveryMapState();
}

class _LiveDeliveryMapState extends State<LiveDeliveryMap> with SingleTickerProviderStateMixin {
  late final AnimationController c;

  double get _progress {
    final ms = DateTime.now().difference(widget.startedAt).inMilliseconds;
    return (ms / widget.eta.inMilliseconds).clamp(0.0, 1.0).toDouble();
  }

  @override
  void initState() {
    super.initState();
    c = AnimationController(vsync: this, duration: widget.eta, value: _progress);
    final left = widget.eta * (1 - _progress);
    if (left > Duration.zero) c.animateTo(1, duration: left, curve: Curves.linear);
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          color: kCard, borderRadius: BorderRadius.circular(18), border: Border.all(color: kLine)),
      child: Column(children: [
        SizedBox(
          height: 230,
          child: AnimatedBuilder(
            animation: c,
            builder: (context, _) => CustomPaint(
              size: Size.infinite,
              painter: _RoutePainter(c.value, widget.riderName, gDark),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(children: [
            AnimatedBuilder(
              animation: c,
              builder: (context, _) {
                final secsLeft = (widget.eta.inSeconds * (1 - c.value)).ceil();
                final metres = (350 * (1 - c.value)).round();
                return Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(secsLeft <= 0 ? 'Arriving now' : 'Arriving in ~${(secsLeft / 60).ceil()} min',
                          style: head(19)),
                      Text('Out for delivery · $metres m away', style: body(12.5, color: kMute)),
                    ]),
                  ),
                  Pill('● LIVE', color: kGText, bg: kPillBg),
                ]);
              },
            ),
            SizedBox(height: 10),
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                CircleAvatar(
                    radius: 21,
                    backgroundColor: kLime,
                    child: Text(widget.riderName[0], style: head(16, color: kGD))),
                SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${widget.riderName} · ${widget.storeName}',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: body(14, weight: FontWeight.w700)),
                    Text('Keep ${rupees(widget.payable)} ready · cash or UPI', style: body(12, color: kMute)),
                  ]),
                ),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: kG),
                  onPressed: () => showToast(context, 'Demo: would call ${widget.storePhone}'),
                  icon: Icon(Icons.call, color: Colors.white, size: 20),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _RoutePainter extends CustomPainter {
  final double t;
  final String rider;
  final bool dark;
  _RoutePainter(this.t, this.rider, this.dark);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = dark ? Color(0xFF1C2A22) : Color(0xFFE9EFE5));
    final block = Paint()..color = dark ? Color(0xFF243329) : Color(0xFFD7E6CF);
    final road = Paint()
      ..color = dark ? Color(0xFF34473B) : Colors.white
      ..strokeWidth = 14;
    final xs = [0.18, 0.5, 0.8], ys = [0.2, 0.55, 0.88];
    for (var i = 0; i < 2; i++) {
      for (var j = 0; j < 2; j++) {
        canvas.drawRRect(
            RRect.fromLTRBR(w * xs[i] + 14, h * ys[j] + 14, w * xs[i + 1] - 14, h * ys[j + 1] - 14,
                Radius.circular(8)),
            block);
      }
    }
    for (final x in xs) {
      canvas.drawLine(Offset(w * x, 0), Offset(w * x, h), road);
    }
    for (final y in ys) {
      canvas.drawLine(Offset(0, h * y), Offset(w, h * y), road);
    }

    final store = Offset(w * xs[0], h * ys[2]);
    final home = Offset(w * xs[2], h * ys[0]);
    final route = Path()
      ..moveTo(store.dx, store.dy)
      ..lineTo(w * xs[0], h * ys[1])
      ..lineTo(w * xs[1], h * ys[1])
      ..lineTo(w * xs[1], h * ys[0])
      ..lineTo(home.dx, home.dy);
    final PathMetric m = route.computeMetrics().first;
    final done = m.extractPath(0, m.length * t);
    final left = m.extractPath(m.length * t, m.length);
    canvas.drawPath(
        left,
        Paint()
          ..color = kG
          ..strokeWidth = 6
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
    canvas.drawPath(
        done,
        Paint()
          ..color = Color(0xFF9FB5A2)
          ..strokeWidth = 6
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);

    _marker(canvas, store, kGD, Icons.storefront);
    _marker(canvas, home, Color(0xFFD64545), Icons.home);

    final pos = m.getTangentForOffset(m.length * t)?.position ?? store;
    canvas.drawCircle(pos, 28, Paint()..color = Color(0x407CC242));
    canvas.drawCircle(pos, 18, Paint()..color = kG);
    canvas.drawCircle(
        pos,
        18,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
    _icon(canvas, pos, Icons.delivery_dining, Colors.white, 20);

    final tp = TextPainter(
      text: TextSpan(
          text: '$rider · live',
          style: TextStyle(fontFamily: 'Inter', fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white)),
      textDirection: TextDirection.ltr,
    )..layout();
    final r = RRect.fromRectAndRadius(
        Rect.fromCenter(center: pos.translate(0, -36), width: tp.width + 20, height: 24), Radius.circular(12));
    canvas.drawRRect(r, Paint()..color = Color(0xFF14201A));
    tp.paint(canvas, Offset(r.center.dx - tp.width / 2, r.center.dy - tp.height / 2));
  }

  void _marker(Canvas canvas, Offset p, Color color, IconData icon) {
    canvas.drawCircle(p, 17, Paint()..color = Colors.white);
    canvas.drawCircle(p, 14, Paint()..color = color);
    _icon(canvas, p, icon, Colors.white, 16);
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
  bool shouldRepaint(covariant _RoutePainter old) => old.t != t || old.dark != dark;
}
