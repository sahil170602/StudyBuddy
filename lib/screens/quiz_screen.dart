/* lib/screens/quiz_screen.dart */
// Full quiz screen. Uses AIService.generateQuiz for new quiz. Stores minimal local progress in memory.
// For production, persist progress to Hive/SQLite.

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/ai_services.dart';
import '../widgets/glass_card.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({Key? key}) : super(key: key);
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with SingleTickerProviderStateMixin {
  List<dynamic>? _currentQuiz;
  int _currentIndex = 0;
  int _score = 0;
  bool _loading = false;
  bool _inGame = false;
  Timer? _qTimer;
  int _timeLeft = 20; // seconds per question
  bool _showAnswer = false;

  @override
  void dispose() {
    _qTimer?.cancel();
    super.dispose();
  }

  Future<void> _startNewQuiz({required bool syllabusMode, String? syllabusText}) async {
    setState(() { _loading = true; });
    try {
      List<dynamic> quiz;
      if (syllabusMode && syllabusText != null) {
        quiz = await AIService.instance.generateQuiz(syllabusText, count: 10, difficulty: 'medium');
      } else {
        // random mode: ask backend to build from generic knowledge
        quiz = await AIService.instance.generateQuiz('General knowledge for student class', count: 10, difficulty: 'medium');
      }
      setState(() {
        _currentQuiz = quiz;
        _currentIndex = 0;
        _score = 0;
        _inGame = true;
        _loading = false;
      });
      _startQuestionTimer();
    } catch (e) {
      setState(() { _loading = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Quiz failed: $e')));
    }
  }

  void _startQuestionTimer() {
    _qTimer?.cancel();
    setState(() { _timeLeft = 20; _showAnswer = false; });
    _qTimer = Timer.periodic(const Duration(seconds:1), (t) {
      setState(() {
        _timeLeft -= 1;
        if (_timeLeft <= 0) {
          t.cancel();
          _onTimeUp();
        }
      });
    });
  }

  void _onTimeUp() {
    setState(() {
      _showAnswer = true;
    });
    Future.delayed(const Duration(seconds:2), _nextQuestion);
  }

  void _onPick(int idx) {
    if (_currentQuiz == null) return;
    final q = _currentQuiz![_currentIndex];
    final correct = q['correctIndex'] ?? 0;
    setState(() {
      if (!_showAnswer) {
        if (idx == correct) _score++;
        _showAnswer = true;
      }
    });
    Future.delayed(const Duration(milliseconds: 700), _nextQuestion);
  }

  void _nextQuestion() {
    _qTimer?.cancel();
    if (_currentQuiz == null) return;
    if (_currentIndex +1 >= _currentQuiz!.length) {
      // finished
      setState(() { _inGame = false; });
      _showResult();
      return;
    }
    setState(() {
      _currentIndex += 1;
      _showAnswer = false;
    });
    _startQuestionTimer();
  }

  void _showResult() {
    showDialog(context: context, builder: (ctx) {
      return AlertDialog(
        title: const Text('Quiz Complete'),
        content: Text('Score: $_score / ${_currentQuiz?.length ?? 0}'),
        actions: [TextButton(onPressed: () { Navigator.of(ctx).pop(); }, child: const Text('OK'))],
      );
    });
  }

  Widget _gameView() {
    if (_currentQuiz == null) return const SizedBox.shrink();
    final q = _currentQuiz![_currentIndex];
    final options = List<String>.from(q['options'] ?? []);
    final correct = q['correctIndex'] ?? 0;
    return Column(children: [
      Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: LinearProgressIndicator(value: (_currentIndex+1) / (_currentQuiz!.length))),
      Text('Question ${_currentIndex+1}/${_currentQuiz!.length}', style: const TextStyle(color: Colors.white70)),
      const SizedBox(height: 8),
      GlassCard(child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: [
          Text(q['question'] ?? 'Question', style: const TextStyle(fontSize: 18, color: Colors.white)),
          const SizedBox(height: 12),
          for (int i=0;i<options.length;i++)
            GestureDetector(
              onTap: () => _onPick(i),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical:6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _showAnswer
                    ? (i == correct ? Colors.green.withOpacity(0.3) : (i== (q['selectedIndex'] ?? -1) ? Colors.red.withOpacity(0.3) : Colors.white10))
                    : Colors.white10,
                  borderRadius: BorderRadius.circular(10)
                ),
                child: Row(children: [Expanded(child: Text(options[i], style: const TextStyle(color: Colors.white)))]),
              )
            )
        ]),
      )),
      const SizedBox(height: 12),
      Text('Time left: $_timeLeft s', style: const TextStyle(color: Colors.white70)),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        ElevatedButton(onPressed: () { setState(() { _inGame = false; }); _qTimer?.cancel(); }, child: const Text('Exit')),
      ])
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071229),
      appBar: AppBar(title: const Text('Quiz'), backgroundColor: Colors.transparent, elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: _loading ? const Center(child: CircularProgressIndicator()) : _inGame ? _gameView() : _menuView()
      ),
    );
  }

  Widget _menuView() {
    return Column(children: [
      GlassCard(child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('New Game', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          Row(children: [
            ElevatedButton(onPressed: () => showDialog(context: context, builder: (_) => _syllabusDialog()), child: const Text('Syllabus')),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: () => _startNewQuiz(syllabusMode: false), child: const Text('Random')),
          ])
        ]),
      )),
      const SizedBox(height: 12),
      GlassCard(child: Padding(padding: const EdgeInsets.all(12.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Continue', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 6),
        const Text('No previous session found', style: TextStyle(color: Colors.white30))
      ]))),
    ]);
  }

  Widget _syllabusDialog() {
    final TextEditingController _s = TextEditingController();
    return AlertDialog(
      title: const Text('Syllabus (paste text)'),
      content: TextField(controller: _s, maxLines: 8, decoration: const InputDecoration(hintText: 'Paste syllabus text or summary')),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(onPressed: () {
          Navigator.of(context).pop();
          _startNewQuiz(syllabusMode: true, syllabusText: _s.text.trim());
        }, child: const Text('Start'))
      ],
    );
  }
}
