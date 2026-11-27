#!/bin/sh
set -e
cd "$(dirname "$0")/.."
VERSION="$1"
if ! echo "$VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "Usage : scripts/release.sh X.Y.Z" >&2
    exit 1
fi
if [ -n "$(git status --porcelain)" ]; then
    echo "Le dépôt contient des modifications non commitées." >&2
    exit 1
fi
if git rev-parse "v$VERSION" >/dev/null 2>&1; then
    echo "Le tag v$VERSION existe déjà." >&2
    exit 1
fi
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" Resources/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" Resources/Info.plist
git add Resources/Info.plist
git commit -m "chore: release v$VERSION"
git tag -a "v$VERSION" -m "v$VERSION"
git push origin HEAD "v$VERSION"
echo "Tag v$VERSION poussé : la release est construite par GitHub Actions."
