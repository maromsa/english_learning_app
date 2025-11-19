# ניהול נתוני משתמשים בענן

## סקירה כללית

המערכת מאפשרת שמירת כל נתוני השחקן בענן (Firebase Firestore) עם סנכרון אוטומטי בין המכשיר המקומי לענן.

## מבנה הנתונים

### PlayerData Model
מודל מרכזי המכיל את כל נתוני השחקן:
- **coins**: מספר המטבעות
- **purchasedItems**: רשימת פריטים שנרכשו
- **achievements**: מפת הישגים (achievementId -> isUnlocked)
- **levelProgress**: התקדמות ברמות (levelId -> LevelProgress)
- **dailyStreak**: רצף יומי
- **lastDailyRewardClaim**: תאריך תביעת מתנה אחרונה
- **totalWordsCompleted**: סך המילים שהושלמו
- **totalQuizzesPlayed**: סך הקוויזים ששוחקו
- **bestQuizStreak**: הרצף הטוב ביותר בקוויז

### LevelProgress
נתוני התקדמות ברמה ספציפית:
- **stars**: מספר כוכבים
- **isUnlocked**: האם הרמה פתוחה
- **wordsCompleted**: מפת מילים שהושלמו (word -> isCompleted)
- **lastPlayedAt**: תאריך משחק אחרון

## מבנה Firestore

```
users/
  {userId}/
    gameData/
      player/
        coins: number
        purchasedItems: string[]
        achievements: {achievementId: boolean}
        levelProgress: {
          {levelId}: {
            stars: number
            isUnlocked: boolean
            wordsCompleted: {word: boolean}
            lastPlayedAt: timestamp
          }
        }
        dailyStreak: number
        lastDailyRewardClaim: timestamp
        totalWordsCompleted: number
        totalQuizzesPlayed: number
        bestQuizStreak: number
        createdAt: timestamp
        updatedAt: timestamp
```

## שירותים

### UserDataService
שירות לניהול נתוני שחקן ב-Firestore:
- `loadPlayerData(userId)`: טעינת נתונים מהענן
- `savePlayerData(playerData)`: שמירת נתונים לענן
- `updatePlayerData(userId, updates)`: עדכון חלקי
- `updateCoins(userId, coins)`: עדכון מטבעות
- `addPurchasedItem(userId, itemId)`: הוספת פריט שנרכש
- `unlockAchievement(userId, achievementId)`: פתיחת הישג
- `updateLevelProgress(userId, levelId, progress)`: עדכון התקדמות רמה
- `updateDailyStreak(userId, streak, lastClaim)`: עדכון רצף יומי
- `incrementStat(userId, statName, amount)`: הגדלת סטטיסטיקה
- `syncWithCloud(userId, localData)`: סנכרון עם אסטרטגיית מיזוג

### PlayerDataSyncService
שירות לסנכרון נתונים בין מקומי לענן:
- `syncFromCloud(userId, ...)`: טעינת נתונים מהענן והחלתם על ה-providers המקומיים
- `syncToCloud(userId, ...)`: שליחת נתונים מקומיים לענן
- `_createInitialPlayerData(...)`: יצירת נתונים ראשוניים בענן

## Providers מעודכנים

### CoinProvider
- שמירה כפולה: מקומי (SharedPreferences) + ענן
- `setUserId(userId)`: הגדרת ID משתמש לסנכרון
- כל שינוי במטבעות נשמר אוטומטית בענן

### ShopProvider
- שמירה כפולה: מקומי + ענן
- `setUserId(userId)`: הגדרת ID משתמש
- רכישות נשמרות אוטומטית בענן

### AchievementService
- שמירה כפולה: מקומי + ענן
- `setUserId(userId)`: הגדרת ID משתמש
- פתיחת הישגים נשמרת אוטומטית בענן

## זרימת עבודה

### התחברות משתמש
1. משתמש מתחבר דרך `AuthProvider`
2. `AuthGate` מזהה התחברות
3. `PlayerDataSyncService.syncFromCloud()` נקרא
4. נתונים נטענים מהענן
5. Providers מעודכנים עם הנתונים מהענן
6. User IDs מוגדרים ב-providers

### שמירת נתונים
1. משתמש מבצע פעולה (רכישה, הישג, וכו')
2. Provider מעדכן את הנתונים המקומיים
3. Provider שומר מקומית (SharedPreferences)
4. Provider שומר בענן (אם משתמש מחובר)

### סנכרון
- **Cloud Wins**: בעת התחברות, נתונים מהענן דורסים נתונים מקומיים
- **Merge Strategy**: בעת סנכרון, לוקחים את הערך הגבוה יותר לסטטיסטיקות
- **Union**: רשימות (כמו purchasedItems) מתמזגות

## אבטחה

- כל נתוני השחקן נשמרים תחת `users/{userId}/gameData/player`
- Firestore Security Rules צריכות להבטיח:
  - משתמש יכול לקרוא/לכתוב רק את הנתונים שלו
  - אין גישה לנתונים של משתמשים אחרים

### דוגמה ל-Security Rules:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/gameData/player {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## שימוש

### הגדרת User ID ב-Providers
```dart
final userId = authProvider.firebaseUser!.uid;
coinProvider.setUserId(userId);
shopProvider.setUserId(userId);
achievementService.setUserId(userId);
```

### סנכרון ידני
```dart
final syncService = PlayerDataSyncService();
await syncService.syncFromCloud(
  userId,
  coinProvider: coinProvider,
  shopProvider: shopProvider,
  achievementService: achievementService,
);
```

### עדכון נתונים בענן
```dart
final userDataService = UserDataService();
await userDataService.updateCoins(userId, 100);
await userDataService.addPurchasedItem(userId, 'magic_hat');
await userDataService.unlockAchievement(userId, 'first_correct');
```

## הערות חשובות

1. **Offline Support**: Firestore תומך בעבודה offline - שינויים יסונכרנו אוטומטית כשהחיבור יחזור
2. **Error Handling**: כל הפעולות כוללות error handling - שגיאות לא יקריסו את האפליקציה
3. **Performance**: שמירה בענן נעשית ברקע ולא חוסמת את ה-UI
4. **Backward Compatibility**: נתונים מקומיים נשמרים גם כן - האפליקציה תעבוד גם ללא חיבור

## העתיד

ניתן להוסיף:
- שמירת התקדמות ברמות (levelProgress)
- שמירת סטטיסטיקות נוספות
- היסטוריית פעולות
- גיבויים אוטומטיים
- סנכרון בין מכשירים מרובים

