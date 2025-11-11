import 'dart:convert';

enum DailyMissionType { speakPractice, lightningRound, quizPlay }

class DailyMission {
  final String id;
  final String title;
  final String description;
  final int target;
  final int reward;
  final DailyMissionType type;

  int progress;
  bool rewardClaimed;

  DailyMission({
    required this.id,
    required this.title,
    required this.description,
    required this.target,
    required this.reward,
    required this.type,
    this.progress = 0,
    this.rewardClaimed = false,
  });

  bool get isCompleted => progress >= target;
  double get completionRatio =>
      target == 0 ? 1 : (progress / target).clamp(0, 1);
  int get remaining {
    final remainingValue = target - progress;
    return remainingValue > 0 ? remainingValue : 0;
  }

  bool get isClaimable => isCompleted && !rewardClaimed;

  DailyMission copyWith({int? progress, bool? rewardClaimed}) {
    return DailyMission(
      id: id,
      title: title,
      description: description,
      target: target,
      reward: reward,
      type: type,
      progress: progress ?? this.progress,
      rewardClaimed: rewardClaimed ?? this.rewardClaimed,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'target': target,
    'reward': reward,
    'type': type.name,
    'progress': progress,
    'rewardClaimed': rewardClaimed,
  };

  factory DailyMission.fromMap(Map<String, dynamic> map) {
    return DailyMission(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      target: map['target'] as int,
      reward: map['reward'] as int,
      type: DailyMissionType.values.firstWhere(
        (value) => value.name == map['type'],
        orElse: () => DailyMissionType.speakPractice,
      ),
      progress: map['progress'] as int? ?? 0,
      rewardClaimed: map['rewardClaimed'] as bool? ?? false,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory DailyMission.fromJson(String source) =>
      DailyMission.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
