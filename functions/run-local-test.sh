#!/bin/bash

# Script to test the geminiProxy function locally
# Usage: ./run-local-test.sh [your_gemini_api_key]

set -e

echo "🧪 Testing geminiProxy Function Locally"
echo "========================================"
echo ""

# Check if API key is provided as argument or environment variable
if [ -n "$1" ]; then
  export GEMINI_API_KEY="$1"
  echo "✅ Using API key from command line argument"
elif [ -n "$GEMINI_API_KEY" ]; then
  echo "✅ Using API key from environment variable"
else
  echo "⚠️  GEMINI_API_KEY not found. Attempting to fetch from Firebase secrets..."
  
  # Try to get the secret from Firebase
  if command -v firebase &> /dev/null; then
    SECRET_KEY=$(firebase functions:secrets:access GEMINI_API_KEY 2>/dev/null || echo "")
    if [ -n "$SECRET_KEY" ]; then
      export GEMINI_API_KEY="$SECRET_KEY"
      echo "✅ Retrieved API key from Firebase secrets"
    else
      echo "❌ Could not retrieve GEMINI_API_KEY"
      echo ""
      echo "Please provide your Gemini API key in one of these ways:"
      echo "  1. As an argument: ./run-local-test.sh YOUR_API_KEY"
      echo "  2. As an environment variable: export GEMINI_API_KEY=YOUR_API_KEY"
      echo "  3. Set it in Firebase: firebase functions:secrets:set GEMINI_API_KEY"
      exit 1
    fi
  else
    echo "❌ Firebase CLI not found. Please set GEMINI_API_KEY manually."
    exit 1
  fi
fi

echo ""
echo "📍 Testing function at: http://localhost:5001/englishkidsapp-916be/us-central1/geminiProxy"
echo ""

# Wait a moment for emulator to be ready
sleep 2

# Run the test script
cd "$(dirname "$0")"
node test-local.js

