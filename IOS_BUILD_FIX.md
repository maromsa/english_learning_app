# iOS Build Fix Guide

## Quick Fix (5 minutes)

Run the automated fix script:

```bash
./fix_ios.sh
```

Then follow the steps printed at the end.

## Manual Fix Steps

If you prefer to do it manually:

### 1. Deep Clean

```bash
# Go to project root
cd /Users/maromsabag/IdeaProjects/english_app_final

# Clean Flutter build artifacts
flutter clean

# Go to iOS directory
cd ios

# Remove CocoaPods files
rm -rf Pods
rm -rf Podfile.lock
rm -rf Runner.xcworkspace

# Optional: Clear CocoaPods cache
pod cache clean --all

# Re-download Flutter dependencies
cd ..
flutter pub get

# Re-install Pods
cd ios
pod install --repo-update
```

### 2. Xcode Configuration

**Important**: Open `ios/Runner.xcworkspace` (NOT `.xcodeproj`) in Xcode.

1. In Xcode, click the blue **Runner** project icon
2. Select the **Runner** target (not the project)
3. Go to **Build Settings** tab
4. Search for **"User Script Sandboxing"**
5. Set **ENABLE_USER_SCRIPT_SANDBOXING** to **No**

**Why**: Flutter build scripts need to modify files outside the strict sandbox.

### 3. Verify xcconfig Files

1. In Xcode, click the blue **Runner** project icon
2. Select the **Project** (not Target) in the main view
3. Click the **Info** tab
4. Look at **Configurations**:
   - **Debug**: Should be set to `Pods-Runner.debug`
   - **Release**: Should be set to `Pods-Runner.release`

If these say "None", set them to the Pods files.

## Verification

### Terminal Check
```bash
flutter build ios --no-codesign
```
Expected: "Build finished successfully"

### Xcode Check
1. Open `ios/Runner.xcworkspace`
2. Select your device (or "Any iOS Device")
3. **Product > Clean Build Folder** (Shift+Cmd+K)
4. **Product > Build** (Cmd+B)

Expected: "Build Succeeded" (Yellow warnings are OK, red errors are not)

## What Was Fixed

### Podfile Updates
- ✅ Added Swift 5.0 enforcement for all dependencies
- ✅ Added `inhibit_warnings` for noisy Firebase pods
- ✅ Disabled Bitcode (deprecated)
- ✅ Fixed code signing for bundle targets

### Build Script Fixes
- ✅ Disabled User Script Sandboxing (required for Flutter)
- ✅ Regenerated Pods files (fixes XCFileList errors)
- ✅ Fixed xcconfig references

## About Warnings

Most warnings you see are from **inside the Pods** (Google/Firebase code). You cannot fix these because:
- They get overwritten on every `pod install`
- They're in third-party code
- They're safe to ignore as long as the build succeeds

The `inhibit_warnings => true` in Podfile helps silence these in build logs.

## If Build Still Fails

1. **Check Xcode version**: Should be Xcode 14+ for iOS 15.0
2. **Check CocoaPods version**: `pod --version` should be 1.11.0+
3. **Check Flutter version**: `flutter --version` should be 3.24+
4. **Clean Derived Data**: In Xcode, go to **Window > Organizer > Projects**, select your project, click **Delete Derived Data**

## Common Issues

### "No such module 'Flutter'"
- Solution: Run `flutter pub get` then `pod install`

### "Command PhaseScriptExecution failed"
- Solution: Disable User Script Sandboxing (see step 2 above)

### "Could not find included file"
- Solution: Run `pod install` again (see step 1)

### "Swift version mismatch"
- Solution: Already fixed in Podfile (Swift 5.0 enforced)

## Need Help?

If you still have issues after following these steps:
1. Check the exact error message
2. Verify you're opening `.xcworkspace` not `.xcodeproj`
3. Make sure User Script Sandboxing is disabled
4. Try a clean build: **Product > Clean Build Folder** then build again


