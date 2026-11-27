#!/bin/sh
set -e
APP="$HOME/Applications/AIUsageBar.app"
if [ -x "$APP/Contents/MacOS/AIUsageBar" ]; then
    "$APP/Contents/MacOS/AIUsageBar" --uninstall-hook
fi
pkill -x AIUsageBar 2>/dev/null || true
rm -rf "$APP" "$HOME/Library/Application Support/ai-usage-bar"
echo "AI Usage Bar désinstallée."
