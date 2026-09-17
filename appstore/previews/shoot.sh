#!/bin/bash
# Shoots and edits the App Store App Previews (iPhone 6.9", 886x1920).
#
#   ./appstore/previews/shoot.sh                 # both storyboards, en fr de es
#   ./appstore/previews/shoot.sh sb1 fr          # one storyboard, one language
#   ./appstore/previews/shoot.sh validate        # only check the pasted examples
#
# Works on a scratch copy of the project (the repo is never modified): applies
# demo-hooks.patch (DEBUG-only paste/logo hand-offs), drops the UI tests into
# "Radical QRUITests", records the simulator while XCTest drives each storyboard,
# then edit.py cuts on the test's marks and composites the preview.
# Env: PREVIEW_WORK (default /tmp/radicalqr-previews), PREVIEW_DEVICE (default
# "iPhone 17 Pro Max"). Requires ffmpeg and Python 3 with Pillow.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
export PREVIEW_WORK="${PREVIEW_WORK:-/tmp/radicalqr-previews}"
WORK="$PREVIEW_WORK"
DEVICE_NAME="${PREVIEW_DEVICE:-iPhone 17 Pro Max}"
PROJ="$WORK/proj"

UDID=$(xcrun simctl list devices available | grep -m1 "    $DEVICE_NAME (" | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
[ -n "$UDID" ] || { echo "No simulator named $DEVICE_NAME"; exit 1; }
DEST="platform=iOS Simulator,id=$UDID"

prepare() {
  mkdir -p "$WORK"/{raw,uitest,work} "$PROJ"
  rsync -a --delete "$REPO/Radical QR" "$REPO/Radical QRTests" "$REPO/RadicalQRShare" "$REPO/QRCode.xcodeproj" "$PROJ/"
  (cd "$PROJ" && git apply "$HERE/demo-hooks.patch") || { echo "demo-hooks.patch does not apply"; exit 1; }
  mkdir -p "$PROJ/Radical QRUITests" && cp "$HERE"/uitests/*.swift "$PROJ/Radical QRUITests/"
  cp "$REPO/design/icon-512.png" "$WORK/logo.png"
  python3 "$HERE/assets.py" >/dev/null
  xcrun simctl boot "$UDID" 2>/dev/null; xcrun simctl bootstatus "$UDID" -b >/dev/null
  xcrun simctl status_bar "$UDID" override --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
  echo "Building…"
  (cd "$PROJ" && xcodebuild -project QRCode.xcodeproj -scheme "Radical QR" -destination "$DEST" \
    -derivedDataPath "$WORK/build" build-for-testing > "$WORK/build.log" 2>&1) || { grep error: "$WORK/build.log" | head; exit 1; }
}

# Parallel testing must stay off: it runs UI tests on a clone of the simulator,
# and the recording would film the idle original.
runtest() { # runtest Class/method lang
  for attempt in 1 2 3 4; do
    (cd "$PROJ" && TEST_RUNNER_DEMO_LANG="$2" TEST_RUNNER_DEMO_WORK_DIR="$WORK" xcodebuild -project QRCode.xcodeproj \
      -scheme "Radical QR" -destination "$DEST" -derivedDataPath "$WORK/build" -parallel-testing-enabled NO \
      -only-testing:"Radical QRUITests/$1" test-without-building > "$WORK/test.log" 2>&1)
    grep -q "TEST EXECUTE SUCCEEDED" "$WORK/test.log" && return 0
    grep -q "failed to initialize\|never finished bootstrapping\|Timed out waiting for AX" "$WORK/test.log" || return 1
    echo "  runner bootstrap failed, retry $attempt"; sleep 5
  done
  return 1
}

shoot() { # shoot sb1|sb2 lang
  local name="${1}_$2" method="testStoryboard${1#sb}"
  for b in com.apple.Preferences com.apple.mobilesafari; do xcrun simctl terminate "$UDID" "$b" >/dev/null 2>&1; done
  rm -f "$WORK/uitest/marks.txt" "$WORK/raw/$name".* "$WORK/work/$name/scores.txt"
  xcrun simctl io "$UDID" recordVideo --codec=h264 --force "$WORK/raw/$name.mov" > "$WORK/raw/$name.log" 2>&1 &
  local rec=$!
  for _ in $(seq 1 150); do grep -q "Recording started" "$WORK/raw/$name.log" && break; sleep 0.1; done
  python3 -c 'import time;print(f"{time.time():.3f}")' > "$WORK/raw/$name.start"
  runtest "StoryboardTests/$method" "$2"; local rc=$?
  kill -INT "$rec"; wait "$rec" 2>/dev/null
  cp "$WORK/uitest/marks.txt" "$WORK/raw/$name.marks" 2>/dev/null
  [ $rc -eq 0 ] && ! grep -q MISSING "$WORK/raw/$name.marks"
}

prepare
if [ "${1:-}" = "validate" ]; then
  for lang in en fr de es; do runtest ValidateTests/testExamples "$lang" && echo "$lang: screenshots in $WORK/uitest"; done
  exit 0
fi
jobs=()
if [ $# -eq 2 ]; then jobs=("$1 $2")
elif [ $# -eq 1 ]; then for l in en fr de es; do jobs+=("$1 $l"); done
else for sb in sb1 sb2; do for l in en fr de es; do jobs+=("$sb $l"); done; done; fi
for job in "${jobs[@]}"; do
  set -- $job
  for attempt in 1 2; do
    echo "=== $1 $2 (attempt $attempt)"
    if shoot "$1" "$2"; then python3 "$HERE/edit.py" "$1" "$2" | tail -1 && break; fi
    echo "  retrying $1 $2"
  done
done
