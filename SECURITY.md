# Security Best Practices

## ⚠️ Important: API Keys Security

Currently, API keys are stored in `lib/config.dart`. This is **NOT secure** for production apps. Here are recommendations:

### Current Status
- API keys are hardcoded in `lib/config.dart`
- This file should be added to `.gitignore` if it contains real keys
- Keys are visible in the compiled app

### Recommended Solutions

#### Option 1: Use Environment Variables (Recommended for Development)
1. Install `flutter_dotenv` package:
   ```yaml
   dependencies:
     flutter_dotenv: ^5.1.0
   ```

2. Create a `.env` file in the project root:
   ```
   GEMINI_API_KEY=your_key_here
   CLOUDINARY_API_KEY=your_key_here
   CLOUDINARY_API_SECRET=your_secret_here
   GOOGLE_TTS_API_KEY=your_key_here
   ```

3. Add `.env` to `.gitignore`

4. Load in `main.dart`:
   ```dart
   await dotenv.load(fileName: ".env");
   ```

5. Access in code:
   ```dart
   final apiKey = dotenv.env['GEMINI_API_KEY']!;
   ```

#### Option 2: Use Firebase Remote Config (Recommended for Production)
- Store API keys in Firebase Remote Config
- Update keys without app updates
- Better security and control

#### Option 3: Use a Backend Server
- Create a backend API
- Store keys on the server
- App calls your backend instead of external APIs directly

### Immediate Actions Required
1. ✅ Add `lib/config.dart` to `.gitignore` if it contains sensitive keys
2. ✅ Create `lib/config.dart.example` with placeholder values
3. ✅ Rotate any keys that have been committed to git
4. ✅ Use environment variables or secure storage for production

### For Firebase Keys
Firebase keys in `firebase_options.dart` are generally safe to commit as they're meant to be public. However, ensure:
- Firebase Security Rules are properly configured
- API keys have proper restrictions set in Firebase Console
- Storage bucket permissions are restricted

