#!/bin/zsh

set -euo pipefail

if (( $# < 2 || $# > 3 )); then
  print -u2 "Usage: $0 /path/to/ClipApp.app <version> [output-directory]"
  exit 64
fi

app_path=${1:A}
version=$2
project_root=${0:A:h:h}
output_directory=${3:-$project_root}
output_directory=${output_directory:A}
dmg_path=$output_directory/ClipApp-${version}.dmg
volume_name="ClipApp $version"
working_root=$(mktemp -d "${TMPDIR:-/tmp}/ClipApp-dmg.XXXXXX")
staging_directory=$working_root/staging
mount_directory=/Volumes/$volume_name
read_write_image=$working_root/ClipApp-read-write.dmg
compressed_image=$working_root/ClipApp-compressed.dmg
mounted=false

cleanup() {
  if [[ $mounted == true ]]; then
    hdiutil detach "$mount_directory" >/dev/null 2>&1 || \
      hdiutil detach -force "$mount_directory" >/dev/null 2>&1 || true
  fi
  rm -rf "$working_root"
}
trap cleanup EXIT

if [[ $version != <->.<->.<-> ]]; then
  print -u2 "Version must use the <major>.<minor>.<patch> format: $version"
  exit 65
fi

if [[ ! -d $app_path || ${app_path:t} != ClipApp.app ]]; then
  print -u2 "ClipApp.app was not found at: $app_path"
  exit 66
fi

if [[ ! -d $output_directory ]]; then
  print -u2 "Output directory was not found: $output_directory"
  exit 72
fi

if [[ -e $dmg_path ]]; then
  print -u2 "Refusing to overwrite existing disk image: $dmg_path"
  exit 73
fi

if [[ -e $mount_directory ]]; then
  print -u2 "Refusing to reuse an existing mounted volume: $mount_directory"
  exit 73
fi

mkdir -p "$staging_directory/.background"
ditto "$app_path" "$staging_directory/ClipApp.app"
ln -s /Applications "$staging_directory/Applications"
swift "$project_root/scripts/generate-dmg-background.swift" \
  "$staging_directory/.background/background.png"

hdiutil create \
  -volname "$volume_name" \
  -fs APFS \
  -format UDRW \
  -srcfolder "$staging_directory" \
  "$read_write_image"

hdiutil attach \
  -readwrite \
  -noverify \
  -noautoopen \
  "$read_write_image" >/dev/null
mounted=true

if [[ ! -d $mount_directory ]]; then
  print -u2 "Mounted release volume was not found: $mount_directory"
  exit 72
fi

osascript "$project_root/scripts/layout-release-dmg.applescript" \
  "$volume_name" \
  "$mount_directory"

for generated_directory in .fseventsd .Spotlight-V100 .Trashes; do
  rm -rf -- "$mount_directory/$generated_directory"
done
sync

hdiutil detach "$mount_directory" >/dev/null
mounted=false

hdiutil convert \
  "$read_write_image" \
  -format ULFO \
  -o "$compressed_image" >/dev/null
mv "$compressed_image" "$dmg_path"
hdiutil verify "$dmg_path"

print "Created $dmg_path"
