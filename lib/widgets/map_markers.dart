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
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: 240);
    return (await codec.getNextFrame()).image;
  }

  /// Draws [img] [width] wide, centred on [at]. Returns the drawn rectangle.
  static Rect draw(Canvas canvas, ui.Image img, Offset at, double width) {
    final h = width * img.height / img.width;
    final dst = Rect.fromCenter(center: at, width: width, height: h);
    canvas.drawImageRect(img, Offset.zero & Size(img.width.toDouble(), img.height.toDouble()), dst,
        Paint()..filterQuality = FilterQuality.medium);
    return dst;
  }
}
