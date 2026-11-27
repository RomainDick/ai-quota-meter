#!/bin/sh
set -e
cd "$(dirname "$0")/.."
app="build/AIUsageBar.app"
dmg="build/AIUsageBar.dmg"
if [ ! -d "$app" ]; then
    echo "Lance d'abord scripts/package.sh" >&2
    exit 1
fi
staging="build/dmg"
rm -rf "$staging" "$dmg"
mkdir -p "$staging"
ditto "$app" "$staging/AIUsageBar.app"
ln -s /Applications "$staging/Applications"
hdiutil create -volname "AI Usage Bar" -srcfolder "$staging" -ov -format UDZO "$dmg" >/dev/null
rm -rf "$staging"
echo "$dmg"
