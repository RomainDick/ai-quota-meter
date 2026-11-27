#!/bin/sh
set -e

REPO="${AIUSAGEBAR_REPO:-RomainDick/ai-usage-bar}"
ZIP_URL="${AIUSAGEBAR_ZIP_URL:-https://github.com/$REPO/releases/latest/download/AIUsageBar.zip}"
APP_NAME="AIUsageBar.app"
DEST="$HOME/Applications"

if [ "$(uname)" != "Darwin" ]; then
    echo "AI Usage Bar ne fonctionne que sur macOS." >&2
    exit 1
fi

SCRIPT_DIR=""
if [ -f "$0" ]; then
    SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
fi

if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/Package.swift" ] && [ "$AIUSAGEBAR_FROM_RELEASE" != "1" ]; then
    if ! xcode-select -p >/dev/null 2>&1; then
        echo "Outils de développement Apple requis : lance 'xcode-select --install' puis relance ce script." >&2
        exit 1
    fi
    cd "$SCRIPT_DIR"
    ./scripts/package.sh
    SOURCE_APP="$SCRIPT_DIR/build/$APP_NAME"
else
    TMP=$(mktemp -d)
    trap 'rm -rf "$TMP"' EXIT
    echo "Téléchargement de $ZIP_URL"
    curl -fsSL "$ZIP_URL" -o "$TMP/AIUsageBar.zip"
    if curl -fsSL "$ZIP_URL.sha256" -o "$TMP/AIUsageBar.zip.sha256" 2>/dev/null; then
        (cd "$TMP" && shasum -a 256 -c AIUsageBar.zip.sha256 >/dev/null) || {
            echo "Somme de contrôle invalide, installation annulée." >&2
            exit 1
        }
    fi
    ditto -x -k "$TMP/AIUsageBar.zip" "$TMP"
    SOURCE_APP="$TMP/$APP_NAME"
fi

mkdir -p "$DEST"
pkill -x AIUsageBar 2>/dev/null || true
rm -rf "$DEST/$APP_NAME"
ditto "$SOURCE_APP" "$DEST/$APP_NAME"
xattr -dr com.apple.quarantine "$DEST/$APP_NAME" 2>/dev/null || true

"$DEST/$APP_NAME/Contents/MacOS/AIUsageBar" --install-hook
open "$DEST/$APP_NAME"
echo "AI Usage Bar installée dans $DEST/$APP_NAME et lancée."
echo "Relance une session Claude Code pour activer la lecture du quota."
