import 'dart:async';
import 'package:flutter/material.dart';
import 'ui.dart';

/// H13: search hint that types a word, waits, deletes it and types the next one.
class TypingHint extends StatefulWidget {
  final List<String> words;
  final String prefix;
  final Color textColor;
  final Color wordColor;
  const TypingHint({super.key, required this.words, this.prefix = 'Search', required this.textColor, required this.wordColor});
  @override
  State<TypingHint> createState() => _TypingHintState();
}

class _TypingHintState extends State<TypingHint> {
  Timer? _timer;
  int _word = 0;
  int _chars = 0;
  bool _deleting = false;
  int _hold = 0;
  bool _cursor = true;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(milliseconds: 70), (_) => _step());
  }

  void _step() {
    if (!mounted) return;
    final w = widget.words[_word % widget.words.length].characters;
    setState(() {
      _tick++;
      if (_tick % 7 == 0) _cursor = !_cursor;
      if (_hold > 0) {
        _hold--;
        return;
      }
      if (!_deleting) {
        if (_chars < w.length) {
          _chars++;
        } else {
          _deleting = true;
          _hold = 22; // ~1.5 s with the full word showing
        }
      } else {
        if (_chars > 0) {
          _chars--;
        } else {
          _deleting = false;
          _word++;
          _hold = 4;
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.words[_word % widget.words.length].characters;
    final shown = w.take(_chars.clamp(0, w.length)).toString();
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: '${widget.prefix} ', style: body(14.5, color: widget.textColor)),
        TextSpan(text: '"$shown', style: body(14.5, color: widget.wordColor, weight: FontWeight.w700)),
        TextSpan(text: _cursor ? '|' : ' ', style: body(14.5, color: kG, weight: FontWeight.w300)),
        if (_chars == w.length) TextSpan(text: '"', style: body(14.5, color: widget.wordColor, weight: FontWeight.w700)),
      ]),
      maxLines: 1,
      overflow: TextOverflow.clip,
    );
  }
}
