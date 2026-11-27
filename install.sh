#!/bin/sh
set -e

REPO="${AIQUOTAMETER_REPO:-RomainDick/ai-quota-meter}"
ZIP_URL="${AIQUOTAMETER_ZIP_URL:-https://github.com/$REPO/releases/latest/download/AIQuotaMeter.zip}"
APP_NAME="AIQuotaMeter.app"
DEST="$HOME/Applications"

if [ "$(uname)" != "Darwin" ]; then
    echo "AI Quota Meter ne fonctionne que sur macOS." >&2
    exit 1
fi

SCRIPT_DIR=""
if [ -f "$0" ]; then
    SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
fi

if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/Package.swift" ] && [ "$AIQUOTAMETER_FROM_RELEASE" != "1" ]; then
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
    curl -fsSL "$ZIP_URL" -o "$TMP/AIQuotaMeter.zip"
    if curl -fsSL "$ZIP_URL.sha256" -o "$TMP/AIQuotaMeter.zip.sha256" 2>/dev/null; then
        (cd "$TMP" && shasum -a 256 -c AIQuotaMeter.zip.sha256 >/dev/null) || {
            echo "Somme de contrôle invalide, installation annulée." >&2
            exit 1
        }
    fi
    ditto -x -k "$TMP/AIQuotaMeter.zip" "$TMP"
    SOURCE_APP="$TMP/$APP_NAME"
fi

mkdir -p "$DEST"
pkill -x AIQuotaMeter 2>/dev/null || true
pkill -x AIUsageBar 2>/dev/null || true
rm -rf "$DEST/AIUsageBar.app"
rm -rf "$DEST/$APP_NAME"
ditto "$SOURCE_APP" "$DEST/$APP_NAME"
xattr -dr com.apple.quarantine "$DEST/$APP_NAME" 2>/dev/null || true

"$DEST/$APP_NAME/Contents/MacOS/AIQuotaMeter" --install-hook
open "$DEST/$APP_NAME"
echo "AI Quota Meter installé dans $DEST/$APP_NAME et lancé."
echo "Relance une session Claude Code pour activer la lecture du quota."
