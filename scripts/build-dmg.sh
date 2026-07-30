#!/usr/bin/env bash
#
# Builds a Release MimicDeck.app and wraps it in a drag-to-install DMG.
#
#   ./scripts/build-dmg.sh
#
#   # signed, for a release anyone else can open
#   SIGN_IDENTITY="Developer ID Application: You (TEAMID)" \
#   NOTARY_PROFILE=mimicdeck ./scripts/build-dmg.sh
#
# Signing defaults to ad-hoc, which is fine on the machine that built it and
# nowhere else. A release other people can open needs a Developer ID identity
# (paid Apple Developer Program) and a notarisation pass.
#
# Set the notary profile up once with:
#
#   xcrun notarytool store-credentials mimicdeck \
#       --apple-id you@example.com \
#       --team-id TEAMID \
#       --password <app-specific-password from appleid.apple.com>
#
# Output: dist/MimicDeck-<version>.dmg

set -euo pipefail

cd "$(dirname "$0")/.."

SCHEME="MimicDeck"
APP_NAME="MimicDeck"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

# Picking an identity is not just about Gatekeeper. macOS ties Accessibility
# and Input Monitoring grants to the code signature, and an ad-hoc signature is
# only a hash of the binary, so every rebuild looks like a brand new app and
# the user has to delete the old row in System Settings and add it again. Any
# real certificate keeps the signature stable across builds, so the permission
# survives a reinstall.
#
# Preference order: Developer ID (ships to anyone), then Apple Development
# (fine on your own machines), then ad-hoc as a last resort.
if [ -z "${SIGN_IDENTITY:-}" ]; then
    SIGN_IDENTITY=$(security find-identity -v -p codesigning \
        | grep "Developer ID Application" \
        | head -1 | sed 's/.*"\(.*\)"/\1/') || true
fi
if [ -z "${SIGN_IDENTITY:-}" ]; then
    SIGN_IDENTITY=$(security find-identity -v -p codesigning \
        | grep "Apple Development" \
        | head -1 | sed 's/.*"\(.*\)"/\1/') || true
fi
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
BUILD_DIR="$(pwd)/dist/build"
STAGE_DIR="$(pwd)/dist/stage"
OUT_DIR="$(pwd)/dist"

rm -rf "$BUILD_DIR" "$STAGE_DIR"
mkdir -p "$BUILD_DIR" "$STAGE_DIR" "$OUT_DIR"

if [ "$SIGN_IDENTITY" = "-" ]; then
    echo "==> Signing: ad-hoc (no certificate found)"
else
    echo "==> Signing: $SIGN_IDENTITY"
fi

echo "==> Building Release (universal)"
# ARCHS is spelled out on purpose. With a plain -destination the build narrows
# to the host architecture and quietly ships an Apple-Silicon-only binary.
xcodebuild \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$BUILD_DIR" \
    ARCHS="arm64 x86_64" \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
    CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM="" \
    build > "$BUILD_DIR/build.log" 2>&1 || {
        echo "Build failed. Tail of the log:"
        tail -30 "$BUILD_DIR/build.log"
        exit 1
    }

APP_PATH="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"
[ -d "$APP_PATH" ] || { echo "No app at $APP_PATH"; exit 1; }

VERSION=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleShortVersionString)
DMG_PATH="$OUT_DIR/$APP_NAME-$VERSION.dmg"
# No dots or spaces. Finder refuses to address a disk called "MimicDeck
# 1.0.0" by name, and the layout step then silently does nothing.
VOLUME_NAME="$APP_NAME"
echo "==> Built $APP_NAME $VERSION"

echo "==> Staging disk image contents"
cp -R "$APP_PATH" "$STAGE_DIR/"
ln -s /Applications "$STAGE_DIR/Applications"

mkdir -p "$STAGE_DIR/.background"
swift scripts/make-dmg-background.swift "$STAGE_DIR/.background/background.png"

echo "==> Creating disk image"
TEMP_DMG="$OUT_DIR/.$APP_NAME-temp.dmg"
rm -f "$TEMP_DMG" "$DMG_PATH"
# Headroom for the volume icon and Finder's .DS_Store, which land after the
# image is sized. Without it the writes fail on a full volume.
STAGE_MB=$(du -sm "$STAGE_DIR" | cut -f1)
hdiutil create \
    -srcfolder "$STAGE_DIR" \
    -volname "$VOLUME_NAME" \
    -fs HFS+ \
    -format UDRW \
    -size "$((STAGE_MB + 30))m" \
    -ov \
    "$TEMP_DMG" > /dev/null

# An earlier copy of this volume still mounted would take the name, and the
# new image would silently land on "VolumeName 1" while we wrote to the old
# read-only one.
while [ -d "/Volumes/$VOLUME_NAME" ]; do
    hdiutil detach "/Volumes/$VOLUME_NAME" -force > /dev/null 2>&1 || break
    sleep 1
done

# Read the mount point back rather than assuming it, for the same reason.
MOUNT_DIR=$(hdiutil attach "$TEMP_DMG" -readwrite -noverify -noautoopen \
    | grep -o '/Volumes/.*$' | tail -1)
[ -d "$MOUNT_DIR" ] || { echo "Could not mount the image"; exit 1; }
VOLUME_NAME=$(basename "$MOUNT_DIR")

# Copy the icon into the live volume rather than the staging folder, so the
# custom-icon bit and the file it points at are set on the same filesystem.
cp "$APP_PATH/Contents/Resources/AppIcon.icns" "$MOUNT_DIR/.VolumeIcon.icns"
SetFile -a C "$MOUNT_DIR"

echo "==> Laying out the window"
# The mount point appears before Finder has registered the volume, and asking
# too early fails with "Can't get disk". Give it a beat, then retry.
# Keep the script itself lean: a trailing re-open plus `update without
# registering applications` makes Finder error out and nothing gets written.
layout_window() {
    osascript <<EOF
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 150, 840, 550}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set background picture of viewOptions to file ".background:background.png"
        set position of item "$APP_NAME.app" of container window to {165, 195}
        set position of item "Applications" of container window to {475, 195}
        close
    end tell
end tell
EOF
}

for attempt in 1 2 3; do
    sleep 2
    if layout_window 2>/dev/null; then break; fi
    echo "    (Finder not ready, retry $attempt)"
done

sleep 1
[ -f "$MOUNT_DIR/.DS_Store" ] \
    && echo "    Layout written" \
    || echo "    (no .DS_Store written, the window will open unstyled)"
sync
hdiutil detach "$MOUNT_DIR" > /dev/null

echo "==> Compressing"
hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" > /dev/null
rm -f "$TEMP_DMG"
rm -rf "$STAGE_DIR"

echo "==> Giving the disk image file the app's icon"
# A custom icon on a plain file lives in its resource fork, which is why this
# needs the old Rez toolchain rather than a plain copy. Note that a resource
# fork does not survive an HTTP download, so this is a local nicety: the copy
# people pull from GitHub Releases falls back to the generic disk icon.
ICON_WORK="$(mktemp -d)"
cp "$APP_PATH/Contents/Resources/AppIcon.icns" "$ICON_WORK/icon.icns"
sips -i "$ICON_WORK/icon.icns" > /dev/null 2>&1
DeRez -only icns "$ICON_WORK/icon.icns" > "$ICON_WORK/icon.rsrc" 2>/dev/null
if [ -s "$ICON_WORK/icon.rsrc" ]; then
    Rez -append "$ICON_WORK/icon.rsrc" -o "$DMG_PATH" 2>/dev/null
    SetFile -a C "$DMG_PATH"
else
    echo "    (could not read the icon resource, keeping the generic one)"
fi
rm -rf "$ICON_WORK"

if [ -n "$NOTARY_PROFILE" ] && [ "$SIGN_IDENTITY" != "-" ]; then
    echo "==> Signing the disk image"
    codesign --force --sign "$SIGN_IDENTITY" --timestamp "$DMG_PATH"

    echo "==> Submitting for notarisation (this takes a few minutes)"
    xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

    echo "==> Stapling the ticket"
    xcrun stapler staple "$DMG_PATH"
    xcrun stapler validate "$DMG_PATH"
fi

echo
echo "Done: $DMG_PATH"
du -h "$DMG_PATH" | cut -f1 | sed 's/^/Size: /'

if [ "$SIGN_IDENTITY" = "-" ]; then
    echo
    echo "Signed ad-hoc. Fine on this Mac. Anyone else has to right-click and"
    echo "choose Open the first time, because Gatekeeper will not trust it."
elif [ -z "$NOTARY_PROFILE" ]; then
    echo
    echo "Signed but not notarised. Gatekeeper still blocks it on first launch."
    echo "Set NOTARY_PROFILE to finish the job."
else
    echo
    echo "Signed, notarised and stapled. This one opens with a double click."
fi
