#!/bin/sh
set -e
APP="$HOME/Applications/AIQuotaMeter.app"
if [ -x "$APP/Contents/MacOS/AIQuotaMeter" ]; then
    "$APP/Contents/MacOS/AIQuotaMeter" --uninstall-hook
fi
pkill -x AIQuotaMeter 2>/dev/null || true
pkill -x AIUsageBar 2>/dev/null || true
rm -rf "$APP" "$HOME/Applications/AIUsageBar.app" "$HOME/Library/Application Support/ai-usage-bar"
echo "AI Quota Meter désinstallé."
