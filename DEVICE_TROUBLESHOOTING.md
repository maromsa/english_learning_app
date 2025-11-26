# iOS Device Troubleshooting Guide

## Problem: "Device is busy (Preparing Marom's iPhone)"

This error occurs when Xcode is trying to prepare your device but it's taking too long or stuck.

### Solutions (try in order):

1. **Unlock your iPhone** - Make sure your iPhone is unlocked and on the home screen

2. **Trust the computer** - If you see a "Trust This Computer?" prompt on your iPhone, tap "Trust" and enter your passcode

3. **Disconnect and reconnect** - Unplug your iPhone, wait 5 seconds, then plug it back in

4. **Restart Xcode** - Close Xcode completely and reopen it:
   ```bash
   killall Xcode
   open ios/Runner.xcworkspace
   ```

5. **Clean build folder** - In Xcode: Product → Clean Build Folder (Shift+Cmd+K)

6. **Restart device preparation** - In Xcode:
   - Go to Window → Devices and Simulators
   - Select your iPhone
   - Click "Use for Development" if prompted
   - Wait for "Preparing device" to complete

7. **Check device status** - Run:
   ```bash
   flutter devices
   xcrun devicectl list devices
   ```

8. **Try building without deploying** - Build the app first, then install manually:
   ```bash
   flutter build ios --release
   # Then install via Xcode or manually
   ```

9. **Use Xcode directly** - Open the workspace and build/run from Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```
   Then in Xcode: Product → Destination → Select your iPhone → Run

10. **Restart your iPhone** - Sometimes a simple restart fixes device preparation issues

### If nothing works:

- Try a different USB cable
- Try a different USB port
- Restart your Mac
- Check if other apps (like iTunes, Finder) are accessing the device


