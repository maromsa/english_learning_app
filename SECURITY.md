# Security Best Practices

## ⚠️ Important: API Keys Security

The project now loads API keys via runtime `--dart-define` values exposed through
`lib/app_config.dart`. Secrets never live in source control. Keep following best
practices below for additional protection:

### Recommended Solutions

- **Development**: provide keys on the command line (`flutter run --dart-define=...`).
- **CI/CD**: inject secure environment variables and map them to dart defines in your pipelines.
- **Production**: prefer a backend proxy or Firebase Remote Config to avoid shipping privileged keys to clients.

### Immediate Actions Required
1. ✅ Verify no real secrets remain in git history.
2. ✅ Restrict API keys in their respective provider dashboards.
3. ✅ Rotate any keys that were previously exposed.

### For Firebase Keys
Firebase keys in `firebase_options.dart` are generally safe to commit as they're meant to be public. However, ensure:
- Firebase Security Rules are properly configured
- API keys have proper restrictions set in Firebase Console
- Storage bucket permissions are restricted

