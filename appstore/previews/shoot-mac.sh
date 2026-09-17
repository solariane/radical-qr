#!/bin/bash
# Shoots and edits the Mac App Previews (1920x1080).
#
#   ./appstore/previews/shoot-mac.sh             # both storyboards, en fr de es
#   ./appstore/previews/shoot-mac.sh sb2         # one storyboard, all four languages
#   ./appstore/previews/shoot-mac.sh sb1 fr      # one storyboard, one language
#
# The Mac counterpart of shoot.sh: same storyboards and edit, filmed with
# `screencapture -v` on a window the DEBUG hook puts at a fixed frame. The app
# must be in front and the Mac left alone while it runs.
#
# One-time setup (needs an admin password; undo with disable-…):
#   sudo automationmodetool enable-automationmode-without-authentication
# and Screen Recording + Accessibility for the app running this script.
#
# Two Mac-only differences from the phone:
# - the build is unsandboxed (ENABLE_APP_SANDBOX=NO) so the app can read the
#   paste/logo hand-offs, and the demo starts with an empty in-memory history
#   (DEMO_EMPTY_HISTORY) so the developer's own codes never appear;
# - the UI test runner *is* sandboxed, so its work directory lives in its
#   container.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
export PREVIEW_WORK="${PREVIEW_WORK:-/tmp/radicalqr-previews-mac}"
WORK="$PREVIEW_WORK"
PROJ="$WORK/proj"
RUNNER_TMP="$HOME/Library/Containers/radicalsolution.com.Radical-QRUITests.xctrunner/Data/tmp/demo"
DEST="platform=macOS,arch=arm64"
# Window frame, top-left screen points: 1040pt tall fits the tallest form (a
# contact) with its code and the save row; 1440pt wide keeps all five export
# tiles in the panel (at 1280 the fifth is clipped). Kept left, away from
# notification banners.
WINDOW="100,140,1440,1040"

prepare() {
  mkdir -p "$WORK"/{raw,work} "$PROJ" "$RUNNER_TMP/uitest"
  rsync -a --delete "$REPO/Radical QR" "$REPO/Radical QRTests" "$REPO/RadicalQRShare" "$REPO/QRCode.xcodeproj" "$PROJ/"
  (cd "$PROJ" && git apply "$HERE/demo-hooks.patch") || { echo "demo-hooks.patch does not apply"; exit 1; }
  # A different bundle identifier and no iCloud: the demo can never open the
  # developer's container, sync their history, or be mistaken by LaunchServices
  # for the installed app — whatever the recording shows is the demo's own data.
  sed -i '' -e 's/PRODUCT_BUNDLE_IDENTIFIER = "radicalsolution.com.Radical-QR";/PRODUCT_BUNDLE_IDENTIFIER = "radicalsolution.com.Radical-QR.preview";/' \
            -e 's/"radicalsolution.com.Radical-QR.RadicalQRShare"/"radicalsolution.com.Radical-QR.preview.RadicalQRShare"/' \
            "$PROJ/QRCode.xcodeproj/project.pbxproj"
  printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>' \
    '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
    '<plist version="1.0"><dict/></plist>' > "$PROJ/Radical QR/Radical QR.entitlements"
  mkdir -p "$PROJ/Radical QRUITests" && command cp -f "$HERE"/uitests/*.swift "$PROJ/Radical QRUITests/"
  command cp -f "$REPO/design/icon-512.png" "$RUNNER_TMP/logo.png"
  python3 "$HERE/assets.py" mac >/dev/null
  echo "Building…"
  (cd "$PROJ" && xcodebuild -project QRCode.xcodeproj -scheme "Radical QR" -destination "$DEST" \
    -derivedDataPath "$WORK/build" ENABLE_APP_SANDBOX=NO SWIFT_OPTIMIZATION_LEVEL=-O ENABLE_TESTABILITY=YES -allowProvisioningUpdates build-for-testing > "$WORK/build.log" 2>&1) \
    || { grep error: "$WORK/build.log" | head; exit 1; }
}

runtest() { # runtest Class/method lang
  for attempt in 1 2 3; do
    (cd "$PROJ" && TEST_RUNNER_DEMO_LANG="$2" TEST_RUNNER_DEMO_WORK_DIR="$RUNNER_TMP" TEST_RUNNER_DEMO_WINDOW="$WINDOW" \
      xcodebuild -project QRCode.xcodeproj -scheme "Radical QR" -destination "$DEST" -derivedDataPath "$WORK/build" \
      -parallel-testing-enabled NO -only-testing:"Radical QRUITests/$1" test-without-building > "$WORK/test.log" 2>&1)
    grep -q "TEST EXECUTE SUCCEEDED" "$WORK/test.log" && return 0
    grep -q "Failed to initialize\|never finished bootstrapping" "$WORK/test.log" || return 1
    echo "  runner bootstrap failed, retry $attempt"; sleep 5
  done
  return 1
}

shoot() { # shoot sb1|sb2 lang
  local name="${1}_$2" method="testStoryboard${1#sb}"
  rm -f "$RUNNER_TMP/uitest/marks.txt" "$WORK/raw/$name".* "$WORK/work/$name/scores.txt"
  local rect; rect=$(echo "$WINDOW" | tr -d ' ')
  screencapture -v -x -R"$rect" "$WORK/raw/$name.mov" > "$WORK/raw/$name.log" 2>&1 &
  local rec=$!
  python3 -c 'import time;print(f"{time.time():.3f}")' > "$WORK/raw/$name.start"
  runtest "StoryboardTests/$method" "$2"; local rc=$?
  kill -INT "$rec"; wait "$rec" 2>/dev/null
  command cp -f "$RUNNER_TMP/uitest/marks.txt" "$WORK/raw/$name.marks" 2>/dev/null
  [ $rc -eq 0 ] && ! grep -q MISSING "$WORK/raw/$name.marks"
}

prepare
jobs=()
if [ $# -eq 2 ]; then jobs=("$1 $2")
elif [ $# -eq 1 ]; then for l in en fr de es; do jobs+=("$1 $l"); done
else for sb in sb1 sb2; do for l in en fr de es; do jobs+=("$sb $l"); done; done; fi
for job in "${jobs[@]}"; do
  set -- $job
  for attempt in 1 2; do
    echo "=== mac $1 $2 (attempt $attempt)"
    if shoot "$1" "$2"; then python3 "$HERE/edit.py" "$1" "$2" mac | tail -1 && break; fi
    echo "  retrying $1 $2"
  done
done
