// In-app voice call with no phone numbers shown (same file in the customer and the Partner app).
// Audio goes phone-to-phone over WebRTC (or through Cloudflare TURN when a network blocks that); the server only
// checks who may call, rings the other phone and passes the connection messages. Nothing is recorded.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

class VoiceError implements Exception {
  final String code, detail;
  const VoiceError(this.code, [this.detail = '']);
  @override
  String toString() => code;
}

/// Words on the call screen: English, Hindi or Hinglish (the app passes which).
String voiceText(String key, String lang) {
  const hi = {
    'Calling…': 'कॉल लग रही है…',
    'Ringing…': 'घंटी जा रही है…',
    'Incoming call': 'कॉल आ रही है',
    'Connecting…': 'जुड़ रहा है…',
    'Call ended': 'कॉल ख़त्म',
    'No answer': 'जवाब नहीं मिला',
    'Declined': 'मना कर दिया',
    'Answer': 'उठाएँ',
    'Decline': 'काटें',
    'Mute': 'म्यूट',
    'Speaker': 'स्पीकर',
    'End': 'काटें',
    'Your number is hidden. Calls are not recorded.': 'आपका नंबर छिपा है। कॉल रिकॉर्ड नहीं होती।',
    'call_closed': 'अब इस ऑर्डर पर कॉल नहीं हो सकती।',
    'call_busy': 'एक कॉल पहले से चल रही है।',
    'call_over': 'यह कॉल ख़त्म हो चुकी है।',
    'callee_offline': 'सामने वाले का फ़ोन अभी ऐप पर नहीं मिला (नेट बंद या लॉग आउट)। चैट भेजें।',
    'mic': 'माइक की इजाज़त चाहिए। फ़ोन सेटिंग में Nukkad Kart को माइक दें।',
    'offline': 'इंटरनेट नहीं है। फिर कोशिश करें।',
    'error': 'कॉल नहीं लगी। फिर कोशिश करें।',
  };
  const hg = {
    'Calling…': 'Call lag rahi hai…',
    'Ringing…': 'Ghanti ja rahi hai…',
    'Incoming call': 'Call aa rahi hai',
    'Connecting…': 'Jud raha hai…',
    'Call ended': 'Call khatam',
    'No answer': 'Jawab nahi mila',
    'Declined': 'Mana kar diya',
    'Answer': 'Uthao',
    'Decline': 'Kaato',
    'Mute': 'Mute',
    'Speaker': 'Speaker',
    'End': 'Kaato',
    'Your number is hidden. Calls are not recorded.': 'Aapka number chhupa hai. Call record nahi hoti.',
    'call_closed': 'Ab is order par call nahi ho sakti.',
    'call_busy': 'Ek call pehle se chal rahi hai.',
    'call_over': 'Yeh call khatam ho chuki hai.',
    'callee_offline': 'Saamne wale ka phone abhi app par nahi mila (net band ya logout). Chat bhejo.',
    'mic': 'Mic ki permission chahiye. Phone settings mein Nukkad Kart ko mic do.',
    'offline': 'Internet nahi hai. Phir try karo.',
    'error': 'Call nahi lagi. Phir try karo.',
  };
  const en = {
    'call_closed': 'Calls are closed for this order now.',
    'call_busy': 'A call is already going on.',
    'call_over': 'This call has ended.',
    'callee_offline': 'Their phone can’t be reached in the app right now (offline or logged out). Send a chat.',
    'mic': 'Microphone permission is needed. Allow it for Nukkad Kart in phone settings.',
    'offline': 'No internet. Try again.',
    'error': 'The call did not connect. Try again.',
  };
  final m = lang == 'hi' ? hi : (lang == 'hg' ? hg : en);
  return m[key] ?? en[key] ?? key;
}

enum VoiceState { idle, calling, incoming, connecting, connected, ended }

/// One call: the server steps, the microphone, the WebRTC connection and the message socket.
class VoiceCall extends ChangeNotifier {
  final String base; // https://…
  final String Function() token;
  VoiceCall({required this.base, required this.token, this.other = ''});

  String id = '', other, title = '';
  bool outgoing = false, muted = false, speaker = false;
  VoiceState state = VoiceState.idle;
  String endReason = ''; // '', 'missed', 'declined'
  DateTime? connectedAt;

  RTCPeerConnection? _pc;
  MediaStream? _mic;
  WebSocketChannel? _ws;
  StreamSubscription? _wsSub;
  Timer? _ping, _giveUp;
  List<Map<String, dynamic>> _ice = [];
  final List<RTCIceCandidate> _pending = [];
  bool _remoteSet = false, _offered = false, _closed = false, _disposed = false;

  Future<Map<String, dynamic>> _get(String path) async {
    http.Response res;
    try {
      res = await http.get(Uri.parse('$base$path'), headers: {'authorization': 'Bearer ${token()}'}).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const VoiceError('offline');
    }
    Map<String, dynamic> d = {};
    try {
      d = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    } catch (_) {}
    if (res.statusCode >= 400) throw VoiceError('${d['error'] ?? 'error'}', '${d['detail'] ?? ''}');
    return d;
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    http.Response res;
    try {
      res = await http
          .post(Uri.parse('$base$path'),
              headers: {'content-type': 'application/json', 'authorization': 'Bearer ${token()}'}, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const VoiceError('offline');
    }
    Map<String, dynamic> d = {};
    try {
      d = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    } catch (_) {}
    if (res.statusCode >= 400) throw VoiceError('${d['error'] ?? 'error'}', '${d['detail'] ?? ''}');
    return d;
  }

  void _take(Map<String, dynamic> r) {
    final c = Map<String, dynamic>.from(r['call'] as Map);
    id = '${c['id']}';
    other = '${c['other'] ?? ''}';
    title = '${c['title'] ?? ''}';
    outgoing = c['outgoing'] == true;
    if (r['ice'] is List && (r['ice'] as List).isNotEmpty) {
      _ice = (r['ice'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
  }

  /// Call the other side of an order (kind 'order', ref = order id) or a street call (kind 'thela', ref = call id).
  /// [to]: on an order, the customer picks 'store' (the shop) or 'rider' (the delivery partner).
  Future<void> start(String kind, String ref, {String to = ''}) async {
    outgoing = true;
    state = VoiceState.calling;
    notifyListeners();
    final r = await _post('/v1/voice/start', {'kind': kind, 'ref': ref, if (to.isNotEmpty) 'to': to});
    _take(r);
    // "End" pressed while the server was still ringing the other phone: stop that ring too.
    if (_closed) {
      try {
        await _post('/v1/voice/$id/end', {});
      } catch (_) {}
      return;
    }
    notifyListeners();
    try {
      await _media();
    } catch (_) {
      await hangup();
      throw const VoiceError('mic');
    }
    await _socket();
    // Nobody answered in 45 s: stop (the server counts it as missed).
    _giveUp = Timer(const Duration(seconds: 45), () {
      if (state != VoiceState.connected) {
        endReason = 'missed';
        hangup();
      }
    });
  }

  /// A call that rang this phone (from the push): who is calling, still ringing?
  Future<void> load(String callId) async {
    final r = await _get('/v1/voice/$callId');
    _take(r);
    final st = '${(r['call'] as Map)['status']}';
    state = st == 'ringing' ? VoiceState.incoming : (st == 'connected' ? VoiceState.connecting : VoiceState.ended);
    if (state == VoiceState.ended) endReason = st;
    notifyListeners();
    if (state == VoiceState.incoming) {
      // Caller gave up while this screen was opening: the server says so; check again in a few seconds.
      _giveUp = Timer.periodic(const Duration(seconds: 4), (t) async {
        if (state != VoiceState.incoming) {
          t.cancel();
          return;
        }
        try {
          final s = '${((await _get('/v1/voice/$id'))['call'] as Map)['status']}';
          if (s != 'ringing' && state == VoiceState.incoming) {
            endReason = s;
            _finish();
          }
        } catch (_) {}
      });
    }
  }

  Future<void> answer() async {
    _giveUp?.cancel();
    state = VoiceState.connecting;
    notifyListeners();
    try {
      _take(await _post('/v1/voice/$id/answer', {}));
      await _media();
      await _socket();
      _send({'type': 'ready'});
    } on VoiceError {
      _finish();
      rethrow;
    } catch (_) {
      await hangup();
      throw const VoiceError('mic');
    }
  }

  Future<void> decline() async {
    try {
      await _post('/v1/voice/$id/decline', {});
    } catch (_) {}
    endReason = 'declined';
    _finish();
  }

  Future<void> hangup() async {
    if (_closed) return;
    _send({'type': 'bye'});
    final callId = id;
    _finish(); // the screen ends at once; the server is told meanwhile
    if (callId.isNotEmpty) {
      try {
        await _post('/v1/voice/$callId/end', {});
      } catch (_) {}
    }
  }

  void toggleMute() {
    muted = !muted;
    for (final t in _mic?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      t.enabled = !muted;
    }
    notifyListeners();
  }

  Future<void> toggleSpeaker() async {
    speaker = !speaker;
    try {
      await Helper.setSpeakerphoneOn(speaker);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _media() async {
    _mic = await navigator.mediaDevices.getUserMedia({'audio': {'echoCancellation': true, 'noiseSuppression': true}, 'video': false});
    _pc = await createPeerConnection({'iceServers': _ice, 'sdpSemantics': 'unified-plan'});
    for (final t in _mic!.getAudioTracks()) {
      await _pc!.addTrack(t, _mic!);
    }
    _pc!.onIceCandidate = (c) {
      if (c.candidate != null) _send({'type': 'ice', 'candidate': c.candidate, 'sdpMid': c.sdpMid, 'sdpMLineIndex': c.sdpMLineIndex});
    };
    _pc!.onConnectionState = (s) {
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateConnected && state != VoiceState.connected) {
        _giveUp?.cancel();
        state = VoiceState.connected;
        connectedAt = DateTime.now();
        HapticFeedback.mediumImpact();
        notifyListeners();
      }
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed) hangup();
    };
    try {
      await Helper.setSpeakerphoneOn(false);
    } catch (_) {}
  }

  Future<void> _socket() async {
    final ws = base.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');
    _ws = IOWebSocketChannel.connect(Uri.parse('$ws/v1/voice/$id/socket'), headers: {'authorization': 'Bearer ${token()}'});
    _wsSub = _ws!.stream.listen((m) => _onMsg('$m'), onDone: () {
      if (state != VoiceState.connected && state != VoiceState.ended) _finish();
    }, onError: (_) {});
    _ping = Timer.periodic(const Duration(seconds: 25), (_) => _ws?.sink.add('ping'));
  }

  void _send(Map<String, dynamic> m) {
    try {
      _ws?.sink.add(jsonEncode(m));
    } catch (_) {}
  }

  Future<void> _offer() async {
    if (_offered || _pc == null) return;
    _offered = true;
    final o = await _pc!.createOffer({'offerToReceiveAudio': true, 'offerToReceiveVideo': false});
    await _pc!.setLocalDescription(o);
    _send({'type': 'offer', 'sdp': o.sdp});
    if (state == VoiceState.calling) {
      state = VoiceState.connecting;
      notifyListeners();
    }
  }

  Future<void> _onMsg(String raw) async {
    if (raw == 'pong') return;
    Map<String, dynamic> m;
    try {
      m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return;
    }
    switch ('${m['type']}') {
      case 'joined':
        // The other phone opened the room. Caller: start; callee: say "ready" again in case it was missed.
        if (outgoing && m['who'] == 'callee') await _offer();
        if (!outgoing && m['who'] == 'caller') _send({'type': 'ready'});
      case 'ready':
        if (outgoing) await _offer();
      case 'offer':
        if (outgoing || _pc == null) return;
        await _pc!.setRemoteDescription(RTCSessionDescription('${m['sdp']}', 'offer'));
        await _flush();
        final a = await _pc!.createAnswer({});
        await _pc!.setLocalDescription(a);
        _send({'type': 'answer', 'sdp': a.sdp});
      case 'answer':
        if (!outgoing || _pc == null) return;
        await _pc!.setRemoteDescription(RTCSessionDescription('${m['sdp']}', 'answer'));
        await _flush();
      case 'ice':
        final c = RTCIceCandidate('${m['candidate']}', m['sdpMid'] as String?, (m['sdpMLineIndex'] as num?)?.toInt());
        if (_remoteSet) {
          await _pc?.addCandidate(c);
        } else {
          _pending.add(c);
        }
      case 'bye':
        if (state != VoiceState.connected && outgoing) endReason = 'declined';
        _finish();
    }
  }

  Future<void> _flush() async {
    _remoteSet = true;
    for (final c in _pending) {
      await _pc?.addCandidate(c);
    }
    _pending.clear();
  }

  /// Server says the other side hung up before answering (push "voice_end").
  void remoteEnded() {
    if (state == VoiceState.incoming || state == VoiceState.calling) endReason = 'missed';
    _finish();
  }

  void _finish() {
    if (_closed) return;
    _closed = true;
    _giveUp?.cancel();
    _ping?.cancel();
    _wsSub?.cancel();
    try {
      _ws?.sink.close();
    } catch (_) {}
    for (final t in _mic?.getTracks() ?? <MediaStreamTrack>[]) {
      t.stop();
    }
    _mic?.dispose();
    _pc?.close();
    state = VoiceState.ended;
    if (!_disposed) notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    if (!_closed) hangup();
    _disposed = true;
    super.dispose();
  }
}

/// The open call, so a push ("voice_end") can reach it.
final ValueNotifier<VoiceCall?> currentVoiceCall = ValueNotifier(null);

/// Full-screen call: who (role only, never a name or number), status / timer, mute, speaker, end;
/// Answer / Decline while ringing in.
class VoiceCallScreen extends StatefulWidget {
  final VoiceCall call;
  final String lang;
  final String? startKind, startRef; // outgoing: start this when the screen opens
  final String startTo; // outgoing order call: 'store' or 'rider'
  final String? incomingId; // incoming: load this call
  final bool autoAnswer; // "Answer" pressed on the notification
  final VoidCallback? stopRing; // stops the ringing notification once answered / declined / over
  const VoiceCallScreen(
      {super.key,
      required this.call,
      required this.lang,
      this.startKind,
      this.startRef,
      this.startTo = '',
      this.incomingId,
      this.autoAnswer = false,
      this.stopRing});

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  Timer? _tick;
  String? _error;

  // The call this screen opened with, kept for the screen's whole life. The app redraws its screens often (order
  // updates, theme); each redraw makes a new VoiceCallScreen widget with a new, empty VoiceCall. Reading
  // widget.call showed that empty one: stuck on "Calling…", and the buttons worked on a call that wasn't running.
  late final VoiceCall c = widget.call;
  String w(String k) => voiceText(k, widget.lang);

  @override
  void initState() {
    super.initState();
    currentVoiceCall.value = c;
    c.addListener(_changed);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (c.state == VoiceState.connected && mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _begin());
  }

  Future<void> _begin() async {
    try {
      if (widget.startKind != null) await c.start(widget.startKind!, widget.startRef!, to: widget.startTo);
      if (widget.incomingId != null) {
        await c.load(widget.incomingId!);
        if (c.state != VoiceState.incoming) widget.stopRing?.call();
        if (widget.autoAnswer && c.state == VoiceState.incoming) {
          widget.stopRing?.call();
          await c.answer();
        }
      }
    } on VoiceError catch (e) {
      if (mounted) setState(() => _error = w(e.code.startsWith('call_') || const ['mic', 'offline', 'callee_offline'].contains(e.code) ? e.code : 'error'));
    }
  }

  void _changed() {
    if (!mounted) return;
    if (c.state != VoiceState.incoming) widget.stopRing?.call();
    setState(() {});
    if (c.state == VoiceState.ended) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    c.removeListener(_changed);
    widget.stopRing?.call();
    if (currentVoiceCall.value == c) currentVoiceCall.value = null;
    c.dispose();
    super.dispose();
  }

  String get _status {
    if (_error != null) return _error!;
    switch (c.state) {
      case VoiceState.idle:
      case VoiceState.calling:
        return c.id.isEmpty ? w('Calling…') : w('Ringing…');
      case VoiceState.incoming:
        return w('Incoming call');
      case VoiceState.connecting:
        return c.outgoing ? w('Ringing…') : w('Connecting…');
      case VoiceState.connected:
        final d = DateTime.now().difference(c.connectedAt ?? DateTime.now());
        return '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
      case VoiceState.ended:
        return c.endReason == 'declined' ? w('Declined') : (c.endReason == 'missed' ? w('No answer') : w('Call ended'));
    }
  }

  Widget _round(IconData icon, String label, Color bg, VoidCallback? onTap, {bool on = false}) => Column(mainAxisSize: MainAxisSize.min, children: [
        Material(
          color: on ? Colors.white : bg,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap == null
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    onTap();
                  },
            child: SizedBox(width: 68, height: 68, child: Icon(icon, color: on ? Colors.black87 : Colors.white, size: 30)),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ]);

  @override
  Widget build(BuildContext context) {
    final incoming = c.state == VoiceState.incoming;
    final live = c.state != VoiceState.ended && _error == null;
    return PopScope(
      canPop: !live,
      child: Scaffold(
        backgroundColor: const Color(0xFF16210F),
        body: SafeArea(
          // Full width, so everything stays in the middle also when only one button is left (call ended).
          child: SizedBox(
            width: double.infinity,
            child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            const SizedBox(height: 60),
            CircleAvatar(
              radius: 52,
              backgroundColor: const Color(0xFF2E4424),
              child: Icon(
                  c.other == 'Customer'
                      ? Icons.person
                      : (c.other == 'Delivery partner' ? Icons.delivery_dining : Icons.storefront),
                  color: const Color(0xFFF8CB46),
                  size: 56),
            ),
            const SizedBox(height: 18),
            Text(c.other.isEmpty ? ' ' : c.other, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
            if (c.title.isNotEmpty) Text(c.title, style: const TextStyle(color: Colors.white60, fontSize: 14)),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(_status, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFF8CB46), fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            const Spacer(),
            const SizedBox(height: 28),
            if (incoming)
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _round(Icons.call_end, w('Decline'), const Color(0xFFD93025), c.decline),
                _round(Icons.call, w('Answer'), const Color(0xFF1E8E3E), () async {
                  try {
                    await c.answer();
                  } on VoiceError catch (e) {
                    if (mounted) setState(() => _error = w(e.code == 'mic' || e.code.startsWith('call_') ? e.code : 'error'));
                  }
                }),
              ])
            else if (live)
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _round(c.muted ? Icons.mic_off : Icons.mic, w('Mute'), const Color(0xFF2E4424), c.toggleMute, on: c.muted),
                _round(Icons.call_end, w('End'), const Color(0xFFD93025), c.hangup),
                _round(Icons.volume_up, w('Speaker'), const Color(0xFF2E4424), c.toggleSpeaker, on: c.speaker),
              ])
            else
              _round(Icons.close, w('Call ended'), const Color(0xFF2E4424), () => Navigator.pop(context)),
            const SizedBox(height: 48),
          ]),
          ),
        ),
      ),
    );
  }
}

/// Wraps the whole app: while the app is on screen, asks every 3 seconds whether a call is ringing for this
/// phone, and opens the ringing screen (and rings). This way an open app always gets the call, even when the
/// ring push is late or never comes. Pauses while the app is in the background (the push rings then).
class VoiceIncomingWatcher extends StatefulWidget {
  final Widget child;
  final String base, lang;
  final String Function() token;

  /// The app's navigator (the watcher sits above it, in MaterialApp.builder).
  final GlobalKey<NavigatorState>? navigatorKey;

  /// Ring the phone (the app's call notification) for a call found by asking.
  final void Function(Map<String, dynamic> call)? ring;

  /// Stop that ringing (call answered / declined / over).
  final void Function(String id)? stopRing;
  const VoiceIncomingWatcher(
      {super.key, required this.child, required this.base, required this.token, required this.lang, this.navigatorKey, this.ring, this.stopRing});
  @override
  State<VoiceIncomingWatcher> createState() => _VoiceIncomingWatcherState();
}

class _VoiceIncomingWatcherState extends State<VoiceIncomingWatcher> with WidgetsBindingObserver {
  Timer? _t;
  bool _busy = false;
  final Set<String> _seen = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _run();
  }

  void _run() {
    _t?.cancel();
    _t = Timer.periodic(const Duration(seconds: 3), (_) => _check());
    _check();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      _run();
    } else if (s == AppLifecycleState.paused || s == AppLifecycleState.detached) {
      _t?.cancel();
      _t = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _t?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    if (_busy || currentVoiceCall.value != null || !mounted) return;
    final tok = widget.token();
    if (tok.isEmpty) return;
    _busy = true;
    try {
      final r = await http
          .get(Uri.parse('${widget.base}/v1/voice/incoming'), headers: {'authorization': 'Bearer $tok'})
          .timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return;
      final c = (jsonDecode(r.body) as Map)['call'];
      if (c is! Map) return;
      final id = '${c['id']}';
      if (_seen.contains(id) || currentVoiceCall.value != null || !mounted) return;
      _seen.add(id);
      // The ring push may be opening this same call right now: let it, and don't open a second screen.
      await Future.delayed(const Duration(milliseconds: 700));
      if (currentVoiceCall.value != null || !mounted) return;
      final nav = widget.navigatorKey?.currentState ?? Navigator.maybeOf(context);
      if (nav == null) return;
      widget.ring?.call({...Map<String, dynamic>.from(c), 'caller': '${c['other'] ?? ''}'});
      final call = VoiceCall(base: widget.base, token: widget.token, other: '${c['other'] ?? ''}');
      nav.push(
        MaterialPageRoute(
          builder: (_) => VoiceCallScreen(
              call: call,
              lang: widget.lang,
              incomingId: id,
              stopRing: () => widget.stopRing?.call(id)),
        ),
      );
    } catch (_) {
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
