#!/bin/bash
# Script to help trust iOS device

echo "Opening Xcode workspace..."
open ios/Runner.xcworkspace

echo ""
echo "=========================================="
echo "הוראות להפיכת המכשיר ל-Trusted Device:"
echo "=========================================="
echo ""
echo "1. ב-Xcode: Window > Devices and Simulators (Cmd+Shift+2)"
echo "2. בחר את המכשיר שלך"
echo "3. סמן 'Connect via network' (אם זמין)"
echo "4. על האייפון: Settings > General > VPN & Device Management"
echo "5. בחר את הפרופיל שלך ולחץ 'Trust'"
echo "6. ב-Xcode: בחר את המכשיר כ-target ולחץ Cmd+R"
echo ""
echo "לאחר מכן המכשיר יישאר trusted!"
echo ""
