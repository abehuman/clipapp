#!/bin/zsh

set -euo pipefail

if (( $# < 2 || $# > 3 )); then
  print -u2 "Usage: $0 <version> <output-directory> [source-packages-directory]"
  exit 64
fi

version=$1
output_directory=${2:A}
project_root=${0:A:h:h}
source_packages_directory=${3:-$project_root/build/SourcePackages}
archive_path=$output_directory/ClipApp.xcarchive
export_directory=$output_directory/export
export_options=$output_directory/ExportOptions-DeveloperID.plist
notary_archive=$output_directory/ClipApp-${version}-notary.zip
notary_result=$output_directory/notary-result.json
notary_log=$output_directory/notary-log.json

required_environment=(
  APPLE_TEAM_ID
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

if [[ $version != <->.<->.<-> ]]; then
  print -u2 "Version must use the <major>.<minor>.<patch> format: $version"
  exit 65
fi

if [[ ! -d $output_directory ]]; then
  print -u2 "Output directory was not found: $output_directory"
  exit 72
fi

if [[ -e $archive_path || -e $export_directory || -e $notary_archive ]]; then
  print -u2 "Refusing to overwrite release output in: $output_directory"
  exit 73
fi

if [[ ! -f $APP_STORE_CONNECT_API_KEY_PATH ]]; then
  print -u2 "App Store Connect API key was not found: $APP_STORE_CONNECT_API_KEY_PATH"
  exit 66
fi

cp "$project_root/Configurations/ExportOptions-DeveloperID.plist" "$export_options"
/usr/libexec/PlistBuddy -c "Set :teamID $APPLE_TEAM_ID" "$export_options"

xcodebuild archive \
  -project "$project_root/ClipApp.xcodeproj" \
  -scheme ClipApp \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$archive_path" \
  -clonedSourcePackagesDirPath "${source_packages_directory:A}" \
  -packageCachePath "${source_packages_directory:A:h}/PackageCache" \
  -skipPackagePluginValidation \
  -skipMacroValidation \
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
  CODE_SIGN_STYLE=Manual \
  'CODE_SIGN_IDENTITY=Developer ID Application'

xcodebuild -exportArchive \
  -archivePath "$archive_path" \
  -exportPath "$export_directory" \
  -exportOptionsPlist "$export_options"

app_path=$export_directory/ClipApp.app
info_plist=$app_path/Contents/Info.plist

if [[ ! -d $app_path || ! -f $info_plist ]]; then
  print -u2 "Exported ClipApp.app was not found: $app_path"
  exit 66
fi

marketing_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$info_plist")
build_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$info_plist")
if [[ $marketing_version != $version || $build_version != $version ]]; then
  print -u2 "Exported app version mismatch: marketing=$marketing_version build=$build_version expected=$version"
  exit 65
fi

"$project_root/scripts/verify-release-app.sh" "$app_path"
ditto -c -k --keepParent "$app_path" "$notary_archive"

set +e
xcrun notarytool submit "$notary_archive" \
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
  print -u2 "Apple notarization failed with status: ${notary_status:-unknown}"
  /usr/bin/plutil -p "$notary_result" >&2 || true
  exit 1
fi

xcrun stapler staple "$app_path"
"$project_root/scripts/verify-release-app.sh" "$app_path" --require-notarization

print "Created notarized app: $app_path"
