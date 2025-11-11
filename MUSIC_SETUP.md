# 🎵 Background Music Setup Guide

Background music has been successfully integrated into your English Learning App! The app now features cheerful, kid-friendly background music on:

- **App Startup** - Welcoming music when the app launches
- **Main Map Screen** - Fun, adventurous music while navigating the level map

## 🎼 What's Been Added

### 1. Background Music Service
A complete music management service (`lib/services/background_music_service.dart`) that handles:
- Playing, pausing, and stopping music
- Automatic looping
- Volume control (set to 30% to not overpower speech)
- Persistent user preferences (music on/off setting is saved)
- Smooth transitions between different tracks

### 2. Music Control Button
A music control button has been added to the map screen (top-right area):
- 🎵 **Music Note Icon** (amber) - Music is playing
- 🎵 **Music Off Icon** (grey) - Music is muted
- Tap to toggle music on/off
- Your preference is saved automatically

### 3. Automatic Music Playback
- **Startup**: Cheerful welcome music plays when the app launches
- **Map Screen**: Switches to adventurous map theme music
- Music loops continuously and seamlessly
- Works in the background

## 📁 Adding Your Music Files

To enable the background music, you need to add MP3 files to the `assets/music/` folder:

### Required Files:

1. **`map_theme.mp3`** 
   - Fun, upbeat music for the main map screen
   - Recommended: Adventure/exploration theme
   - Duration: 1-3 minutes (will loop)

2. **`startup_theme.mp3`**
   - Welcoming, cheerful music for app startup
   - Recommended: Bright, positive melody
   - Duration: 1-2 minutes (will loop)

### Where to Find Kid-Friendly Royalty-Free Music

Here are some excellent sources for free, kid-appropriate background music:

#### YouTube Audio Library (Free & High Quality)
1. Go to: https://studio.youtube.com/channel/UC/music
2. Filter by:
   - Genre: "Children" or "Happy"
   - Mood: "Bright", "Happy", "Funky"
3. Download MP3 format

#### Recommended Tracks:
- **For Map Theme**: Look for "adventure" or "playful" tracks
  - Example keywords: "kids adventure", "playful melody", "happy journey"
- **For Startup**: Look for "upbeat" or "cheerful" tracks
  - Example keywords: "happy intro", "cheerful start", "bright beginning"

#### Other Great Sources:
- **Incompetech** (incompetech.com) - Kevin MacLeod's music
  - Search: "Children" or "Happy" category
  - All music is free with attribution
  
- **Bensound** (bensound.com)
  - "Funny" and "Happy" categories perfect for kids
  - Free for non-commercial use

- **Free Music Archive** (freemusicarchive.org)
  - Filter: "Children" or "Educational"
  - High-quality, curated tracks

### Installation Steps:

1. **Download** your chosen music files (MP3 format)

2. **Rename** them:
   - Your map music → `map_theme.mp3`
   - Your startup music → `startup_theme.mp3`

3. **Place** them in: `/workspace/assets/music/`

4. **Done!** The app will automatically detect and play them

## 🎛️ Technical Details

### Music Specifications:
- **Format**: MP3 (recommended), also supports: WAV, AAC, OGG
- **Bitrate**: 128-192 kbps (good quality, reasonable file size)
- **Volume**: Automatically set to 30% to not overpower voice/effects
- **Looping**: Enabled by default
- **File Size**: Keep under 5MB per file for app performance

### How It Works:
1. The `BackgroundMusicService` is initialized at app startup
2. Music starts playing automatically (if user hasn't disabled it)
3. When navigating to the map screen, music switches to map theme
4. User preferences are saved to device storage
5. Music continues playing across screen transitions

### Fallback Behavior:
If music files are not found, the app will:
- Continue to work normally (no crashes)
- Show debug messages in console
- Display the music control button (ready for when files are added)

## 🔧 Customization Options

### To Change Music Files:
Edit the constants in `lib/services/background_music_service.dart`:

```dart
static const String mapMusic = 'assets/music/YOUR_MAP_MUSIC.mp3';
static const String startupMusic = 'assets/music/YOUR_STARTUP_MUSIC.mp3';
```

### To Adjust Volume:
In `background_music_service.dart`, find:
```dart
await _audioPlayer.setVolume(0.3); // 30% volume
```
Change `0.3` to any value between `0.0` (silent) and `1.0` (full volume)

### To Add More Tracks:
You can add music to other screens by:
1. Adding the music file to `assets/music/`
2. Playing it in the screen's `initState()`:
```dart
Provider.of<BackgroundMusicService>(context, listen: false)
  .playMusic('assets/music/your_track.mp3');
```

## 🎮 User Experience

### Music Controls:
- **Toggle On/Off**: Tap the music icon in the app bar
- **Preference Saved**: Choice persists across app restarts
- **Smooth Transitions**: Music switches seamlessly between screens
- **Non-Intrusive**: Volume is balanced to not interfere with learning

### Accessibility:
- Clear visual indicator (icon changes color/style)
- Tooltip text in Hebrew
- Easy one-tap control
- Respects user preference

## 🐛 Troubleshooting

### Music Not Playing?
1. ✅ Check that MP3 files are in `/workspace/assets/music/`
2. ✅ Verify file names match exactly (`map_theme.mp3`, `startup_theme.mp3`)
3. ✅ Check that music isn't muted (tap the music button)
4. ✅ Look for debug messages in the console

### Music Stuttering?
- Reduce file size (use lower bitrate or shorter duration)
- Ensure MP3 files are properly encoded

### Want Different Music for Each Level?
You can extend the service to support per-level music by:
1. Adding level-specific tracks to the assets folder
2. Passing the level ID to the music service
3. Playing different tracks based on level theme

## 📝 Summary

✅ Background music service created and integrated  
✅ Music plays on app startup  
✅ Map screen has dedicated music track  
✅ User can toggle music on/off  
✅ Settings persist across sessions  
✅ Volume optimized for learning environment  
✅ Ready for your music files!

**Next Step**: Add your MP3 files to `assets/music/` and enjoy! 🎉

---

For questions or issues, check the debug console for helpful messages.
