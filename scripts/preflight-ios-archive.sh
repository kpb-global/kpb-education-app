#!/usr/bin/env bash
# Préflight iOS strict — valide l'artefact signé, pas seulement ses métadonnées.
#
# Usage, APRÈS une archive App Store créée dans Xcode Organizer :
#   scripts/preflight-ios-archive.sh \
#     --xcconfig ios/Flutter/Generated.xcconfig \
#     --archive-plist path/to/Runner.xcarchive/Products/Applications/Runner.app/Info.plist
#
# `--app path/to/Runner.app` peut remplacer `--archive-plist`. Lorsque les deux
# sont fournis, ils doivent désigner le même bundle. Le script ne construit rien,
# ne lit aucun trousseau et n'affiche aucune valeur de secret.

set -euo pipefail

XCCONFIG=""
ARCHIVE_PLIST=""
APP_PATH=""

EXPECTED_BUILD="50"
EXPECTED_VERSION="2.1.0"
EXPECTED_BUNDLE_ID="Karatou.karatou"
EXPECTED_TEAM_ID="DNPB788LKX"

# Le démasquage des outils IA est une constante de COMPILATION : l'oublier ne
# casse rien, ne se voit nulle part, et livre une build identique à la
# précédente. C'est la raison d'être de cette ligne — la changer doit rester un
# geste délibéré, pas un effet de bord.
EXPECTED_AI_TOOLS="true"

usage() {
  sed -n '2,15p' "$0" | sed 's/^# \?//'
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --xcconfig) XCCONFIG="${2:-}"; shift 2 ;;
    --archive-plist) ARCHIVE_PLIST="${2:-}"; shift 2 ;;
    --app) APP_PATH="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Argument inconnu : $1" >&2; usage ;;
  esac
done

fail() { echo "PREFLIGHT ÉCHEC : $*" >&2; exit 1; }

[[ -n "$XCCONFIG" ]] || usage
[[ -f "$XCCONFIG" ]] || {
  echo "Generated.xcconfig introuvable : $XCCONFIG" >&2
  echo "Ce script ne construit rien. Passez le fichier produit par Flutter." >&2
  exit 2
}

if [[ -z "$APP_PATH" && -n "$ARCHIVE_PLIST" ]]; then
  [[ "$(basename "$ARCHIVE_PLIST")" == "Info.plist" ]] || \
    fail "--archive-plist doit désigner le Info.plist racine d'un .app"
  APP_PATH="$(dirname "$ARCHIVE_PLIST")"
fi
[[ -n "$APP_PATH" ]] || usage
[[ -d "$APP_PATH" && "${APP_PATH##*.}" == "app" ]] || \
  fail "bundle .app introuvable : $APP_PATH"

APP_PLIST="$APP_PATH/Info.plist"
[[ -f "$APP_PLIST" ]] || fail "Info.plist absent du bundle : $APP_PLIST"
if [[ -n "$ARCHIVE_PLIST" ]]; then
  [[ -f "$ARCHIVE_PLIST" ]] || fail "Info.plist d'archive introuvable : $ARCHIVE_PLIST"
  cmp -s "$ARCHIVE_PLIST" "$APP_PLIST" || \
    fail "--archive-plist ne correspond pas au bundle donné par --app"
fi

for tool in codesign security plutil python3; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "Outil macOS requis introuvable : $tool" >&2
    exit 2
  }
done

TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/kpb-ios-preflight.XXXXXX")
trap 'rm -rf "$TMP_DIR"' EXIT

plist_get() {
  python3 - "$1" "$2" <<'PY'
import plistlib
import sys

with open(sys.argv[1], "rb") as handle:
    value = plistlib.load(handle)
for part in sys.argv[2].split("."):
    if not isinstance(value, dict) or part not in value:
        raise SystemExit(3)
    value = value[part]
if isinstance(value, bool):
    print("true" if value else "false")
elif isinstance(value, list):
    print("\n".join(str(item) for item in value))
else:
    print(value)
PY
}

# Flutter build contract. Decode in memory and never print DART_DEFINES because
# it can contain client-side service keys.
NUMBER=$(grep -E '^FLUTTER_BUILD_NUMBER=' "$XCCONFIG" | head -1 | cut -d= -f2- | tr -d '[:space:]')
[[ "$NUMBER" == "$EXPECTED_BUILD" ]] || \
  fail "FLUTTER_BUILD_NUMBER=$NUMBER (attendu $EXPECTED_BUILD)"

NAME=$(grep -E '^FLUTTER_BUILD_NAME=' "$XCCONFIG" | head -1 | cut -d= -f2- | tr -d '[:space:]')
[[ "$NAME" == "$EXPECTED_VERSION" ]] || \
  fail "FLUTTER_BUILD_NAME=$NAME (attendu $EXPECTED_VERSION)"

DEFINES=$(grep -E '^DART_DEFINES=' "$XCCONFIG" | head -1 | cut -d= -f2-)
[[ -n "$DEFINES" ]] || fail "DART_DEFINES vide dans $XCCONFIG"
DECODED=$(python3 - "$DEFINES" <<'PY'
import base64
import sys

for chunk in sys.argv[1].split(","):
    chunk = chunk.strip()
    if not chunk:
        continue
    padding = "=" * (-len(chunk) % 4)
    print(base64.b64decode(chunk + padding).decode("utf-8", "strict"))
PY
) || fail "DART_DEFINES n'est pas un ensemble base64 valide"

printf '%s\n' "$DECODED" | grep -Fxq 'KPB_APP_ENV=prod' || \
  fail "DART_DEFINES sans KPB_APP_ENV=prod"
WHATSAPP=$(printf '%s\n' "$DECODED" | sed -n 's/^KPB_WHATSAPP_NUMBER=//p' | tail -1)
[[ -n "$WHATSAPP" && "$WHATSAPP" != *'<'* && "$WHATSAPP" != *'>'* ]] || \
  fail "KPB_WHATSAPP_NUMBER absent ou placeholder"

POSTHOG=$(printf '%s\n' "$DECODED" | sed -n 's/^POSTHOG_API_KEY=//p' | tail -1)
printf '%s\n' "$DECODED" | grep -q '^POSTHOG_API_KEY=' || \
  fail "DART_DEFINES sans choix explicite POSTHOG_API_KEY="
if [[ -n "$POSTHOG" && "$POSTHOG" != phc_* ]]; then
  fail "POSTHOG_API_KEY renseignée mais format public phc_… invalide"
fi

AI_TOOLS=$(printf '%s\n' "$DECODED" | sed -n 's/^KPB_AI_TOOLS_ENABLED=//p' | tail -1)
printf '%s\n' "$DECODED" | grep -q '^KPB_AI_TOOLS_ENABLED=' || \
  fail "DART_DEFINES sans KPB_AI_TOOLS_ENABLED= : le drapeau est lu à la COMPILATION, l'omettre livre les outils IA masqués sans le dire"
[[ "$AI_TOOLS" == "$EXPECTED_AI_TOOLS" ]] || \
  fail "KPB_AI_TOOLS_ENABLED=$AI_TOOLS (attendu $EXPECTED_AI_TOOLS)"

API_OVERRIDE=$(printf '%s\n' "$DECODED" | sed -n 's/^KPB_API_BASE_URL=//p' | tail -1)
if [[ -n "$API_OVERRIDE" && "$API_OVERRIDE" != https://* ]]; then
  fail "KPB_API_BASE_URL de production doit utiliser https://"
fi

# Identity and public metadata.
BUNDLE_ID=$(plist_get "$APP_PLIST" CFBundleIdentifier) || fail "CFBundleIdentifier absent"
[[ "$BUNDLE_ID" == "$EXPECTED_BUNDLE_ID" ]] || \
  fail "CFBundleIdentifier=$BUNDLE_ID (attendu $EXPECTED_BUNDLE_ID)"
VERSION=$(plist_get "$APP_PLIST" CFBundleShortVersionString) || fail "version marketing absente"
[[ "$VERSION" == "$EXPECTED_VERSION" ]] || \
  fail "CFBundleShortVersionString=$VERSION (attendu $EXPECTED_VERSION)"
BUILD=$(plist_get "$APP_PLIST" CFBundleVersion) || fail "CFBundleVersion absent"
[[ "$BUILD" == "$EXPECTED_BUILD" ]] || \
  fail "CFBundleVersion=$BUILD (attendu $EXPECTED_BUILD)"

ORIENTATION=$(plist_get "$APP_PLIST" UISupportedInterfaceOrientations) || fail "orientations absentes"
[[ "$ORIENTATION" == "UIInterfaceOrientationPortrait" ]] || \
  fail "orientations archive = [$ORIENTATION]"
# Famille d'appareils ET orientations iPad : deux règles d'Apple, couplées. Elles
# ne laissent qu'UNE configuration valide, et ce préflight a laissé passer les
# deux bundles qui la violaient — d'où ce contrôle.
#
#  · 90101 — on ne peut PAS retirer une famille d'appareils d'une app DÉJÀ
#    publiée. La fiche (id 1128659292) est universelle depuis toujours, donc
#    UIDeviceFamily doit contenir 2. Tenté en iPhone-only sur la 49 : refusé.
#  · 90474 — un bundle qui embarque l'iPad doit déclarer les QUATRE orientations
#    iPad (multitâche). Tenté en portrait-only sur la 49 : refusé.
#
# Seule issue : famille [1,2] + 4 orientations iPad — exactement la build 48,
# acceptée. L'iPhone reste portrait-only (aucune contrainte de multitâche), et
# le verrou runtime (SystemChrome.portraitUp, lockPortraitOrientation) garde
# l'UI en portrait sur les DEUX familles : déclarer les 4 orientations iPad
# n'autorise donc aucune rotation réelle.
DEVICE_FAMILY=$(plist_get "$APP_PLIST" UIDeviceFamily) || fail "UIDeviceFamily absent"
DEVICE_FAMILY_FLAT=$(printf '%s' "$DEVICE_FAMILY" | tr '\n' ',')
printf '%s\n' "$DEVICE_FAMILY" | grep -Fxq '2' || \
  fail "UIDeviceFamily=[$DEVICE_FAMILY_FLAT] : l'iPad manque. Retirer une famille d'appareils d'une app publiée = rejet 90101. Garder TARGETED_DEVICE_FAMILY=\"1,2\"."
IPAD=$(plist_get "$APP_PLIST" 'UISupportedInterfaceOrientations~ipad') || \
  fail "UISupportedInterfaceOrientations~ipad absent alors que le bundle embarque l'iPad"
IPAD_FLAT=$(printf '%s' "$IPAD" | tr '\n' ',')
IPAD_COUNT=$(printf '%s\n' "$IPAD" | grep -c .)
[[ "$IPAD_COUNT" == "4" ]] || \
  fail "orientations iPad=[$IPAD_FLAT] : un bundle iPad doit déclarer les 4 orientations (multitâche), sinon rejet 90474."
BACKGROUND=$(plist_get "$APP_PLIST" UIBackgroundModes) || fail "UIBackgroundModes absent"
[[ "$BACKGROUND" == "remote-notification" ]] || \
  fail "UIBackgroundModes archive = [$BACKGROUND]"
LOCALIZATIONS=$(plist_get "$APP_PLIST" CFBundleLocalizations) || fail "localisations absentes"
[[ "$LOCALIZATIONS" == "fr" ]] || fail "CFBundleLocalizations = [$LOCALIZATIONS]"
FIREBASE_ANALYTICS_DEFAULT=$(plist_get "$APP_PLIST" FIREBASE_ANALYTICS_COLLECTION_ENABLED) || \
  fail "FIREBASE_ANALYTICS_COLLECTION_ENABLED absent"
[[ "$FIREBASE_ANALYTICS_DEFAULT" == "false" ]] || \
  fail "Firebase Analytics doit démarrer désactivé"
CRASHLYTICS_DEFAULT=$(plist_get "$APP_PLIST" FirebaseCrashlyticsCollectionEnabled) || \
  fail "FirebaseCrashlyticsCollectionEnabled absent"
[[ "$CRASHLYTICS_DEFAULT" == "false" ]] || \
  fail "Firebase Crashlytics doit démarrer désactivé"

# The app-level privacy manifest must survive the archive resource phase.
PRIVACY_MANIFEST="$APP_PATH/PrivacyInfo.xcprivacy"
[[ -f "$PRIVACY_MANIFEST" ]] || fail "PrivacyInfo.xcprivacy absent du bundle signé"
plutil -lint "$PRIVACY_MANIFEST" >/dev/null || fail "PrivacyInfo.xcprivacy invalide"
TRACKING=$(plist_get "$PRIVACY_MANIFEST" NSPrivacyTracking) || \
  fail "NSPrivacyTracking absent du manifeste de confidentialité"
[[ "$TRACKING" == "false" ]] || fail "NSPrivacyTracking doit être false"

# Verify the actual signature and its identity. An unsigned archive, an ad-hoc
# signature, or Apple Development must never pass a store preflight.
codesign --verify --deep --strict "$APP_PATH" >/dev/null 2>&1 || \
  fail "signature codesign absente ou invalide"
SIGNING=$(codesign -dv --verbose=4 "$APP_PATH" 2>&1) || fail "signature illisible"
printf '%s\n' "$SIGNING" | grep -Eq '^Authority=(Apple Distribution|iPhone Distribution)' || \
  fail "l'app n'est pas signée avec un certificat Apple Distribution"
printf '%s\n' "$SIGNING" | grep -Fxq "Identifier=$EXPECTED_BUNDLE_ID" || \
  fail "l'identifiant codesign n'est pas $EXPECTED_BUNDLE_ID"
printf '%s\n' "$SIGNING" | grep -Fxq "TeamIdentifier=$EXPECTED_TEAM_ID" || \
  fail "le TeamIdentifier codesign n'est pas $EXPECTED_TEAM_ID"

ENTITLEMENTS="$TMP_DIR/entitlements.plist"
codesign -d --entitlements :- "$APP_PATH" >"$ENTITLEMENTS" 2>/dev/null || \
  fail "entitlements codesign illisibles"
plutil -lint "$ENTITLEMENTS" >/dev/null || fail "entitlements codesign invalides"
APS=$(plist_get "$ENTITLEMENTS" aps-environment) || fail "aps-environment absent de la signature"
[[ "$APS" == "production" ]] || fail "aps-environment=$APS (attendu production)"
if DEBUGGABLE=$(plist_get "$ENTITLEMENTS" get-task-allow 2>/dev/null); then
  [[ "$DEBUGGABLE" == "false" ]] || fail "get-task-allow=true : build de développement"
fi
APP_IDENTIFIER=$(plist_get "$ENTITLEMENTS" application-identifier) || \
  fail "application-identifier absent des entitlements"
[[ "$APP_IDENTIFIER" == "$EXPECTED_TEAM_ID.$EXPECTED_BUNDLE_ID" ]] || \
  fail "application-identifier inattendu"

# App Store provisioning profile: production push, no registered devices,
# non-debuggable, correct team/bundle, and currently valid.
PROFILE="$APP_PATH/embedded.mobileprovision"
[[ -f "$PROFILE" ]] || fail "embedded.mobileprovision absent"
PROFILE_PLIST="$TMP_DIR/profile.plist"
security cms -D -i "$PROFILE" >"$PROFILE_PLIST" 2>/dev/null || \
  fail "profil de provisioning illisible"
plutil -lint "$PROFILE_PLIST" >/dev/null || fail "profil de provisioning invalide"

PROFILE_TEAM=$(plist_get "$PROFILE_PLIST" TeamIdentifier) || fail "TeamIdentifier absent du profil"
[[ "$PROFILE_TEAM" == "$EXPECTED_TEAM_ID" ]] || fail "profil rattaché à une autre équipe"
PROFILE_APP_ID=$(plist_get "$PROFILE_PLIST" Entitlements.application-identifier) || \
  fail "application-identifier absent du profil"
[[ "$PROFILE_APP_ID" == "$EXPECTED_TEAM_ID.$EXPECTED_BUNDLE_ID" ]] || \
  fail "profil destiné à un autre bundle"
PROFILE_APS=$(plist_get "$PROFILE_PLIST" Entitlements.aps-environment) || \
  fail "aps-environment absent du profil"
[[ "$PROFILE_APS" == "production" ]] || fail "profil APNs non-production"
PROFILE_DEBUG=$(plist_get "$PROFILE_PLIST" Entitlements.get-task-allow) || \
  fail "get-task-allow absent du profil"
[[ "$PROFILE_DEBUG" == "false" ]] || fail "profil de développement (get-task-allow=true)"
PROFILE_BETA=$(plist_get "$PROFILE_PLIST" Entitlements.beta-reports-active) || \
  fail "profil non App Store (beta-reports-active absent)"
[[ "$PROFILE_BETA" == "true" ]] || fail "profil non App Store"
if plist_get "$PROFILE_PLIST" ProvisionedDevices >/dev/null 2>&1; then
  fail "profil Ad Hoc/de développement : ProvisionedDevices présent"
fi
if ALL_DEVICES=$(plist_get "$PROFILE_PLIST" ProvisionsAllDevices 2>/dev/null); then
  [[ "$ALL_DEVICES" == "false" ]] || fail "profil Enterprise : ProvisionsAllDevices=true"
fi
python3 - "$PROFILE_PLIST" <<'PY' || fail "profil de provisioning expiré"
import datetime
import plistlib
import sys

with open(sys.argv[1], "rb") as handle:
    expiration = plistlib.load(handle).get("ExpirationDate")
if not isinstance(expiration, datetime.datetime):
    raise SystemExit(1)
now = datetime.datetime.now(datetime.timezone.utc)
if expiration.replace(tzinfo=datetime.timezone.utc) <= now:
    raise SystemExit(1)
PY

echo "Préflight iOS OK — 2.1.0 (49), Karatou.karatou, Apple Distribution, APNs production, profil App Store, confidentialité embarquée."
