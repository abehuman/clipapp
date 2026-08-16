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
archive_path=${output_directory:A}/ClipApp-${version}.zip

if [[ ! -d "$app_path" || ${app_path:t} != "ClipApp.app" ]]; then
  print -u2 "ClipApp.app was not found at: $app_path"
  exit 66
fi

if [[ ! -d "$output_directory" ]]; then
  print -u2 "Output directory was not found: $output_directory"
  exit 72
fi

if [[ -e "$archive_path" ]]; then
  print -u2 "Refusing to overwrite existing archive: $archive_path"
  exit 73
fi

# Sparkle recommends an update archive containing only the application bundle.
# The app already embeds all required license and third-party notice files.
ditto -c -k --keepParent "$app_path" "$archive_path"

print "Created $archive_path"
