# Background Music Assets

This folder contains background music files for the English Learning App.

## Required Music Files

To enable background music, please add the following MP3 files to this directory:

1. **map_theme.mp3** - Fun, upbeat music for the main map screen (suitable for kids)
2. **startup_theme.mp3** - Welcoming, cheerful music for app startup
3. **level_theme.mp3** - Energetic music for level gameplay (optional)

## Music Requirements

- **Format**: MP3 (recommended) or other formats supported by just_audio package
- **Duration**: 1-3 minutes (will loop automatically)
- **Style**: Kid-friendly, upbeat, educational atmosphere
- **Volume**: Music will be automatically set to 30% volume to not overpower speech

## Finding Royalty-Free Kids Music

You can find suitable royalty-free music from:
- [YouTube Audio Library](https://www.youtube.com/audiolibrary/music) - Filter by "Children" genre
- [Free Music Archive](https://freemusicarchive.org/) - Kids/Educational category
- [Incompetech](https://incompetech.com/) - Kevin MacLeod's royalty-free music
- [Bensound](https://www.bensound.com/) - "Funny" and "Happy" categories

## Temporary Solution

If you don't have music files yet, the app will:
- Continue to work normally without music
- Show a music control button that will be enabled once files are added
- Fall back gracefully with debug messages in the console

## Adding Your Music

1. Download or create your music files
2. Rename them to match the names above (or update the constants in `background_music_service.dart`)
3. Place them in this `assets/music/` folder
4. The app will automatically detect and play them

Enjoy! 🎵
