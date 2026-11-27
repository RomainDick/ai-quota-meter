#!/bin/sh
set -e
cd "$(dirname "$0")/.."
app="build/AIQuotaMeter.app"
if [ "$UNIVERSAL" = "1" ]; then
    swift build -c release --triple arm64-apple-macosx13.0
    swift build -c release --triple x86_64-apple-macosx13.0
    mkdir -p .build/universal
    lipo -create -output .build/universal/AIQuotaMeter \
        .build/arm64-apple-macosx/release/AIQuotaMeter \
        .build/x86_64-apple-macosx/release/AIQuotaMeter
    binary=".build/universal/AIQuotaMeter"
else
    swift build -c release
    binary=".build/release/AIQuotaMeter"
fi
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary" "$app/Contents/MacOS/AIQuotaMeter"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
if [ -n "$VERSION" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$app/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$app/Contents/Info.plist"
fi
codesign --force --sign - "$app"
echo "$app"
