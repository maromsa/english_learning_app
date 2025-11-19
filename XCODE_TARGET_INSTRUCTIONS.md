# איך לבחור את המכשיר ב-Xcode

## שלב 1: בחירת המכשיר (Device/Target)

בחלק העליון של Xcode, יש לך כמה אפשרויות:

### אופציה A: Toolbar בחלק העליון
1. **מצא את ה-scheme selector** - זה בחלק העליון של Xcode, ליד הכפתור הירוק (Run)
2. תראה משהו כמו: `Runner > iPhone 15 Pro` או `Runner > Marom's iPhone`
3. לחץ על זה ותראה רשימה של מכשירים
4. בחר את האייפון שלך מהרשימה

### אופציה B: Product > Destination
1. לחץ על `Product` בתפריט העליון
2. לחץ על `Destination`
3. בחר את המכשיר שלך מהרשימה

### אופציה C: אם המכשיר לא מופיע
1. חבר את האייפון דרך USB
2. על האייפון: לחץ "Trust This Computer" אם מופיע
3. ב-Xcode: `Window` > `Devices and Simulators` (`Cmd + Shift + 2`)
4. ודא שהמכשיר מופיע ברשימה
5. אם הוא מופיע כ-"Unpaired", לחץ עליו כדי לזווג

## שלב 2: הרצת האפליקציה

לאחר שבחרת את המכשיר:
1. לחץ על הכפתור הירוק `▶` (Run) בפינה השמאלית העליונה
2. או לחץ `Cmd + R`
3. Xcode יבנה ויתקין את האפליקציה על המכשיר

## אם עדיין לא רואה את המכשיר:

1. ודא שהמכשיר מחובר דרך USB
2. ודא שהמכשיר לא נעול (unlock)
3. על האייפון: Settings > General > VPN & Device Management > Trust את המחשב
4. ב-Xcode: `Window` > `Devices and Simulators` - ודא שהמכשיר מופיע
