# Background Music Assets

This directory should contain background music files for the application.

## Required Files

1. **app_startup.mp3** - Music that plays when the app starts
2. **map_background.mp3** - Music that plays on the main map screen

## File Format

- Format: MP3 (recommended) or other formats supported by just_audio
- Recommended: Looping-friendly tracks (the service will loop them automatically)
- Volume: Normalized audio levels (the service will control volume)

## Adding Music Files

1. Place your audio files in this directory (`assets/audio/`)
2. Ensure the files are named exactly as listed above
3. Run `flutter pub get` to refresh assets
4. The app will automatically use these files when available

## Notes

- If audio files are missing, the app will continue to function normally (errors are handled gracefully)
- Users can toggle background music on/off in Settings
- Music volume can be adjusted programmatically if needed
