import 'package:flutter/material.dart';
import '../models/quiz_item.dart';
import '../widgets/answer_button.dart';

// רשימת שאלות (אפשר להוציא לקובץ נפרד, או API)
final List<QuizItem> quizItems = [
  QuizItem(
    imageAsset: 'assets/images/apple.png',
    correctAnswer: 'Apple',
    wrongAnswers: ['Banana', 'Car', 'Dog'],
  ),
  QuizItem(
    imageAsset: 'assets/images/dog.png',
    correctAnswer: 'Dog',
    wrongAnswers: ['Cat', 'Fish', 'Bird'],
  ),
  QuizItem(
    imageAsset: 'assets/images/banana.png',
    correctAnswer: 'Banana',
    wrongAnswers: ['Apple', 'Car', 'Dog'],
  ),
];

class ImageQuizGame extends StatefulWidget {
  const ImageQuizGame({super.key});

  @override
  State<ImageQuizGame> createState() => _ImageQuizGameState();
}

class _ImageQuizGameState extends State<ImageQuizGame> {
  int _currentIndex = 0;
  bool _answered = false;
  String? _selectedAnswer;

  void _answerQuestion(String answer) {
    setState(() {
      _answered = true;
      _selectedAnswer = answer;
    });
  }

  void _nextQuestion() {
    setState(() {
      _answered = false;
      _selectedAnswer = null;
      _currentIndex = (_currentIndex + 1) % quizItems.length;
    });
  }


  @override
  Widget build(BuildContext context) {
    final quizItem = quizItems[_currentIndex];
    final options = quizItem.getShuffledAnswers();

    return Scaffold(
      backgroundColor: Colors.green.shade50,
      appBar: AppBar(
        title: const Text('משחק תמונות'),
        backgroundColor: Colors.green.shade700,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // תמונה עם מסגרת מעוגלת וצל קל
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
              ),
              clipBehavior: Clip.hardEdge,
              child: Image.asset(
                quizItem.imageAsset,
                height: 280,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final answer = options[index];
                  return AnswerButton(
                    answer: answer,
                    isSelected: _selectedAnswer == answer,
                    isCorrect: answer == quizItem.correctAnswer,
                    answered: _answered,
                    onTap: () => _answerQuestion(answer),
                  );
                },
              ),
            ),
            if (_answered)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 6,
                  ),
                  onPressed: _nextQuestion,
                  child: const Text(
                    'שאלה הבאה',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
