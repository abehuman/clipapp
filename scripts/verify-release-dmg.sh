#!/bin/zsh

set -euo pipefail

if (( $# != 2 )); then
  print -u2 "Usage: $0 /path/to/ClipApp-<version>.dmg <version>"
  exit 64
fi

dmg_path=${1:A}
version=$2
project_root=${0:A:h:h}
mount_root=$(mktemp -d "${TMPDIR:-/tmp}/ClipApp-dmg-verification.XXXXXX")
mounted=false

cleanup() {
  if [[ $mounted == true ]]; then
    hdiutil detach "$mount_root" >/dev/null 2>&1 || \
      hdiutil detach -force "$mount_root" >/dev/null 2>&1 || true
  fi
  rm -rf "$mount_root"
}
trap cleanup EXIT

if [[ $version != <->.<->.<-> ]]; then
  print -u2 "Version must use the <major>.<minor>.<patch> format: $version"
  exit 65
fi

if [[ ! -f $dmg_path || ${dmg_path:e} != dmg ]]; then
  print -u2 "Release disk image was not found: $dmg_path"
  exit 66
fi

hdiutil verify "$dmg_path"
codesign --verify --verbose=4 "$dmg_path"
xcrun stapler validate "$dmg_path"
spctl --assess --type open --context context:primary-signature --verbose=4 "$dmg_path"

hdiutil attach \
  -readonly \
  -nobrowse \
  -noautoopen \
  -mountpoint "$mount_root" \
  "$dmg_path" >/dev/null
mounted=true

app_path=$mount_root/ClipApp.app
applications_link=$mount_root/Applications
background_path=$mount_root/.background/background.png

if [[ ! -d $app_path ]]; then
  print -u2 "ClipApp.app is missing from the disk image root."
  exit 66
fi

if [[ ! -L $applications_link || $(readlink "$applications_link") != /Applications ]]; then
  print -u2 "The disk image must contain an Applications symlink."
  exit 66
fi

if [[ ! -f $background_path || ! -f $mount_root/.DS_Store ]]; then
  print -u2 "The disk image is missing its Finder background or layout."
  exit 66
fi

background_width=$(sips -g pixelWidth "$background_path" 2>/dev/null | awk '/pixelWidth/ { print $2 }')
background_height=$(sips -g pixelHeight "$background_path" 2>/dev/null | awk '/pixelHeight/ { print $2 }')
if [[ $background_width != 640 || $background_height != 400 ]]; then
  print -u2 "Unexpected DMG background size: ${background_width:-unknown}x${background_height:-unknown}"
  exit 65
fi

info_plist=$app_path/Contents/Info.plist
marketing_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$info_plist")
build_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$info_plist")
if [[ $marketing_version != $version || $build_version != $version ]]; then
  print -u2 "DMG app version mismatch: marketing=$marketing_version build=$build_version expected=$version"
  exit 65
fi

"$project_root/scripts/verify-release-app.sh" "$app_path" --require-notarization

hdiutil detach "$mount_root" >/dev/null
mounted=false

print "Verified release disk image: $dmg_path"
