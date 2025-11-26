#!/bin/bash

echo "🛠️  Starting iOS Build Repair..."

# 1. Clean Flutter
echo "🧹 Cleaning Flutter..."
flutter clean

# 2. Clean iOS artifacts
echo "🗑️  Removing iOS Pods and Locks..."
cd ios
rm -rf Pods
rm -rf Podfile.lock
rm -rf .symlinks
rm -rf Flutter/Flutter.framework
rm -rf Flutter/App.framework

# 3. Re-fetch Flutter dependencies
echo "📦 Getting Flutter packages..."
cd ..
flutter pub get

# 4. Install Pods
echo "🥥 Installing CocoaPods..."
cd ios
# Note: --repo-update ensures we have latest specs for Firebase
pod install --repo-update

echo ""
echo "✅ Fix script complete."
echo ""
echo "👉 Next steps:"
echo "   1. Open 'ios/Runner.xcworkspace' in Xcode (NOT .xcodeproj)"
echo "   2. In Xcode: Runner project → Runner target → Build Settings"
echo "   3. Search for 'User Script Sandboxing'"
echo "   4. Set ENABLE_USER_SCRIPT_SANDBOXING to 'NO'"
echo "   5. Build (Cmd+B)"
echo ""


