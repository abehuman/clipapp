#!/bin/zsh

set -euo pipefail

if (( $# != 3 )); then
  print -u2 "Usage: $0 /path/to/archive.zip <version> <distribution|update>"
  exit 64
fi

archive_path=${1:A}
version=$2
archive_kind=$3
project_root=${0:A:h:h}
extraction_root=$(mktemp -d "${TMPDIR:-/tmp}/ClipApp-archive-verification.XXXXXX")

cleanup() {
  rm -rf "$extraction_root"
}
trap cleanup EXIT

if [[ ! -f $archive_path ]]; then
  print -u2 "Release archive was not found: $archive_path"
  exit 66
fi

if [[ $version != <->.<->.<-> ]]; then
  print -u2 "Version must use the <major>.<minor>.<patch> format: $version"
  exit 65
fi

case $archive_kind in
  distribution)
    expected_app=$extraction_root/ClipApp-${version}/ClipApp.app
    ;;
  update)
    expected_app=$extraction_root/ClipApp.app
    ;;
  *)
    print -u2 "Unknown archive kind: $archive_kind"
    exit 64
    ;;
esac

unzip -tq "$archive_path"
ditto -x -k "$archive_path" "$extraction_root"

if [[ ! -d $expected_app ]]; then
  print -u2 "Expected app was not found after extracting $archive_path: $expected_app"
  exit 66
fi

info_plist=$expected_app/Contents/Info.plist
marketing_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$info_plist")
build_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$info_plist")
if [[ $marketing_version != $version || $build_version != $version ]]; then
  print -u2 "Extracted app version mismatch: marketing=$marketing_version build=$build_version expected=$version"
  exit 65
fi

"$project_root/scripts/verify-release-app.sh" "$expected_app" --require-notarization
print "Verified $archive_kind archive: $archive_path"
