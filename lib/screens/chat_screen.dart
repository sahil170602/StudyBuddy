// File: lib/screens/chat_screen.dart
// Full ChatScreen updated: uses _checkModelAssetAndPrepare() (web blob fetch) and debug print before ModelViewer.
// Requirements:
// - model_viewer_plus in pubspec.yaml
// - GLB at assets/models/robot.glb (no spaces)

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:universal_html/html.dart' as html;
import '../widgets/glass_card.dart';

const double kNavVisualHeight = 86.0;
const String GLB_ASSET_PATH = 'assets/models/robot.glb';
const String TEST_REMOTE_GLB = 'https://modelviewer.dev/shared-assets/models/Astronaut.glb';

const String GEMINI_API_KEY = 'AIzaSyBs3FSpD_Vj9myIchvAl0ZY2nJjZ4ssQOE';
const String GEMINI_MODEL = 'models/text-bison-001';
const String GEMINI_ENDPOINT = 'https://generativelanguage.googleapis.com/v1beta2/';

class ChatMessage {
  final String text;
  final bool fromBot;
  final DateTime time;
  ChatMessage(this.text, this.fromBot) : time = DateTime.now();
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final List<ChatMessage> _messages = [ChatMessage("Hello — I'm Buddy. Ask me anything!", true)];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  bool _chatMode = false;
  bool _voiceEnabled = true;

  late stt.SpeechToText _speech;
  bool _speechAvailable = false;
  bool _isListening = false;
  double _micLevel = 0.0;

  FlutterTts? _flutterTts;

  late AnimationController _mouthController;
  late AnimationController _speakPulseController;

  // model state
  bool _modelCheckDone = false;
  bool _modelExists = false;
  String? _modelLoadError;
  String? _resolvedSrc;

  Timer? _genTimer;
  Timer? _ttsPollTimer;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();
    _mouthController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400))..value = 0.0;
    _speakPulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    if (!kIsWeb) {
      _flutterTts = FlutterTts();
      _flutterTts?.setStartHandler(() => _speakPulseController.repeat(reverse: true));
      _flutterTts?.setCompletionHandler(() => _speakPulseController.stop());
    }
    // NOTE: we intentionally call the check function with the exact name you requested
    _checkModelAssetAndPrepare();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _mouthController.dispose();
    _speakPulseController.dispose();
    _flutterTts?.stop();
    _genTimer?.cancel();
    _ttsPollTimer?.cancel();
    super.dispose();
  }

  // ----------------------------
  // Replaced: _checkModelAssetAndPrepare()
  // Verifies asset bundle; on web fetches bytes via HTTP, creates Blob URL and sets _resolvedSrc.
  Future<void> _checkModelAssetAndPrepare() async {
    setState(() {
      _modelCheckDone = false;
      _modelExists = false;
      _modelLoadError = null;
      _resolvedSrc = null;
    });

    try {
      // quick check that asset is present in bundle
      final bytesCheck = await rootBundle.load(GLB_ASSET_PATH);
      if (bytesCheck.lengthInBytes == 0) throw Exception('Asset zero-length');

      if (kIsWeb) {
        // Resolve absolute URL for the asset served by Flutter web server
        final assetUrl = Uri.base.resolve(GLB_ASSET_PATH).toString();
        if (kDebugMode) debugPrint('Fetching GLB via HTTP: $assetUrl');

        final resp = await http.get(Uri.parse(assetUrl));
        if (resp.statusCode != 200) {
          throw Exception('HTTP ${resp.statusCode} fetching asset: $assetUrl');
        }

        // create a blob URL so <model-viewer> reads raw bytes (avoids path quirks)
        final blob = html.Blob([resp.bodyBytes], 'model/gltf-binary');
        final objectUrl = html.Url.createObjectUrlFromBlob(blob);

        if (kDebugMode) {
          debugPrint('Created objectUrl for GLB: $objectUrl');
          debugPrint('Response byteLength: ${resp.bodyBytes.length}');
        }

        setState(() {
          _modelCheckDone = true;
          _modelExists = true;
          _resolvedSrc = objectUrl;
        });
      } else {
        // non-web: use the asset path directly
        setState(() {
          _modelCheckDone = true;
          _modelExists = true;
          _resolvedSrc = GLB_ASSET_PATH;
        });
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('GLB prepare failed: $e');
        debugPrintStack(stackTrace: st);
      }
      setState(() {
        _modelCheckDone = true;
        _modelExists = false;
        _modelLoadError = e.toString();
        _resolvedSrc = null;
      });
    }
  }
  // ----------------------------

  Future<void> _loadRemoteTestModel() async {
    setState(() {
      _modelCheckDone = false;
      _modelExists = false;
      _modelLoadError = null;
      _resolvedSrc = null;
    });

    try {
      if (kIsWeb) {
        final resp = await http.get(Uri.parse(TEST_REMOTE_GLB));
        if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode} fetching test GLB');
        final blob = html.Blob([resp.bodyBytes], 'model/gltf-binary');
        final objectUrl = html.Url.createObjectUrlFromBlob(blob);
        setState(() {
          _modelCheckDone = true;
          _modelExists = true;
          _resolvedSrc = objectUrl;
        });
      } else {
        setState(() {
          _modelCheckDone = true;
          _modelExists = true;
          _resolvedSrc = TEST_REMOTE_GLB;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Load remote test model failed: $e');
      setState(() {
        _modelCheckDone = true;
        _modelExists = false;
        _modelLoadError = e.toString();
        _resolvedSrc = null;
      });
    }
  }

  // ----------------------------
  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (s) => kDebugMode ? debugPrint('STT status: $s') : null,
        onError: (e) => kDebugMode ? debugPrint('STT error: $e') : null,
      );
      setState(() {});
    } catch (e) {
      if (kDebugMode) debugPrint('STT init failed: $e');
    }
  }

  void _startListening() async {
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone not available')));
      return;
    }
    try {
      final ok = await _speech.initialize();
      if (!ok) return;
    } catch (_) {}
    setState(() => _isListening = true);
    _speech.listen(
      listenMode: stt.ListenMode.dictation,
      onResult: (res) {
        if (res.finalResult) {
          final text = res.recognizedWords.trim();
          if (text.isNotEmpty) _onUserText(text);
        }
      },
      onSoundLevelChange: (level) {
        final normalized = ((level + 50) / 50).clamp(0.0, 1.0);
        setState(() => _micLevel = normalized);
        _mouthController.animateTo(normalized.clamp(0.05, 1.0), duration: const Duration(milliseconds: 80), curve: Curves.easeOut);
      },
      cancelOnError: true,
    );
  }

  void _stopListening() async {
    await _speech.stop();
    setState(() {
      _isListening = false;
      _micLevel = 0.0;
    });
    _mouthController.animateTo(0.0, duration: const Duration(milliseconds: 120));
  }

  // ----------------------------
  Future<void> _speak(String text) async {
    if (!mounted) return;
    try {
      if (kIsWeb) {
        final utter = html.SpeechSynthesisUtterance(text);
        utter.rate = 1.0;
        utter.pitch = 1.0;
        html.window.speechSynthesis?.speak(utter);
        _speakPulseController.repeat(reverse: true);
        _ttsPollTimer?.cancel();
        _ttsPollTimer = Timer.periodic(const Duration(milliseconds: 120), (t) {
          final speaking = html.window.speechSynthesis?.speaking ?? false;
          if (!speaking) {
            _speakPulseController.stop();
            t.cancel();
          }
        });
      } else {
        _speakPulseController.repeat(reverse: true);
        await (_flutterTts ?? FlutterTts()).speak(text);
        _speakPulseController.stop();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('TTS error: $e');
    }
  }

  // ----------------------------
  Future<String> callGemini(String prompt) async {
    if (GEMINI_API_KEY.trim().isEmpty) return _localAiReply(prompt);
    final url = Uri.parse('${GEMINI_ENDPOINT}${GEMINI_MODEL}:generate?key=$GEMINI_API_KEY');
    final body = {"prompt": {"text": prompt}, "temperature": 0.2, "candidateCount": 1};
    try {
      final resp = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body)).timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) {
        final map = jsonDecode(resp.body) as Map<String, dynamic>;
        String? out;
        if (map['candidates'] != null && map['candidates'] is List && (map['candidates'] as List).isNotEmpty) {
          final cand = (map['candidates'] as List)[0];
          out = cand['output'] ?? cand['content'] ?? cand['text'] ?? cand.toString();
        } else if (map['output'] != null && map['output'] is List && (map['output'] as List).isNotEmpty) {
          final first = (map['output'] as List)[0];
          if (first is Map && first['content'] != null) {
            out = (first['content'] as List).map((e) => e['text'] ?? '').join(' ');
          }
        }
        out ??= map.values.map((v) => v.toString()).join(' ');
        return out.trim();
      } else {
        if (kDebugMode) debugPrint('Gemini HTTP ${resp.statusCode}: ${resp.body}');
        return _localAiReply(prompt);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Gemini call error: $e');
      return _localAiReply(prompt);
    }
  }

  String _localAiReply(String text) {
    final s = text.toLowerCase();
    if (s.contains('schedule') || s.contains('today')) return "Today's schedule — Wake 6:00 • Class 8:30 • Lunch 12:30 • Study 18:00.";
    if (s.contains('quiz')) return "Quiz options: Random or Syllabus — which do you want?";
    if (s.contains('hello') || s.contains('hi')) return "Hi! I'm Buddy — I can help with quizzes, schedules, and notes.";
    final replies = ["Got it — preparing a short summary.", "On it — searching resources.", "Okay — would you like this as a PDF?"];
    return replies[Random().nextInt(replies.length)];
  }

  // ----------------------------
  void _onUserText(String text) {
    setState(() => _messages.add(ChatMessage(text, false)));
    _scrollToBottom();
    if (_voiceEnabled) _speak("Let me check that for you.");
    _genTimer?.cancel();
    _genTimer = Timer(const Duration(milliseconds: 600), () async {
      final reply = await callGemini(text);
      if (!mounted) return;
      setState(() => _messages.add(ChatMessage(reply, true)));
      if (_voiceEnabled) await _speak(reply);
      _scrollToBottom();
    });
  }

  void _sendFromInput() {
    final t = _input.text.trim();
    if (t.isEmpty) return;
    _input.clear();
    _onUserText(t);
  }

  String _shortTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ap = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ap';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(_scroll.position.maxScrollExtent + 140, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  // ----------------------------
  Widget _modelErrorCard() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(children: [
            const Icon(Icons.broken_image, size: 48, color: Colors.redAccent),
            const SizedBox(height: 8),
            const Text('Model failed to load', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_modelLoadError ?? 'Unknown error', style: const TextStyle(fontSize: 12, color: Colors.white70)),
            const SizedBox(height: 12),
            const Text(
              'Quick checks:\n• Ensure GLB file exists at assets/models/robot.glb\n• Confirm assets are declared in pubspec.yaml and run `flutter pub get`\n• Open DevTools → Network and check robot.glb (200, Content-Type)',
              style: TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ElevatedButton(onPressed: _checkModelAssetAndPrepare, child: const Text('Re-check model asset')),
              ElevatedButton(onPressed: _loadRemoteTestModel, child: const Text('Load test Astronaut model')),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _buildTalkingPanel(double maxWidth) {
    if (!_modelCheckDone) return const Center(child: CircularProgressIndicator());
    if (!_modelExists) return _modelErrorCard();
    final src = _resolvedSrc ?? GLB_ASSET_PATH;
    if (kDebugMode) debugPrint('ModelViewer src => $src');

    return Center(
      child: Column(children: [
        const SizedBox(height: 8),
        Text('Buddy', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: min(640.0, maxWidth)),
          child: AspectRatio(
            aspectRatio: 1,
            child: Card(
              color: Colors.transparent,
              elevation: 0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(children: [
                  ModelViewer(
                    src: src,
                    alt: "Buddy 3D model",
                    autoRotate: true,
                    cameraControls: true,
                    backgroundColor: Colors.transparent,
                  ),
                  Positioned(
                    bottom: 36,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_mouthController, _speakPulseController]),
                        builder: (_, __) {
                          final micScale = (_micLevel * 1.6).clamp(0.08, 1.4);
                          final speakScale = _speakPulseController.isAnimating ? (1.0 + 0.28 * sin(_speakPulseController.value * pi * 2)) : 1.0;
                          final scale = micScale * speakScale;
                          return Transform.scale(
                            scale: scale,
                            child: Container(width: 120, height: 24, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12))),
                          );
                        },
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          ElevatedButton.icon(onPressed: _isListening ? _stopListening : _startListening, icon: Icon(_isListening ? Icons.mic_off : Icons.mic), label: Text(_isListening ? 'Stop' : 'Talk')),
          const SizedBox(width: 12),
          ElevatedButton.icon(onPressed: () => setState(() => _chatMode = true), icon: const Icon(Icons.open_in_full), label: const Text('Open Chat')),
          const SizedBox(width: 12),
          IconButton(icon: Icon(_voiceEnabled ? Icons.volume_up : Icons.volume_off, color: Colors.white70), onPressed: () => setState(() => _voiceEnabled = !_voiceEnabled)),
        ]),
      ]),
    );
  }

  Widget _miniPreview() {
    final preview = _messages.reversed.take(3).toList();
    if (!_modelCheckDone) return const SizedBox.shrink();
    if (!_modelExists) return _modelErrorCard();
    final src = _resolvedSrc ?? GLB_ASSET_PATH;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.16), borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            SizedBox(width: 64, height: 64, child: ModelViewer(src: src, alt: "Buddy", autoRotate: true, cameraControls: false, backgroundColor: Colors.transparent)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('News for you', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                for (final m in preview)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('${m.fromBot ? 'Buddy: ' : 'You: '}${m.text}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
                  ),
              ]),
            ),
            const SizedBox(width: 8),
            IconButton(onPressed: () => setState(() => _chatMode = true), icon: const Icon(Icons.open_in_full, color: Colors.white70)),
          ]),
        ),
      ),
    );
  }

  Widget _buildChatPanel(double maxWidth) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GlassCard(
            child: SizedBox(
              height: MediaQuery.of(context).size.height - 140,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(children: [
                    SizedBox(
                      width: 56,
                      height: 56,
                      child: _modelExists ? ModelViewer(src: _resolvedSrc ?? GLB_ASSET_PATH, autoRotate: true, cameraControls: false, backgroundColor: Colors.transparent) : const SizedBox.shrink(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Buddy', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold))),
                    IconButton(icon: Icon(_voiceEnabled ? Icons.volume_up : Icons.volume_off, color: Colors.white70), onPressed: () => setState(() => _voiceEnabled = !_voiceEnabled)),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => setState(() => _chatMode = false)),
                  ]),
                ),
                const Divider(color: Colors.white12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: ListView.builder(
                      controller: _scroll,
                      itemCount: _messages.length,
                      itemBuilder: (_, i) {
                        final m = _messages[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            mainAxisAlignment: m.fromBot ? MainAxisAlignment.start : MainAxisAlignment.end,
                            children: [
                              ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.66),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: m.fromBot ? Colors.white10 : Colors.blueAccent.withOpacity(0.18), borderRadius: BorderRadius.circular(12)),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(m.text, style: const TextStyle(color: Colors.white)),
                                    const SizedBox(height: 6),
                                    Text(_shortTime(m.time), style: const TextStyle(color: Colors.white30, fontSize: 10)),
                                  ]),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white10,
                          hintText: 'Message Buddy...',
                          hintStyle: const TextStyle(color: Colors.white54),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        onSubmitted: (_) => _sendFromInput(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(onPressed: _sendFromInput, child: const Icon(Icons.send)),
                    const SizedBox(width: 8),
                    IconButton(icon: Icon(_isListening ? Icons.mic_off : Icons.mic, color: Colors.white70), onPressed: _isListening ? _stopListening : _startListening),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomReserve = kNavVisualHeight + MediaQuery.of(context).viewPadding.bottom;
    final maxWidth = MediaQuery.of(context).size.width.clamp(0, 1000).toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFF071229),
      body: SafeArea(
        child: Stack(children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: bottomReserve + 8, top: 8),
              child: Column(children: [
                AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: _chatMode ? _buildChatPanel(maxWidth) : _buildTalkingPanel(maxWidth)),
                const SizedBox(height: 12),
              ]),
            ),
          ),
          if (!_chatMode) Positioned(left: 12, right: 12, bottom: bottomReserve - 44, child: _miniPreview()),
        ]),
      ),
    );
  }
}