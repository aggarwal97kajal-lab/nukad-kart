import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'ui.dart';
import '../l10n.dart';

/// H04: "Listening…" sheet. Uses the phone's Google speech service.
/// Returns what the person said, or null.
Future<String?> showVoiceSearch(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: kCard,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => const _VoiceSheet(),
  );
}

class _VoiceSheet extends StatefulWidget {
  const _VoiceSheet();
  @override
  State<_VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends State<_VoiceSheet> with SingleTickerProviderStateMixin {
  final SpeechToText _sp = SpeechToText();
  late final AnimationController _pulse;
  String _words = '';
  String? _error;
  bool _listening = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: Duration(milliseconds: 1100))..repeat(reverse: true);
    _start();
  }

  Future<void> _start() async {
    try {
      final ok = await _sp.initialize(
        onError: (e) {
          if (mounted) setState(() => _error = 'Didn’t catch that. Tap the mic and try again.');
        },
        onStatus: (st) {
          if (!mounted) return;
          setState(() => _listening = st == 'listening');
          if ((st == 'done' || st == 'notListening') && _words.trim().isNotEmpty) _finish();
        },
      );
      if (!mounted) return;
      if (!ok) {
        setState(() => _error = 'Voice search needs microphone permission and Google speech on this phone.');
        return;
      }
      setState(() {
        _error = null;
        _words = '';
      });
      await _sp.listen(
        localeId: gLang == 'en' ? 'en_IN' : 'hi_IN',
        listenFor: Duration(seconds: 10),
        pauseFor: Duration(seconds: 3),
        onResult: (r) {
          if (!mounted) return;
          setState(() => _words = r.recognizedWords);
          if (r.finalResult && _words.trim().isNotEmpty) _finish();
        },
      );
    } catch (_) {
      if (mounted) setState(() => _error = 'Voice search isn’t available on this phone.');
    }
  }

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    Navigator.pop(context, _words.trim());
  }

  @override
  void dispose() {
    _pulse.dispose();
    _sp.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 44, height: 5, decoration: BoxDecoration(color: kLine, borderRadius: BorderRadius.circular(3))),
          SizedBox(height: 14),
          Text('Bol kar search karein · Hindi ya English', style: body(13, color: kMute, weight: FontWeight.w700)),
          SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              if (_listening) {
                _sp.stop();
              } else {
                _start();
              }
            },
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                final k = _listening ? _pulse.value : 0.0;
                return SizedBox(
                  width: 150,
                  height: 150,
                  child: Stack(alignment: Alignment.center, children: [
                    Container(
                        width: 110 + 40 * k,
                        height: 110 + 40 * k,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Color(0x2E7CC242))),
                    Container(
                        width: 96 + 10 * k,
                        height: 96 + 10 * k,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Color(0x4D7CC242))),
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: _error != null ? kMute : kG),
                      child: Icon(_listening ? Icons.mic : Icons.mic_none, color: Colors.white, size: 36),
                    ),
                  ]),
                );
              },
            ),
          ),
          SizedBox(height: 12),
          Text(
            _error ?? (_words.isEmpty ? (_listening ? 'Listening…' : 'Starting…') : '“$_words”'),
            textAlign: TextAlign.center,
            style: _error != null ? body(14, color: kRed, weight: FontWeight.w600) : head(22),
          ),
          SizedBox(height: 6),
          Text(_listening ? 'Tap the mic to stop' : 'Tap the mic to try again', style: body(12.5, color: kMute)),
          SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            for (final w in ['Doodh', 'Cheeni', 'Tamatar']) Pill('TRY: ${w.toUpperCase()}', color: kGText, bg: kPillBg),
          ]),
        ]),
      ),
    );
  }
}
