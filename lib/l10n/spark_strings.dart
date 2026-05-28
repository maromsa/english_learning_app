import 'dart:math';

/// All child-facing Hebrew copy in the app.
///
/// Tone rules: 1st person plural inclusive ("בואו ננסה!"),
/// never "שגיאה", pair every problem with an action,
/// max 8 words per error string.
///
/// A non-engineer (teacher/parent) should be able to review
/// and edit every string in this file without touching code.
class SparkStrings {
  SparkStrings._();
  static final _rand = Random();

  // ─── Mic & speech recognition ─────────────────
  static const String micPrompt = 'בואו נדבר! לחצו על המיקרופון 🎤';
  static const String micSpeakBtn = 'דבר';
  static const String micListening = 'אני מקשיבה...';
  static const String micRetry = 'אופס, לא שמעתי. ננסה שוב?';
  static const String micTooQuiet = 'קצת יותר חזק? אני כאן 💛';
  static const String micPermissionAsk =
      'צריך הרשאת מיקרופון כדי לדבר איתי';
  static const String micChecking = 'רגע, בודקת מה שמעתם...';
  static const String micHeardNothing = 'לא שמעתי. בואו נדבר שוב?';
  static const String micStartFailed = 'אופס, לא הצלחתי. ננסה שוב?';

  /// Semantics for [SparkOrb] (assistive tech only).
  static const String orbSemanticsIdle = 'מיקרופון — לחצו לדבר';
  static const String orbSemanticsSuccess = 'כל הכבוד!';

  // ─── TTS / audio playback ─────────────────────
  static const String ttsError = 'הקול נחבא 🙈 נלחץ שוב על המילה?';

  // ─── Loading / thinking states ────────────────
  static const String thinking = 'רגע, אני חושבת... ✨';
  static const String imageAnalyzing = 'מסתכלת על התמונה...';
  static const String generatingQuiz = 'מכינה לכם משחק חדש 🎲';

  // ─── Network / Gemini failures ────────────────
  static const String offline = 'אין אינטרנט כרגע. ננסה עוד רגע?';
  static const String aiTimeout = 'לקח לי קצת. בואו ננסה שוב?';
  static const String aiUnavailable =
      'אני קצת עייפה עכשיו. נחזור עוד מעט?';

  // ─── Wrong-answer ladder (3 strikes, soft) ────
  static const String wrong1 = 'כמעט! ננסה עוד פעם?';
  static const String wrong2 = 'בואו נשמע איך זה נשמע באנגלית 👂';
  static const String wrong3 =
      'נמשיך הלאה — נחזור למילה הזאת אחר כך 💛';

  /// When fuzzy match hears something close (home pronunciation).
  static String wrongAlmostHeard(String heard) =>
      'כמעט! שמעתי $heard. עוד פעם?';

  // ─── Compliments (Celebration + home) ─────────
  static const List<String> compliments = <String>[
    'מעולה!',
    'וואו!',
    'אלוף!',
    'מדהים!',
    'כל הכבוד!',
    'נהדר!',
    'מצוין!',
    'פנטסטי!',
    'ענק!',
    'שיחקת אותה!',
  ];

  static String randomCompliment() =>
      compliments[_rand.nextInt(compliments.length)];

  // ─── Camera / photo identify ──────────────────
  static const String cameraUnclearUi = 'לא רואה ברור. בואו נצלם שוב?';
  static const String cameraUnclearSpeak =
      'לא ראיתי ברור. בואו ננסה שוב!';
  static String cameraCenterWord(String word) =>
      'שימו את $word במרכז וצלמו שוב?';
  static String cameraFoundWord(String word) => 'וואו! רואה $word. בואו נלמד!';
  static String cameraSpeakFound(String word) => 'מצוין! רואה $word.';
  static const String cameraGenericFail = 'אופס! בואו ננסה שוב?';

  // ─── Camera mission screen ────────────────────
  static String cameraShootTarget(String word) => 'צלמו: $word';
  static const String cameraValidating = 'בודקת את התמונה...';
  static String cameraSuccessBadge(String word) => 'מצוין! זיהינו $word ✅';
  static String cameraTryAgainTarget(String word) =>
      'עוד לא $word. בואו נצלם שוב?';

  // ─── Scavenger hunt (Living-World camera) ─────
  static const String scavengerTitle = 'מצאדון עם ספרק';
  static const String scavengerLoading = 'מכינים את המצלמה...';
  static const String scavengerRoundLabel = 'אתגר';
  static const String scavengerValidating = 'ספרק בודקת...';
  static const String scavengerNetworkFail =
      'לא הצלחנו לבדוק עכשיו. ננסה שוב?';
  static const String scavengerSessionComplete =
      'סיימתם את כל האתגרים! אתם גיבורי מצלמה! 🏆';
  static const String scavengerNextRound = 'אתגר הבא!';
  static const String scavengerTapToCapture = 'לחצו לצילום';
  static const String scavengerUsePicker = 'בחרו תמונה מהמצלמה';

  static String scavengerSparkIntro(String prompt) =>
      'היי! $prompt צלמו ותראו לי!';

  static String scavengerSuccess(String emoji) =>
      '${randomCompliment()} מצאתם $emoji';

  static String scavengerTryAgain(String promptHebrew) =>
      'עוד לא... $promptHebrew נסו שוב!';

  static const String scavengerTeachingTitle = 'ספרק מלמדת! 📸';
  static const String scavengerTeachingLoading =
      'ספרק מסתכלת על התמונה שלכם...';
  static const String scavengerTeachingTipsLabel = 'טיפים מספרק:';
  static const String scavengerTeachingObjectsLabel = 'עוד מילים בתמונה:';
  static const String scavengerTeachingContinue = 'לאתגר הבא!';
  static const String scavengerTeachingFinish = 'סיום המצאדון';
  static const String scavengerTeachingSkipHint =
      'אפשר להמשיך — נלמד שוב בפעם הבאה!';
  static const String scavengerTeachingSkipWhileLoading = 'המשיכו בינתיים';

  static String scavengerTeachingFallback(String emoji, String promptHebrew) =>
      '${randomCompliment()} מצאתם $emoji — $promptHebrew';

  // ─── Map / load ───────────────────────────────
  static const String mapLoading3d = 'טוענת את העולם... ✨';
  static const String mapLoadFailed = 'לא הצלחנו לטעון. ננסה שוב?';
  static const String mapNoLevels = 'אין שלבים עכשיו. נחזור עוד רגע?';
  static String levelUnlockNeed(String prev, String next, int remaining) =>
      'נסיים $prev — עוד $remaining מילים ל$next';
  static String levelUnlockNeedShort(String prev, String next) =>
      'נסיים $prev כדי לפתוח $next';

  // ─── Quiz / lightning ─────────────────────────
  static const String quizLoadFailed = 'לא הצלחנו לטעון. ננסה שוב?';
  static const String quizNeedMoreWords = 'צריך עוד מילים כדי לשחק!';
  static String quizCorrectCoins(String compliment, int coins) =>
      '$compliment +$coins מטבעות';
  static String quizWrongAnswer(String w) => 'כמעט! התשובה: $w';
  static const String quizRemovedWrong = 'הסרתי תשובה אחת 😉';
  static const String quizNextQuestion = 'שאלה הבאה';
  static const String quizPickAnswer = 'בחרו תמונה כדי להמשיך';
  static const String lightningLoadFailed = 'לא הצלחנו לטעון. ננסה שוב?';
  static String lightningWinCoins(int n) => 'מעולה! +$n מטבעות ⚡';
  static String lightningWrong(String w) => 'כמעט! התשובה: $w';
  static const String lightningNeedWords = 'צריך עוד מילים לריצת ברק!';
  static const String lightningTimeUp = 'נגמר הזמן! בואו נסכם?';

  // ─── Home / missions UI ───────────────────────
  static const String homeNeedWordsLightning =
      'צריך שתי מילים לפחות לריצת ברק!';
  static const String homeNoWordsYet = 'אין מילים עדיין. בואו נצלם אחת!';
  static const String dailyMissionTitle = 'משימה יומית';
  static String dailyMissionRemaining(int n) => 'עוד $n וננצח!';
  static const String dailyMissionKeepGoing = 'ממשיכים יפה!';

  // ─── Shop ─────────────────────────────────────
  static const String shopNotEnoughCoins = 'אופס! אין מספיק מטבעות 🪙';

  // ─── Level / chapter ──────────────────────────
  static const String levelLocked = 'נסיים את הקודם קודם 🔒';
  static const String levelUnlocked = 'שלב חדש פתוח! 🎉';
  static const String chapterDone = 'סיימנו פרק! מטורף 🏆';
  static const String levelCompleteTitle = 'כל הכבוד!';
  static String levelCompleteNamed(String name) => 'סיימנו את $name!';
  static const String levelCompleteMap = 'חזרה למפה';
  static const String levelPlayAgain = 'נשחק שוב';

  // ─── Onboarding ───────────────────────────────
  static const String welcomeTitle = 'ברוכים הבאים למסע המילים!';
  static const String welcomeBody =
      'יש לנו טיפים קטנים ללמוד באנגלית בקצב שלכם.';
  static const String welcomeGo = 'קדימה!';

  // ─── AI conversation (child errors) ─────────
  static const String aiChatRetry = 'אופס! בואו ננסה שוב?';
  static const String aiChatStartFirst = 'בואו נפתח שיחה עם ספרק קודם';
  static const String aiChatStuck = 'ספרק נתקעה. ננסה שוב?';
  static const String aiChatCantHear = 'לא שמעתי. נדבר או נכתוב?';

  // ─── Widgets ──────────────────────────────────
  static String welcomeBackUser(String name) => 'היי $name, כיף שחזרת!';
  static const String achievementNew = 'הישג חדש! 🎉';
  static String wordsProgress(int done, int total) => '$done מתוך $total מילים';

  // ─── Generic button labels ────────────────────
  static const String tryAgain = 'ננסה שוב';
  static const String continueBtn = 'נמשיך!';
  static const String letsStart = 'נתחיל ללמוד!';
  static const String skipForNow = 'נדלג בינתיים';
  static const String backToMap = 'חזרה למפה';
  static const String backToJourney = 'חזרה למסע';

  // ─── Parent / teacher area ────────────────────
  static const String parentsAreaButton = 'אזור הורים';
  static const String parentsAreaSubtitle = 'לוח בקרה להורים ומורים';

  static const String parentGateTitle = 'אזור מבוגרים';
  static String parentGateQuestion(int a, int b) => 'מה התשובה ל-$a × $b?';
  static const String parentGateAnswerLabel = 'תשובה';
  static const String parentGateWrong = 'לא נכון. ננסה שוב?';
  static const String parentGateCancel = 'ביטול';
  static const String parentGateContinue = 'המשך';

  static const String parentDashboardTitle = 'לוח בקרה להורים';
  static const String parentDashboardNoUser = 'אין משתמש פעיל';
  static const String parentDashboardDefaultChild = 'הלומד/ת';
  static const String parentDashboardOverview = 'סיכום מהיר';
  static const String parentDashboardProgress = 'התקדמות';
  static const String parentDashboardTotalStars = 'כוכבים';
  static const String parentDashboardDailyStreak = 'רצף יומי';
  static const String parentDashboardWordsPracticed = 'מילים שתרגלו';
  static const String parentDashboardCoins = 'מטבעות';
  static const String parentDashboardAchievements = 'הישגים';
  static const String parentDashboardLevelsDone = 'שלבים שהושלמו';
  static const String parentDashboardWordsLabel = 'מילים באנגלית';
  static String parentDashboardWordsSubtitle(int done, int total) =>
      '$done מתוך $total במסלול';
  static String parentDashboardMastered(int count) => '$count בשליטה מלאה';
  static const String parentDashboardLevelsLabel = 'שלבים במפה';
  static String parentDashboardLevelsSubtitle(int done, int total) =>
      '$done מתוך $total שלבים';
  static const String parentDashboardMissionsLabel = 'משימות היום';
  static String parentDashboardMissionsSubtitle(int done, int total) =>
      '$done מתוך $total הושלמו';
  static const String parentDashboardLastPlayedUnknown = 'עדיין לא שיחקו הפעם';
  static String parentDashboardLastPlayed(String when) => 'שיחקו לאחרונה: $when';
  static const String parentDashboardNote =
      'הנתונים נשמרים במכשיר זה. ברצף יומי — לכל המשפחה במכשיר משותף.';

  // ─── Offline practice packs (parent) ──────────
  static const String offlineDownloadsTitle = 'הורדה לאופליין';
  static const String offlineDownloadsDescription =
      'חבילות תרגול לטיסות ונסיעות — מילים, תמונות וקול';
  static const String offlineDownloadsButton = 'הורידו את כל התוכן הפתוח';
  static const String offlineDownloadsHint =
      'עדיין לא הורדתם חבילה. מומלץ לפני נסיעה';
  static const String offlineDownloadsDownloading = 'מורידים תוכן...';
  static const String offlineDownloadsComplete = 'מוכן לתרגול בלי אינטרנט';
  static const String offlineDownloadsFailed = 'ההורדה נכשלה';
  static String offlineDownloadsLastDownload(String when, int levels) =>
      'עודכן $when · $levels שלבים';
  static String offlineDownloadsProgress(int done, int total) =>
      '$done מתוך $total פריטים';
}
