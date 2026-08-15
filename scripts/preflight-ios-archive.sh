#!/usr/bin/env bash
# Préflight iOS — LIV-T7.
#
# Ne construit PAS l'archive. `flutter build ipa` échoue à l'export sur la
# machine de dev (espace dans le chemin du dépôt, « Copy failed »). La voie
# réelle est : `flutter build ios --release …` puis Xcode Organizer.
#
# Usage, APRÈS l'archive Xcode :
#   scripts/preflight-ios-archive.sh \
#     --xcconfig ios/Flutter/Generated.xcconfig \
#     --archive-plist path/to/Products/Applications/Runner.app/Info.plist
#
# Sortie 2 si un chemin manque (ce script n'est pas un build).

set -euo pipefail

XCCONFIG=""
ARCHIVE_PLIST=""

usage() {
  sed -n '2,16p' "$0" | sed 's/^# \?//'
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --xcconfig) XCCONFIG="${2:-}"; shift 2 ;;
    --archive-plist) ARCHIVE_PLIST="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Argument inconnu : $1" >&2; usage ;;
  esac
done

if [[ -z "$XCCONFIG" || -z "$ARCHIVE_PLIST" ]]; then
  usage
fi
if [[ ! -f "$XCCONFIG" ]]; then
  echo "Generated.xcconfig introuvable : $XCCONFIG" >&2
  echo "Ce script ne construit rien. Passez le fichier produit par flutter build ios." >&2
  exit 2
fi
if [[ ! -f "$ARCHIVE_PLIST" ]]; then
  echo "Info.plist d'archive introuvable : $ARCHIVE_PLIST" >&2
  exit 2
fi

fail() { echo "PREFLIGHT ÉCHEC : $*" >&2; exit 1; }

NUMBER=$(grep -E '^FLUTTER_BUILD_NUMBER=' "$XCCONFIG" | head -1 | cut -d= -f2- | tr -d '[:space:]')
[[ "$NUMBER" == "49" ]] || fail "FLUTTER_BUILD_NUMBER=$NUMBER (attendu 49)"

DEFINES=$(grep -E '^DART_DEFINES=' "$XCCONFIG" | head -1 | cut -d= -f2-)
[[ -n "$DEFINES" ]] || fail "DART_DEFINES vide dans $XCCONFIG"

DECODED=$(python3 -c '
import base64, sys
raw = sys.argv[1]
parts = []
for chunk in raw.split(","):
    chunk = chunk.strip()
    if not chunk:
        continue
    pad = "=" * (-len(chunk) % 4)
    parts.append(base64.b64decode(chunk + pad).decode("utf-8", "replace"))
print("\n".join(parts))
' "$DEFINES")

echo "$DECODED" | grep -q 'KPB_APP_ENV=prod' || fail "DART_DEFINES sans KPB_APP_ENV=prod"
echo "$DECODED" | grep -q 'KPB_WHATSAPP_NUMBER=' || fail "DART_DEFINES sans KPB_WHATSAPP_NUMBER"
echo "$DECODED" | grep -q 'POSTHOG_API_KEY=' || fail "DART_DEFINES sans POSTHOG_API_KEY"

plist_get() {
  python3 -c '
import plistlib, sys
with open(sys.argv[1], "rb") as f:
    data = plistlib.load(f)
val = data.get(sys.argv[2])
if val is None:
    sys.exit(3)
if isinstance(val, list):
    print("\n".join(str(x) for x in val))
else:
    print(val)
' "$ARCHIVE_PLIST" "$1"
}

VERSION=$(plist_get CFBundleVersion) || fail "CFBundleVersion absent de l'archive"
[[ "$VERSION" == "49" ]] || fail "archive CFBundleVersion=$VERSION (attendu 49)"

ORIEN=$(plist_get UISupportedInterfaceOrientations) || fail "orientations absentes"
[[ "$ORIEN" == "UIInterfaceOrientationPortrait" ]] || fail "orientations archive = [$ORIEN]"

if IPAD=$(plist_get "UISupportedInterfaceOrientations~ipad" 2>/dev/null); then
  [[ "$IPAD" == "UIInterfaceOrientationPortrait" ]] || fail "orientations iPad archive = [$IPAD]"
fi

BG=$(plist_get UIBackgroundModes) || fail "UIBackgroundModes absent"
[[ "$BG" == "remote-notification" ]] || fail "UIBackgroundModes archive = [$BG]"

LOCS=$(plist_get CFBundleLocalizations) || fail "CFBundleLocalizations absent"
[[ "$LOCS" == "fr" ]] || fail "CFBundleLocalizations archive = [$LOCS]"

echo "Préflight iOS OK — build 49, portrait, remote-notification, locale fr."
