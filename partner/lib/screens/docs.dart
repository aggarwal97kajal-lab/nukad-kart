import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../api.dart';
import '../session.dart';
import '../ui.dart';
import 'register.dart';

const maxDocBytes = 2 * 1024 * 1024;
const _chunkBytes = 256 * 1024; // raw bytes per part; 4 parts go at once, so the meter moves smoothly
const _parallel = 4;

Map<String, (String, String)> get docLabels => {
  'pan': (tr('PAN card'), tr('Clear photo or PDF of your PAN card')),
  'aadhaar': (tr('Aadhaar (masked)'), tr('Cover the first 8 digits before taking the photo')),
  'gst': (tr('GST certificate'), tr('Needed because you entered a GSTIN')),
  'fssai': (tr('FSSAI certificate'), tr('Required if you entered an FSSAI number')),
};

String sizeText(int b) => b >= 1024 * 1024 ? '${(b / 1024 / 1024).toStringAsFixed(1)} MB' : '${(b / 1024).round()} KB';

/// Step 3: PAN, Aadhaar (masked), GST and FSSAI documents. JPG or PDF, up to 2 MB each.
class DocsScreen extends StatefulWidget {
  /// Opened from home to fix documents after Nukad team asked for changes.
  final bool pushed;
  const DocsScreen({super.key, this.pushed = false});
  @override
  State<DocsScreen> createState() => _DocsScreenState();
}

class _DocsScreenState extends State<DocsScreen> {
  List<Map<String, dynamic>> docs = [];
  List<String> required = [], optional = [];
  bool _loading = true;
  final Map<String, double> progress = {}; // type → 0..1 while uploading
  final Map<String, (int, int)> sent = {}; // type → (bytes sent, total)

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await api.call('GET', '/v1/partner/docs');
      docs = ((r['docs'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      required = ((r['required'] as List?) ?? []).map((e) => '$e').toList();
      optional = ((r['optional'] as List?) ?? []).map((e) => '$e').toList();
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => _loading = false);
  }

  Map<String, dynamic>? _doc(String type) {
    for (final d in docs) {
      if (d['type'] == type) return d;
    }
    return null;
  }

  Future<void> _choose(String type) async {
    final how = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(tr('{0} · JPG or PDF, max 2 MB', [docLabels[type]!.$1]), style: tx(15, weight: FontWeight.w800)),
          ),
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: Text(tr('Take photo')), onTap: () => Navigator.pop(ctx, 'camera')),
          ListTile(leading: const Icon(Icons.image_outlined), title: Text(tr('Choose JPG photo')), onTap: () => Navigator.pop(ctx, 'jpg')),
          ListTile(leading: const Icon(Icons.picture_as_pdf_outlined), title: Text(tr('Choose PDF file')), onTap: () => Navigator.pop(ctx, 'pdf')),
        ]),
      ),
    );
    if (how == null) return;
    Uint8List? bytes;
    String name = '', mime = 'image/jpeg';
    try {
      if (how == 'camera') {
        final x = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 2000, imageQuality: 80);
        if (x == null) return;
        bytes = await x.readAsBytes();
        name = '$type.jpg';
      } else {
        final r = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: how == 'pdf' ? ['pdf'] : ['jpg', 'jpeg'],
          withData: true,
        );
        final f = r?.files.single;
        if (f == null) return;
        bytes = f.bytes ?? (f.path != null ? await File(f.path!).readAsBytes() : null);
        name = f.name;
        mime = f.name.toLowerCase().endsWith('.pdf') ? 'application/pdf' : 'image/jpeg';
      }
    } catch (_) {
      if (mounted) toast(context, tr('Could not open the file. Try again.'));
      return;
    }
    if (bytes == null || bytes.isEmpty || !mounted) return;
    if (bytes.length > maxDocBytes) {
      toast(context, tr('This file is {0}. Max 2 MB: take a smaller photo or compress the PDF.', [sizeText(bytes.length)]));
      return;
    }
    final isJpg = bytes.length > 2 && bytes[0] == 0xff && bytes[1] == 0xd8;
    final isPdf = bytes.length > 4 && bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46;
    if ((mime == 'image/jpeg' && !isJpg) || (mime == 'application/pdf' && !isPdf)) {
      toast(context, tr('Only JPG photos or PDF files can be uploaded.'));
      return;
    }
    await _upload(type, bytes, name, mime);
  }

  Future<void> _upload(String type, Uint8List bytes, String name, String mime) async {
    final parts = (bytes.length / _chunkBytes).ceil();
    setState(() {
      progress[type] = 0.02;
      sent[type] = (0, bytes.length);
    });
    try {
      final r = await api.call('POST', '/v1/partner/docs', {'type': type, 'mime': mime, 'size': bytes.length, 'name': name, 'chunks': parts});
      final id = '${r['id']}';
      var next = 0, doneBytes = 0;
      Future<void> worker() async {
        while (next < parts) {
          final i = next++;
          final end = (i + 1) * _chunkBytes > bytes.length ? bytes.length : (i + 1) * _chunkBytes;
          final res = await api.putBytes('/v1/partner/docs/$id/$i', bytes.sublist(i * _chunkBytes, end));
          doneBytes += end - i * _chunkBytes;
          if (!mounted) return;
          setState(() {
            progress[type] = doneBytes / bytes.length;
            sent[type] = (doneBytes, bytes.length);
          });
          if (res['done'] == true) {
            docs = ((res['docs'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        }
      }

      await Future.wait([for (var k = 0; k < (parts < _parallel ? parts : _parallel); k++) worker()]);
      if (mounted) toast(context, '${docLabels[type]!.$1} uploaded');
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (!mounted) return;
    setState(() {
      progress.remove(type);
      sent.remove(type);
    });
    if (widget.pushed) session.refresh().catchError((_) {});
  }

  Widget _row(String type, {bool isOptional = false}) {
    final d = _doc(type);
    final p = progress[type];
    final (title, hint) = docLabels[type]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Box(
        border: d != null ? kAct : kLine,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(d != null ? Icons.check_circle : Icons.upload_file, color: d != null ? kAct : kMute),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isOptional ? '$title (optional)' : '$title *', style: tx(14.5, weight: FontWeight.w800)),
                Text(
                    d != null
                        ? '${d['name'] ?? ''} · ${sizeText((d['size'] as num).toInt())} · ${d['mime'] == 'application/pdf' ? 'PDF' : 'JPG'}'
                        : (isOptional ? (type == 'fssai' ? tr('Add if you have one. Required only when you enter an FSSAI number.') : tr('Add if you have it.')) : hint),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tx(12, color: d != null ? kAct : kMute)),
              ]),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: p != null ? null : () => _choose(type),
              style: OutlinedButton.styleFrom(foregroundColor: kAct, side: BorderSide(color: kAct)),
              child: Text(d != null ? tr('Change') : tr('Upload')),
            ),
          ]),
          if (p != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: p),
                duration: const Duration(milliseconds: 250),
                builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 8, color: kAct, backgroundColor: kSurf),
              ),
            ),
            const SizedBox(height: 4),
            Text(tr('Uploading {0} of {1} · {2}%', [sizeText(sent[type]!.$1), sizeText(sent[type]!.$2), (p * 100).round()]),
                style: tx(11.5, color: kMute, weight: FontWeight.w700)),
          ],
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final missing = required.where((t) => _doc(t) == null).length;
    final busy = progress.isNotEmpty;
    return Scaffold(
      appBar: bar(tr('Upload documents'), actions: [
        if (!widget.pushed)
          PopupMenuButton<String>(
            onSelected: (_) => session.signOut(),
            itemBuilder: (_) => [PopupMenuItem(value: 'out', child: Text(tr('Log out')))],
          ),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              Text(tr('Step 3 of 5'), style: tx(12, color: kMute)),
              const SizedBox(height: 8),
              Box(
                color: kSurf,
                child: Row(children: [
                  Icon(Icons.info_outline, color: kAct, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(tr('JPG photo or PDF only · max 2 MB per file · all * documents are required. Nukad team checks them before your shop goes live.'),
                          style: tx(12.5, weight: FontWeight.w600))),
                ]),
              ),
              const SizedBox(height: 12),
              for (final t in required) _row(t),
              for (final t in optional) _row(t, isOptional: true),
              if (!widget.pushed) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                  child: Text(tr('Change business details')),
                ),
              ],
              const SizedBox(height: 8),
              Btn(
                busy ? tr('Uploading…') : (missing == 0 ? tr('Continue') : tr('Continue ({0} left)', [missing])),
                onTap: busy || missing > 0
                    ? null
                    : () async {
                        await session.refresh();
                        if (widget.pushed && context.mounted) Navigator.pop(context);
                      },
              ),
            ]),
    );
  }
}

