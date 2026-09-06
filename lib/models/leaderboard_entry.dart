/// A ranked row on the global leaderboard.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.profileId,
    required this.displayName,
    required this.totalCoins,
    required this.currentStreak,
    required this.avatarColor,
    required this.rank,
    this.avatarUrl,
    this.avatarId,
    this.isCurrentUser = false,
  });

  final String profileId;
  final String displayName;
  final int totalCoins;
  final int currentStreak;
  final int avatarColor;
  final String? avatarUrl;

  /// Optional kid-picked animal emoji (see `ChildProfile.avatarChoices`).
  /// Takes precedence over [avatarUrl] and the coloured initial when set.
  final String? avatarId;
  final int rank;
  final bool isCurrentUser;

  LeaderboardEntry copyWith({
    String? profileId,
    String? displayName,
    int? totalCoins,
    int? currentStreak,
    int? avatarColor,
    String? avatarUrl,
    String? avatarId,
    int? rank,
    bool? isCurrentUser,
  }) {
    return LeaderboardEntry(
      profileId: profileId ?? this.profileId,
      displayName: displayName ?? this.displayName,
      totalCoins: totalCoins ?? this.totalCoins,
      currentStreak: currentStreak ?? this.currentStreak,
      avatarColor: avatarColor ?? this.avatarColor,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatarId: avatarId ?? this.avatarId,
      rank: rank ?? this.rank,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
    );
  }
}

/// How the leaderboard is ranked. The kid can flip between these.
enum LeaderboardSortMode { coins, streak }

/// Sorted leaderboard payload for the UI.
class LeaderboardResult {
  const LeaderboardResult({
    required this.entries,
    this.currentUserEntry,
  });

  final List<LeaderboardEntry> entries;
  final LeaderboardEntry? currentUserEntry;
}
