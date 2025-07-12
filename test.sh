#!/bin/bash

set -e  # עצור אם יש שגיאה
set -o pipefail

echo "🚿 Cleaning Flutter project and caches..."

flutter clean
rm -rf .dart_tool build pubspec.lock
rm -rf ~/.pub-cache

echo "📦 Running flutter pub get..."
flutter pub get

echo "🩺 Running flutter doctor..."
flutter doctor -v

echo "🚀 Running upload_words.dart with Flutter..."
flutter pub run scripts/upload_words.dart

echo "✅ Done. Script finished successfully."

