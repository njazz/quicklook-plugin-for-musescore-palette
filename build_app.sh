#!/usr/bin/env bash
# Build the host app MpalFilePreview.app (Quick Look extension embedded in Contents/PlugIns)
# and zip it into dist/ for distribution, e.g. as a GitHub release asset.
#
#   ./build_app.sh                 native architecture
#   UNIVERSAL=1 ./build_app.sh     arm64 + x86_64 (needs full Xcode, not just Command Line Tools)
#
# Env overrides:
#   SIGN_ID="Developer ID Application: …"   signing identity (default "-" = ad-hoc)
#   BUNDLE_ID=com.yourdomain.mpal-preview   app bundle ID (default local.mpal-file-preview);
#                                           the extension gets "$BUNDLE_ID.quicklook"
#   VERSION=1.2.0                           CFBundleShortVersionString/CFBundleVersion (default 1.0)
#
# Output: dist/MpalFilePreview.zip  (unzips to MpalFilePreview.app)
set -euo pipefail
cd "$(dirname "$0")"

APP=MpalFilePreview
EXT=MpalFilePreviewExtension
BUNDLE_ID="${BUNDLE_ID:-local.mpal-file-preview}"
EXT_ID="$BUNDLE_ID.quicklook"
SIGN_ID="${SIGN_ID:--}"
VERSION="${VERSION:-1.0}"
ZIP="dist/$APP.zip"

[[ "$(uname)" == Darwin ]] || { echo "This script runs on macOS only." >&2; exit 1; }

# Note: ${arr[@]+"${arr[@]}"} keeps empty arrays safe under `set -u` in macOS's bash 3.2.
ARCH=()
if [[ "${UNIVERSAL:-0}" == 1 ]]; then ARCH=(--arch arm64 --arch x86_64); fi

echo "==> Building (release, ${ARCH[*]:-native arch})"
swift build -c release ${ARCH[@]+"${ARCH[@]}"}
BIN="$(swift build -c release ${ARCH[@]+"${ARCH[@]}"} --show-bin-path)"

echo "==> Assembling $APP.app ($BUNDLE_ID, $VERSION)"
# Assemble in a temp dir so Spotlight/LaunchServices never register a stray copy in the repo.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
OUT="$WORK/$APP.app"
APPEX="$OUT/Contents/PlugIns/$EXT.appex"
mkdir -p "$OUT/Contents/MacOS" "$APPEX/Contents/MacOS"
cp "$BIN/$APP" "$OUT/Contents/MacOS/$APP"
cp "$BIN/$EXT" "$APPEX/Contents/MacOS/$EXT"
cp Bundle/App-Info.plist "$OUT/Contents/Info.plist"
cp Bundle/Extension-Info.plist "$APPEX/Contents/Info.plist"
for pl in "$OUT/Contents/Info.plist" "$APPEX/Contents/Info.plist"; do
  plutil -replace CFBundleShortVersionString -string "$VERSION" "$pl"
  plutil -replace CFBundleVersion -string "$VERSION" "$pl"
done
plutil -replace CFBundleIdentifier -string "$BUNDLE_ID" "$OUT/Contents/Info.plist"
plutil -replace CFBundleIdentifier -string "$EXT_ID" "$APPEX/Contents/Info.plist"
plutil -lint -s "$OUT/Contents/Info.plist" "$APPEX/Contents/Info.plist"

echo "==> Signing (identity: $SIGN_ID)"
# With a real certificate, also enable hardened runtime + timestamp (needed for notarization).
SIGN_OPTS=()
if [[ "$SIGN_ID" != "-" ]]; then SIGN_OPTS=(--options runtime --timestamp); fi
# Sign inside-out: the extension first (sandboxed), then the host app.
codesign --force --sign "$SIGN_ID" ${SIGN_OPTS[@]+"${SIGN_OPTS[@]}"} \
  --entitlements Bundle/Extension.entitlements "$APPEX"
codesign --force --sign "$SIGN_ID" ${SIGN_OPTS[@]+"${SIGN_OPTS[@]}"} "$OUT"
codesign --verify --deep --strict "$OUT"

echo "==> Packaging $ZIP"
mkdir -p dist
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$OUT" "$ZIP"
echo "Built $ZIP  ($APP.app $VERSION, $(lipo -archs "$OUT/Contents/MacOS/$APP"))"
