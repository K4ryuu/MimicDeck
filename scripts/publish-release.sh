#!/usr/bin/env bash
#
# Cuts a GitHub release for the version in Config/Version.xcconfig.
#
#   ./scripts/publish-release.sh          # asks before anything public happens
#   ./scripts/publish-release.sh --yes    # no prompt, for when you already know
#
# It builds the DMG, pulls that version's section out of CHANGELOG.md for the
# release notes, tags the commit and uploads. Refuses to run if the tag or the
# release already exists: re-releasing a version people may have downloaded
# swaps the bits under them, which is worse than cutting a new version.

set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="MimicDeck"
ASSUME_YES=0
[ "${1:-}" = "--yes" ] || [ "${1:-}" = "-y" ] && ASSUME_YES=1

fail() { echo "error: $*" >&2; exit 1; }

command -v gh > /dev/null || fail "the GitHub CLI (gh) is not installed"
gh auth status > /dev/null 2>&1 || fail "gh is not logged in, run: gh auth login"

# --- version, from the one place that defines it -----------------------------

VERSION=$(sed -n 's/^MARKETING_VERSION *= *//p' Config/Version.xcconfig | tr -d ' ')
[ -n "$VERSION" ] || fail "no MARKETING_VERSION in Config/Version.xcconfig"
TAG="v$VERSION"

# --- refuse to overwrite anything that already exists ------------------------

if git rev-parse "$TAG" > /dev/null 2>&1; then
    fail "tag $TAG already exists locally. Bump MARKETING_VERSION in Config/Version.xcconfig."
fi
if git ls-remote --exit-code --tags origin "$TAG" > /dev/null 2>&1; then
    fail "tag $TAG already exists on the remote. Bump the version."
fi
if gh release view "$TAG" > /dev/null 2>&1; then
    fail "release $TAG is already published. Bump the version."
fi

# --- the tree has to be committed, the tag points at a real commit -----------

[ -z "$(git status --porcelain)" ] || fail "working tree is dirty, commit or stash first"

BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$BRANCH" != "main" ] && [ "$ASSUME_YES" -eq 0 ]; then
    printf "You are on '%s', not main. Continue? [y/N] " "$BRANCH"
    read -r reply
    [ "$reply" = "y" ] || [ "$reply" = "Y" ] || fail "stopped"
fi

# --- release notes, lifted from the changelog --------------------------------

NOTES_FILE=$(mktemp)
trap 'rm -f "$NOTES_FILE"' EXIT

# Everything between "## [1.2.3]" and the next "## [" heading.
awk -v ver="$VERSION" '
    $0 ~ "^## \\[" ver "\\]" { grab = 1; next }
    grab && /^## \[/         { exit }
    grab                     { print }
' CHANGELOG.md | sed '/./,$!d' > "$NOTES_FILE"

[ -s "$NOTES_FILE" ] || fail "CHANGELOG.md has no section for [$VERSION]"

# --- build the installer -----------------------------------------------------

DMG="dist/$APP_NAME-$VERSION.dmg"
echo "==> Building the installer"
./scripts/build-dmg.sh > /dev/null
[ -f "$DMG" ] || fail "expected $DMG, the build did not produce it"

{
    echo
    echo "---"
    echo
    printf '`%s`  \n' "$(shasum -a 256 "$DMG" | cut -d' ' -f1)"
    echo "sha256 of $APP_NAME-$VERSION.dmg"
} >> "$NOTES_FILE"

# --- confirm, then do the public part ----------------------------------------

cat <<SUMMARY

  Release   $TAG
  Commit    $(git rev-parse --short HEAD) on $BRANCH
  Asset     $DMG ($(du -h "$DMG" | cut -f1))
  Notes     $(grep -c '' "$NOTES_FILE") lines from CHANGELOG.md

SUMMARY

if [ "$ASSUME_YES" -eq 0 ]; then
    printf "Tag, push and publish this release? [y/N] "
    read -r reply
    [ "$reply" = "y" ] || [ "$reply" = "Y" ] || fail "stopped, nothing was pushed"
fi

echo "==> Tagging $TAG"
git tag -a "$TAG" -m "$APP_NAME $VERSION"
git push origin "$TAG"

echo "==> Publishing"
gh release create "$TAG" "$DMG" \
    --title "$APP_NAME $VERSION" \
    --notes-file "$NOTES_FILE"

echo
echo "Done: $(gh release view "$TAG" --json url --jq .url)"
