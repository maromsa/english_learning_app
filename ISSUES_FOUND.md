# בעיות שנמצאו בהתקנה על iPhone

## סיכום הבעיות

### ✅ מה עובד:
1. **Flutter dependencies** - מותקנים כראוי
2. **CocoaPods** - מותקנים כראוי (20 dependencies, 52 total pods)
3. **Build** - האפליקציה נבנית בהצלחה
4. **Code Signing** - האפליקציה חתומה כראוי עם:
   - Authority: Apple Development: maromsabag@gmail.com (R86GYTF5B9)
   - Team ID: BAH9Z485D9
   - Bundle ID: com.example.englishAppFinal

### ❌ הבעיה העיקרית:
**CoreDeviceError 3002** - שגיאת התקנה על המכשיר

```
ERROR: Failed to install the app on the device. (com.apple.dt.CoreDeviceError error 3002 (0xBBA))
Connection interrupted
```

## סיבות אפשריות:

1. **Trust/Trusted Computer** - המחשב לא מאושר ב-iPhone
   - פתרון: ב-iPhone, עבור ל-Settings > General > VPN & Device Management
   - או כאשר מתחברים, לחץ "Trust This Computer"

2. **Wireless Connection Issues** - המכשיר מחובר wirelessly
   - פתרון: נסה לחבר את ה-iPhone דרך USB

3. **Xcode Permissions** - Xcode צריך הרשאות
   - פתרון: Settings > Privacy & Security > Automation > Xcode

4. **Provisioning Profile** - בעיה עם פרופיל ההתקנה
   - פתרון: פתח את Xcode ובדוק ב-Signing & Capabilities

## פתרונות מומלצים:

### פתרון 1: דרך Xcode ישירות
1. פתח את `ios/Runner.xcworkspace` ב-Xcode
2. בחר את ה-iPhone כ-target device
3. לחץ על Product > Run (⌘R)
4. אם יש בעיות signing, Xcode יבקש לתקן אותן אוטומטית

### פתרון 2: בדיקת Trust
1. נתק וחבר מחדש את ה-iPhone
2. כאשר מופיעה ההודעה "Trust This Computer?", לחץ "Trust"
3. הזן את קוד ה-iPhone אם נדרש

### פתרון 3: חיבור USB
1. חבר את ה-iPhone דרך USB במקום wireless
2. נסה שוב: `flutter run -d <device-id>`

### פתרון 4: ניקוי וניסיון מחדש
```bash
flutter clean
flutter pub get
cd ios && pod install && cd ..
flutter run -d <device-id>
```

## מידע טכני:

- **Device ID (Flutter)**: 00008140-000004AA3E29801C
- **Device ID (devicectl)**: 28BB6225-93D5-5568-84AB-F3C57D13DA14
- **Device Name**: Marom's iPhone
- **iOS Version**: 26.1 (23B85)
- **Model**: iPhone 16 Pro Max
- **Connection**: Wireless

## הצעדים הבאים:

1. ✅ Xcode נפתח - נסה להתקין דרך Xcode
2. ⏳ בדוק Trust ב-iPhone
3. ⏳ נסה חיבור USB אם wireless לא עובד
4. ⏳ בדוק הרשאות Xcode ב-System Settings

