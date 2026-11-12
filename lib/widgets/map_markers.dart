import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

/// Nukad Kart branded map markers: delivery bike and thela.
class MapMarkers {
  static ui.Image? bike, thela;

  static Future<void> load() async {
    try {
      bike ??= await _load('assets/images/markers/bike.png');
      thela ??= await _load('assets/images/markers/thela.png');
    } catch (_) {
      // Maps fall back to plain circles if the images can't be read.
    }
  }

  static Future<ui.Image> _load(String asset) async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: 300);
    return (await codec.getNextFrame()).image;
  }

  /// Draws [img] [width] wide, centred on [at] (kept inside [within] if given). Returns the drawn rectangle.
  static Rect draw(Canvas canvas, ui.Image img, Offset at, double width, {Size? within}) {
    final h = width * img.height / img.width;
    var c = at;
    if (within != null) {
      c = Offset(c.dx.clamp(width / 2 + 2, within.width - width / 2 - 2).toDouble(),
          c.dy.clamp(h / 2 + 2, within.height - h / 2 - 2).toDouble());
    }
    final dst = Rect.fromCenter(center: c, width: width, height: h);
    canvas.drawImageRect(img, Offset.zero & Size(img.width.toDouble(), img.height.toDouble()), dst,
        Paint()..filterQuality = FilterQuality.medium);
    return dst;
  }
}
