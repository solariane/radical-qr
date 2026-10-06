#!/bin/bash
# Archives Radical QR and hands it to App Store Connect.
#
#   ./release.sh ios                 # archive, export, ask Apple to validate
#   ./release.sh mac --upload        # …and send it for real
#   ./release.sh both --upload
#   ./release.sh --build 12 both     # override the build number for this run
#   ./release.sh both --reuse        # keep the archives from the last run
#
# Validation is the default: Apple checks the package and answers, but nothing
# reaches App Store Connect. `--upload` is the step that does.
#
# The build number comes from CURRENT_PROJECT_VERSION in the project. Both
# platforms share it, and the share extension must carry the same numbers as
# the app, so bump the two targets together. Apple refuses a build number it
# has already seen; `--build N` raises it for one run without touching the
# project. MARKETING_VERSION must match the version string on App Store
# Connect exactly, and that version has to exist there for each platform
# before updAppStore.sh can write its text.
#
# Credentials: ASC_ISSUER_ID, ASC_KEY_ID, ASC_KEY_PATH, read from ../.env then
# .env, as updAppStore.sh does. ASC_KEY_PATH may be relative to this folder,
# which xcodebuild rejects, so it is made absolute here. altool finds the key
# by id in a directory: the file must be named AuthKey_<ASC_KEY_ID>.p8.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$HERE/QRCode.xcodeproj"
SCHEME="Radical QR"
TEAM_ID=NQWAG54N64
OUT="${RELEASE_WORK:-$HERE/build/release}"

PLATFORMS=""
UPLOAD=false
REUSE=false
BUILD_OVERRIDE=""
USAGE="Usage: $0 [ios|mac|both] [--upload] [--build N] [--reuse]"
while [ $# -gt 0 ]; do
  case "$1" in
    ios|mac|both) PLATFORMS="$1" ;;
    --upload)     UPLOAD=true ;;
    --reuse)      REUSE=true ;;
    --build)      BUILD_OVERRIDE="$2"; shift ;;
    *) echo "$USAGE"; exit 1 ;;
  esac
  shift
done
[ -n "$PLATFORMS" ] || { echo "$USAGE"; exit 1; }

set -a
[ -f "$HERE/../.env" ] && . "$HERE/../.env"
[ -f "$HERE/.env" ] && . "$HERE/.env"
set +a
: "${ASC_ISSUER_ID:?ASC_ISSUER_ID manquant}" "${ASC_KEY_ID:?ASC_KEY_ID manquant}" "${ASC_KEY_PATH:?ASC_KEY_PATH manquant}"
KEY_PATH="${ASC_KEY_PATH/#\~/$HOME}"
case "$KEY_PATH" in /*) ;; *) KEY_PATH="$HERE/$KEY_PATH" ;; esac
[ -f "$KEY_PATH" ] || { echo "Clé introuvable : $KEY_PATH"; exit 1; }
export API_PRIVATE_KEYS_DIR="$(cd "$(dirname "$KEY_PATH")" && pwd)"

settings() { xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release -showBuildSettings 2>/dev/null; }
BUILD_NUMBER="${BUILD_OVERRIDE:-$(settings | awk '/ CURRENT_PROJECT_VERSION = /{print $3; exit}')}"
VERSION=$(settings | awk '/ MARKETING_VERSION = /{print $3; exit}')
echo "Version $VERSION, build $BUILD_NUMBER"

mkdir -p "$OUT"
cat > "$OUT/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <key>destination</key><string>export</string>
</dict>
</plist>
PLIST

release() { # release ios|mac
  local plat="$1" destination type archive export
  if [ "$plat" = "ios" ]; then
    destination="generic/platform=iOS"; type=ios
  else
    destination="generic/platform=macOS"; type=macos
  fi
  archive="$OUT/$plat.xcarchive"
  export="$OUT/$plat"
  rm -rf "$export"

  if $REUSE && [ -d "$archive" ]; then
    echo "→ Archive $plat : celle de $(date -r "$archive" "+%H:%M") est réutilisée"
  else
    rm -rf "$archive"
    echo "→ Archive $plat…"
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
      -destination "$destination" -archivePath "$archive" \
      CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
      -allowProvisioningUpdates \
      -authenticationKeyPath "$KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" \
      -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
      archive > "$OUT/$plat-archive.log" 2>&1 \
      || { grep -E "error:" "$OUT/$plat-archive.log" | head -5; echo "   voir $OUT/$plat-archive.log"; return 1; }
  fi

  # Apple's rsync only: Xcode's export step drives rsync with 2.6-era syntax,
  # and Homebrew's 3.5 on the PATH answers "syntax or usage error". The iOS
  # export is the one that fails; the Mac one happens not to copy that way.
  echo "→ Export $plat…"
  env PATH=/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -exportArchive -archivePath "$archive" -exportPath "$export" \
    -exportOptionsPlist "$OUT/ExportOptions.plist" \
    -allowProvisioningUpdates \
    -authenticationKeyPath "$KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" \
    -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
    > "$OUT/$plat-export.log" 2>&1 \
    || { grep -E "error:" "$OUT/$plat-export.log" | head -5; echo "   voir $OUT/$plat-export.log"; return 1; }

  local package
  package=$(find "$export" -maxdepth 1 \( -name "*.ipa" -o -name "*.pkg" \) | head -1)
  [ -n "$package" ] || { echo "   aucun paquet exporté dans $export"; return 1; }
  echo "   $(basename "$package")"

  local action="--validate-app"
  $UPLOAD && action="--upload-app"
  echo "→ ${action#--} $plat…"
  xcrun altool $action -f "$package" -t "$type" \
    --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID" 2>&1 | tail -15
}

case "$PLATFORMS" in
  ios)  release ios ;;
  mac)  release mac ;;
  both) release ios && release mac ;;
esac

$UPLOAD || echo "(validation seule — rien n'a été envoyé ; ajouter --upload)"
