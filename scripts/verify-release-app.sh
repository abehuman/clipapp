#!/bin/zsh

set -euo pipefail

if (( $# < 1 || $# > 2 )); then
  print -u2 "Usage: $0 /path/to/ClipApp.app [--require-notarization]"
  exit 64
fi

app_path=${1:A}
verification_mode=${2:-}

if [[ $verification_mode != "" && $verification_mode != "--require-notarization" ]]; then
  print -u2 "Unknown verification mode: $verification_mode"
  exit 64
fi

info_plist=$app_path/Contents/Info.plist
executable=$app_path/Contents/MacOS/ClipApp

if [[ ! -d $app_path || ${app_path:t} != "ClipApp.app" ]]; then
  print -u2 "ClipApp.app was not found at: $app_path"
  exit 66
fi

if [[ ! -f $info_plist || ! -f $executable ]]; then
  print -u2 "ClipApp.app is missing its Info.plist or executable: $app_path"
  exit 66
fi

if [[ ! -d $app_path/Contents/Frameworks/Sparkle.framework ]]; then
  print -u2 "Sparkle.framework is missing from the app."
  exit 66
fi

required_notices=(
  LICENSE
  LICENSE_CLIPMENU
  LICENSE_SPARKLE
  THIRD_PARTY_NOTICES
)
for notice in $required_notices; do
  if [[ ! -f $app_path/Contents/Resources/$notice ]]; then
    print -u2 "Required license or notice is missing from the app: $notice"
    exit 66
  fi
done

bundle_identifier=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$info_plist")
if [[ $bundle_identifier != "jp.co.aiv.clipApp" ]]; then
  print -u2 "Unexpected bundle identifier: $bundle_identifier"
  exit 65
fi

codesign --verify --deep --strict --all-architectures --verbose=4 "$app_path"

architectures=$(lipo -archs "$executable")
if [[ " $architectures " != *' arm64 '* || " $architectures " != *' x86_64 '* ]]; then
  print -u2 "Release must contain arm64 and x86_64 slices; found: $architectures"
  exit 65
fi

if [[ $verification_mode == "--require-notarization" ]]; then
  xcrun stapler validate "$app_path"
  spctl --assess --type execute --verbose=4 "$app_path"
fi

print "Verified release app: $app_path"
print "Architectures: $architectures"
