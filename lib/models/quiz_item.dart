import 'dart:math';

// מודל לשאלה
class QuizItem {
  final String imageAsset;
  final String correctAnswer;
  final List<String> wrongAnswers;

  QuizItem({
    required this.imageAsset,
    required this.correctAnswer,
    required this.wrongAnswers,
  });

  List<String> getShuffledAnswers({Random? random}) {
    final all = List<String>.from(wrongAnswers)..add(correctAnswer);
    all.shuffle(random);
    return all;
  }
}
