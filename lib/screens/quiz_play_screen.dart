// lib/screens/quiz_play_screen.dart
import 'package:flutter/material.dart';
import '../widgets/glass_card.dart';

class QuizPlayScreen extends StatefulWidget {
  final String quizTitle;
  const QuizPlayScreen({super.key, required this.quizTitle});
  @override
  State<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<QuizPlayScreen> with SingleTickerProviderStateMixin {
  int _index = 0;
  int _score = 0;
  final List<Map<String, dynamic>> _questions = [
    {'q': '2 + 2', 'choices': ['3', '4', '5'], 'answer': 1},
    {'q': 'Capital of UK', 'choices': ['Paris', 'London', 'Rome'], 'answer': 1},
    {'q': 'Flutter language', 'choices': ['Kotlin', 'Dart', 'Swift'], 'answer': 1},
  ];

  late final AnimationController _revealController = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));

  @override
  void initState() {
    super.initState();
    _revealController.forward();
  }

  @override
  void dispose() {
    _revealController.dispose();
    super.dispose();
  }

  void _answer(int i) {
    final correct = _questions[_index]['answer'] == i;
    if (correct) _score++;

    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: Text(correct ? 'Correct' : 'Wrong'),
        content: Text(correct ? 'Nice!' : 'Better luck next'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                if (_index < _questions.length - 1) {
                  _index++;
                  _revealController.forward(from: 0);
                } else {
                  _showResult();
                }
              });
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _showResult() {
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (_) => AlertDialog(
        title: const Text('Result'),
        content: Text('Score: $_score / ${_questions.length}'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst), child: const Text('Home')),
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _questions[_index];
    return Scaffold(
      appBar: AppBar(title: Text(widget.quizTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(children: [
            LinearProgressIndicator(value: (_index + 1) / _questions.length, minHeight: 6),
            const SizedBox(height: 12),
            FadeTransition(
              opacity: CurvedAnimation(parent: _revealController, curve: Curves.easeIn),
              child: GlassCard(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('Q${_index + 1}: ${q['q']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))),
            ),
            const SizedBox(height: 12),
            ...List.generate((q['choices'] as List).length, (i) {
              final choice = (q['choices'] as List)[i].toString();
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ElevatedButton(
                  onPressed: () => _answer(i),
                  child: Align(alignment: Alignment.centerLeft, child: Text(choice)),
                ),
              );
            }),
            const Spacer(),
            Row(children: [
              TextButton(onPressed: () => setState(() => _index = 0), child: const Text('Restart')),
              const Spacer(),
              Text('Score: $_score', style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
          ]),
        ),
      ),
    );
  }
}
