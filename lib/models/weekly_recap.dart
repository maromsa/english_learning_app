import 'parent_dashboard_stats.dart';

/// A summary of a child's learning over the **last 7 calendar days**
/// (today + the six before it), shown as a card on the Parent Dashboard.
///
/// Built by `WeeklyRecapService` from on-device data only.
class WeeklyRecap {
  const WeeklyRecap({
    required this.days,
    required this.coinsEarned,
    required this.wordsMasteredThisWeek,
  });

  /// Exactly 7 entries, oldest first, one per day of the window. Days with no
  /// activity are present with zero `words` / `minutes`.
  final List<DailyActivity> days;

  /// Coins earned across the window (rewards only — spends excluded).
  final int coinsEarned;

  /// Words that are at mastery (`masteryLevel >= 1.0`) **and** were reviewed
  /// inside the window. See the service for why this is an approximation.
  final int wordsMasteredThisWeek;

  /// Number of days in the window with any practice (words or minutes).
  int get activeDays => days.where((d) => d.words > 0 || d.minutes > 0).length;

  /// Total words practised across the window.
  int get wordsPracticed => days.fold(0, (sum, d) => sum + d.words);

  /// Total practice minutes across the window.
  int get minutesPracticed => days.fold(0, (sum, d) => sum + d.minutes);

  /// The day with the most words practised, or `null` if the week was idle.
  DailyActivity? get bestDay {
    DailyActivity? best;
    for (final day in days) {
      if (day.words > 0 && (best == null || day.words > best.words)) {
        best = day;
      }
    }
    return best;
  }

  /// True when nothing happened this week — the card shows a friendly nudge.
  bool get isEmpty =>
      activeDays == 0 && coinsEarned == 0 && wordsMasteredThisWeek == 0;
}
