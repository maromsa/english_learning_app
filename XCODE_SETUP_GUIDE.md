# Xcode Setup Guide - Finding Runner Project

## ✅ Good News!

The `ENABLE_USER_SCRIPT_SANDBOXING` setting is **already configured** in your project file! It's set to `NO` for all build configurations (Debug, Release, Profile).

## How to Open the Project Correctly

### Step 1: Open the Workspace (NOT the Project)

**Important**: You must open `.xcworkspace`, not `.xcodeproj`

```bash
# From terminal:
open ios/Runner.xcworkspace

# OR double-click this file in Finder:
ios/Runner.xcworkspace
```

### Step 2: Finding the Runner Project in Xcode

Once Xcode opens:

1. **Look at the left sidebar** (Project Navigator)
2. You should see a **blue icon** at the very top - this is the "Runner" project
3. Click on it once to select it
4. In the main area, you'll see:
   - **PROJECT** section (with "Runner" in it)
   - **TARGETS** section (with "Runner" and "RunnerTests")

### Step 3: Verify the Setting (Optional - Already Done!)

If you want to verify the setting is correct:

1. Click the **blue "Runner" project icon** in the left sidebar
2. In the main area, make sure **"Runner"** is selected under **PROJECT** (not TARGETS)
3. Click the **"Build Settings"** tab at the top
4. In the search box, type: `sandbox`
5. You should see `ENABLE_USER_SCRIPT_SANDBOXING` set to `NO`

**Note**: This is already configured, so you don't need to change anything!

## If You Still Can't Find It

### Option 1: Use Terminal to Open
```bash
cd /Users/maromsabag/IdeaProjects/english_app_final
open ios/Runner.xcworkspace
```

### Option 2: Check if Workspace Exists
```bash
ls -la ios/*.xcworkspace
```

If it doesn't exist, run:
```bash
cd ios
pod install
```

### Option 3: Visual Guide

When Xcode opens, the left sidebar should look like this:

```
📁 Runner (blue icon) ← This is what you're looking for!
  📁 Runner
    📁 Runner
      📄 AppDelegate.swift
      📄 Info.plist
      ...
  📁 Pods
  📁 Products
  📁 Flutter
```

## Next Steps

Since the setting is already configured, you can now:

1. **Try building**:
   - In Xcode: **Product > Build** (Cmd+B)
   - Or from terminal: `flutter build ios --no-codesign`

2. **If build fails**, check:
   - Are you opening `.xcworkspace` (not `.xcodeproj`)?
   - Did you run `pod install` after the fix script?
   - Are there any specific error messages?

## Quick Verification

Run this to verify everything is set up:

```bash
cd /Users/maromsabag/IdeaProjects/english_app_final
flutter build ios --no-codesign
```

If this succeeds, you're all set! 🎉


