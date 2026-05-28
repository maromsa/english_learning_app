/// Progress snapshot while [OfflinePracticeService] downloads practice packs.
class OfflinePackProgress {
  const OfflinePackProgress({
    required this.phase,
    this.completedLevels = 0,
    this.totalLevels = 0,
    this.currentLevelName,
    this.completedItems = 0,
    this.totalItems = 0,
    this.message,
    this.errorMessage,
  });

  final OfflinePackPhase phase;
  final int completedLevels;
  final int totalLevels;
  final String? currentLevelName;
  final int completedItems;
  final int totalItems;
  final String? message;
  final String? errorMessage;

  double get overallFraction {
    if (totalItems <= 0) {
      if (totalLevels <= 0) {
        return phase == OfflinePackPhase.complete ? 1.0 : 0.0;
      }
      return completedLevels / totalLevels;
    }
    return (completedItems / totalItems).clamp(0.0, 1.0);
  }

  bool get isFinished =>
      phase == OfflinePackPhase.complete || phase == OfflinePackPhase.failed;

  OfflinePackProgress copyWith({
    OfflinePackPhase? phase,
    int? completedLevels,
    int? totalLevels,
    String? currentLevelName,
    int? completedItems,
    int? totalItems,
    String? message,
    String? errorMessage,
  }) {
    return OfflinePackProgress(
      phase: phase ?? this.phase,
      completedLevels: completedLevels ?? this.completedLevels,
      totalLevels: totalLevels ?? this.totalLevels,
      currentLevelName: currentLevelName ?? this.currentLevelName,
      completedItems: completedItems ?? this.completedItems,
      totalItems: totalItems ?? this.totalItems,
      message: message ?? this.message,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

enum OfflinePackPhase {
  idle,
  preparing,
  downloading,
  complete,
  failed,
}
