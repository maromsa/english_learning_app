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

  List<String> getShuffledAnswers() {
    final all = List<String>.from(wrongAnswers)..add(correctAnswer);
    all.shuffle();
    return all;
  }
}