# הוראות להפיכת האייפון ל-Trusted Device קבוע

## דרך Xcode (הדרך המומלצת):

1. **פתח את Xcode**
   - פתח את `ios/Runner.xcworkspace` ב-Xcode

2. **חבר את האייפון דרך USB**
   - ודא שהמכשיר מחובר למחשב

3. **פתח את Devices and Simulators**
   - ב-Xcode: `Window` > `Devices and Simulators` (או `Cmd + Shift + 2`)
   - או: `Xcode` > `Settings` > `Platforms` > בחר את המכשיר

4. **הפוך את המכשיר ל-Trusted**
   - בחר את המכשיר שלך מהרשימה
   - סמן את התיבה **"Connect via network"** (אם זמין)
   - זה יאפשר חיבור גם בלי USB

5. **אשר את המפתח במכשיר (פעם אחת)**
   - על האייפון: `Settings` > `General` > `VPN & Device Management` (או `Device Management`)
   - תחת **"Developer App"** תראה את הפרופיל שלך
   - לחץ עליו ולחץ **"Trust"**
   - אשר שוב ב-**"Trust"**

6. **בנה והתקן דרך Xcode (פעם אחת)**
   - ב-Xcode: בחר את המכשיר כ-target
   - לחץ `Cmd + R` או `Product` > `Run`
   - זה ייצור את ה-provisioning profile וישמור אותו

## לאחר מכן:

- המכשיר יישאר trusted גם אחרי ניתוק USB
- לא תצטרך לאשר את הפרופיל שוב
- תוכל להתקין אפליקציות דרך Flutter או Xcode בלי אישורים נוספים

## אם עדיין יש בעיות:

1. **נקה את ה-provisioning profiles:**
   ```bash
   rm -rf ~/Library/MobileDevice/Provisioning\ Profiles/*
   ```

2. **בנה מחדש דרך Xcode:**
   - פתח את `ios/Runner.xcworkspace`
   - בחר את המכשיר כ-target
   - לחץ `Product` > `Clean Build Folder` (`Cmd + Shift + K`)
   - לחץ `Product` > `Run` (`Cmd + R`)

3. **ודא שה-Apple ID מחובר ב-Xcode:**
   - `Xcode` > `Settings` > `Accounts`
   - ודא שה-Apple ID שלך מחובר
   - לחץ על ה-Apple ID ולחץ `Download Manual Profiles`

## הערות:

- אם אתה משתמש ב-Apple Developer Account (שלם), ה-provisioning profiles נשמרים ל-7 ימים
- אם אתה משתמש ב-Free Account, ה-profiles נשמרים ל-7 ימים
- לאחר 7 ימים, תצטרך לבנות מחדש דרך Xcode

