#!/bin/zsh

set -euo pipefail

if (( $# != 1 )); then
  print -u2 "Usage: $0 /path/to/ClipApp-<version>.dmg"
  exit 64
fi

dmg_path=${1:A}
working_root=$(mktemp -d "${TMPDIR:-/tmp}/ClipApp-dmg-notarization.XXXXXX")
notary_result=$working_root/notary-result.json
notary_log=$working_root/notary-log.json

cleanup() {
  rm -rf "$working_root"
}
trap cleanup EXIT

required_environment=(
  DEVELOPER_ID_APPLICATION_IDENTITY
  APP_STORE_CONNECT_API_KEY_ID
  APP_STORE_CONNECT_API_ISSUER_ID
  APP_STORE_CONNECT_API_KEY_PATH
)

for variable_name in $required_environment; do
  if [[ -z ${(P)variable_name:-} ]]; then
    print -u2 "Required environment variable is missing: $variable_name"
    exit 78
  fi
done

if [[ ! -f $dmg_path || ${dmg_path:e} != dmg ]]; then
  print -u2 "Release disk image was not found: $dmg_path"
  exit 66
fi

if [[ ! -f $APP_STORE_CONNECT_API_KEY_PATH ]]; then
  print -u2 "App Store Connect API key was not found: $APP_STORE_CONNECT_API_KEY_PATH"
  exit 66
fi

codesign \
  --force \
  --timestamp \
  --sign "$DEVELOPER_ID_APPLICATION_IDENTITY" \
  "$dmg_path"
codesign --verify --verbose=4 "$dmg_path"

set +e
xcrun notarytool submit "$dmg_path" \
  --key "$APP_STORE_CONNECT_API_KEY_PATH" \
  --key-id "$APP_STORE_CONNECT_API_KEY_ID" \
  --issuer "$APP_STORE_CONNECT_API_ISSUER_ID" \
  --wait \
  --output-format json > "$notary_result"
submit_status=$?
set -e

submission_id=$(/usr/bin/plutil -extract id raw -o - "$notary_result" 2>/dev/null || true)
notary_status=$(/usr/bin/plutil -extract status raw -o - "$notary_result" 2>/dev/null || true)

if [[ -n $submission_id ]]; then
  xcrun notarytool log "$submission_id" \
    --key "$APP_STORE_CONNECT_API_KEY_PATH" \
    --key-id "$APP_STORE_CONNECT_API_KEY_ID" \
    --issuer "$APP_STORE_CONNECT_API_ISSUER_ID" \
    "$notary_log"
  /usr/bin/plutil -p "$notary_log"
fi

if (( submit_status != 0 )) || [[ $notary_status != Accepted ]]; then
  print -u2 "Apple DMG notarization failed with status: ${notary_status:-unknown}"
  /usr/bin/plutil -p "$notary_result" >&2 || true
  exit 1
fi

xcrun stapler staple "$dmg_path"
xcrun stapler validate "$dmg_path"
codesign --verify --verbose=4 "$dmg_path"
spctl --assess --type open --context context:primary-signature --verbose=4 "$dmg_path"

print "Notarized $dmg_path"
