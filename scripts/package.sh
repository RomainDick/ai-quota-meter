#!/bin/sh
set -e
cd "$(dirname "$0")/.."
app="build/AIUsageBar.app"
if [ "$UNIVERSAL" = "1" ]; then
    swift build -c release --triple arm64-apple-macosx13.0
    swift build -c release --triple x86_64-apple-macosx13.0
    mkdir -p .build/universal
    lipo -create -output .build/universal/AIUsageBar \
        .build/arm64-apple-macosx/release/AIUsageBar \
        .build/x86_64-apple-macosx/release/AIUsageBar
    binary=".build/universal/AIUsageBar"
else
    swift build -c release
    binary=".build/release/AIUsageBar"
fi
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp "$binary" "$app/Contents/MacOS/AIUsageBar"
cp Resources/Info.plist "$app/Contents/Info.plist"
if [ -n "$VERSION" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$app/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$app/Contents/Info.plist"
fi
codesign --force --sign - "$app"
echo "$app"
