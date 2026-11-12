import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../api.dart';
import '../ui.dart';
import 'agreement.dart';

/// Turns a photo of a signature on paper into a clean PNG: paper becomes transparent, ink stays, cropped to the ink.
Uint8List? cleanSignature(Uint8List photo) {
  final src = img.decodeImage(photo);
  if (src == null) return null;
  final small = src.width > 900 ? img.copyResize(src, width: 900) : src;
  final out = img.Image(width: small.width, height: small.height, numChannels: 4);
  var minX = small.width, minY = small.height, maxX = -1, maxY = -1;
  for (final p in small) {
    final lum = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
    if (lum < 140) {
      out.setPixelRgba(p.x, p.y, 20, 30, 60, 255);
      if (p.x < minX) minX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.x > maxX) maxX = p.x;
      if (p.y > maxY) maxY = p.y;
    } else {
      out.setPixelRgba(p.x, p.y, 255, 255, 255, 0);
    }
  }
  if (maxX < 0) return null;
  final crop = img.copyCrop(out, x: (minX - 8).clamp(0, out.width), y: (minY - 8).clamp(0, out.height),
      width: (maxX - minX + 16).clamp(1, out.width), height: (maxY - minY + 16).clamp(1, out.height));
  return Uint8List.fromList(img.encodePng(crop));
}

/// Admin: Nukad Kart's signature, drawn or uploaded once, used on every partner agreement.
class AdminSignatureScreen extends StatefulWidget {
  final String name;
  final String? current; // base64 PNG
  const AdminSignatureScreen({super.key, required this.name, this.current});
  @override
  State<AdminSignatureScreen> createState() => _AdminSignatureScreenState();
}

class _AdminSignatureScreenState extends State<AdminSignatureScreen> {
  bool draw = true, _saving = false, _drawing = false;
  final _pad = GlobalKey<SignaturePadState>();
  late final name = TextEditingController(text: widget.name);
  Uint8List? uploaded;

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600);
    if (x == null) return;
    final png = cleanSignature(await x.readAsBytes());
    if (!mounted) return;
    if (png == null) {
      toast(context, t('No signature found in the photo. Sign with a dark pen on white paper.'));
      return;
    }
    setState(() => uploaded = png);
  }

  Future<void> _save() async {
    final png = draw ? await _pad.currentState?.toPng(transparent: true) : uploaded;
    if (!mounted) return;
    if (png == null) {
      toast(context, t('Sign in the box with your finger.'));
      return;
    }
    if (name.text.trim().length < 3) {
      toast(context, t('Type your full name.'));
      return;
    }
    setState(() => _saving = true);
    try {
      await api.call('PUT', '/v1/admin/settings', {
        'signature': base64Encode(png),
        'party': {'signName': name.text.trim()},
      });
      if (mounted) {
        toast(context, t('Signature saved'));
        Navigator.pop(context, true);
      }
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => _saving = false);
  }

  Widget _tab(bool v, IconData i, String label) => Expanded(
        child: GestureDetector(
          onTap: () => setState(() => draw = v),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(color: draw == v ? kAct : kCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: draw == v ? kAct : kLine)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(i, size: 18, color: draw == v ? kOnAct : kMute),
              const SizedBox(width: 6),
              Text(label, style: tx(13.5, color: draw == v ? kOnAct : kInk, weight: FontWeight.w700)),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: bar(t('Nukad Kart signature')),
      body: ListView(
        physics: _drawing ? const NeverScrollableScrollPhysics() : null,
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.current != null && widget.current!.isNotEmpty) ...[
            Text(t('Current signature'), style: tx(12.5, color: kMute, weight: FontWeight.w700)),
            const SizedBox(height: 6),
            Container(height: 80, color: Colors.white, child: Image.memory(base64Decode(widget.current!), fit: BoxFit.contain)),
            const SizedBox(height: 16),
          ],
          Row(children: [_tab(true, Icons.draw_outlined, t('Draw')), _tab(false, Icons.upload_outlined, t('Upload photo'))]),
          const SizedBox(height: 12),
          if (draw) ...[
            Row(children: [
              Expanded(child: Text(t('Sign with your finger'), style: tx(12.5, color: kMute, weight: FontWeight.w700))),
              TextButton(onPressed: () => _pad.currentState?.clear(), child: Text(t('Clear'))),
            ]),
            SignaturePad(key: _pad, onActive: (on) => setState(() => _drawing = on)),
          ] else ...[
            GestureDetector(
              onTap: _pick,
              child: Container(
                height: 140,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kAct, width: 1.5)),
                child: uploaded == null
                    ? Center(child: Text(t('Choose a photo of your signature'), style: tx(14, color: const Color(0xFF315426), weight: FontWeight.w700)))
                    : Padding(padding: const EdgeInsets.all(10), child: Image.memory(uploaded!, fit: BoxFit.contain)),
              ),
            ),
            const SizedBox(height: 6),
            Text(t('Sign with a dark pen on white paper and take a photo. The paper is removed automatically.'), style: tx(12, color: kMute)),
          ],
          const SizedBox(height: 14),
          TextField(controller: name, decoration: field(tr('Full name, Proprietor'), label: t('Name under the signature'))),
          const SizedBox(height: 16),
          Btn(_saving ? t('Saving…') : t('Save signature'), onTap: _saving ? null : _save),
          const SizedBox(height: 8),
          Text(t('Used on every partner agreement as "For Nukad Kart".'), textAlign: TextAlign.center, style: tx(12, color: kMute)),
        ],
      ),
    );
  }
}
