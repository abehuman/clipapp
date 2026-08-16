#!/bin/zsh

set -euo pipefail

if (( $# < 2 || $# > 3 )); then
  print -u2 "Usage: $0 /path/to/ClipApp.app <version> [output-directory]"
  exit 64
fi

app_path=$1
version=$2
project_root=${0:A:h:h}
output_directory=${3:-$project_root}
archive_path=${output_directory:A}/ClipApp-${version}-distribution.zip
staging_root=$(mktemp -d "${TMPDIR:-/tmp}/ClipApp-release.XXXXXX")
staging_dir=${staging_root}/ClipApp-${version}

cleanup() {
  rm -rf "$staging_root"
}
trap cleanup EXIT

if [[ ! -d "$app_path" || ${app_path:t} != "ClipApp.app" ]]; then
  print -u2 "ClipApp.app was not found at: $app_path"
  exit 66
fi

if [[ ! -d "$output_directory" ]]; then
  print -u2 "Output directory was not found: $output_directory"
  exit 72
fi

mkdir -p "$staging_dir"
ditto "$app_path" "$staging_dir/ClipApp.app"
cp "$project_root/LICENSE" "$project_root/LICENSE_CLIPMENU" \
  "$project_root/LICENSE_SPARKLE" "$project_root/THIRD_PARTY_NOTICES" \
  "$staging_dir/"

if [[ -e "$archive_path" ]]; then
  print -u2 "Refusing to overwrite existing archive: $archive_path"
  exit 73
fi

(
  cd "$staging_root"
  ditto -c -k --keepParent "${staging_dir:t}" "$archive_path"
)

print "Created $archive_path"
