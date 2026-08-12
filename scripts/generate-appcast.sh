#!/bin/zsh

set -euo pipefail

if (( $# < 2 || $# > 3 )); then
  print -u2 "Usage: $0 /path/to/update-archives <version> [source-packages-directory]"
  exit 64
fi

archives_directory=${1:A}
version=$2
project_root=${0:A:h:h}
source_packages_directory=${3:-$project_root/build/SourcePackages}
generate_appcast=${source_packages_directory:A}/artifacts/sparkle/Sparkle/bin/generate_appcast
canonical_appcast=$project_root/docs/appcast.xml
working_appcast=$archives_directory/appcast.xml
update_archive=$archives_directory/ClipApp-${version}.zip
download_url=https://github.com/abehuman/clipapp/releases/download/v${version}/

if [[ ! -d "$archives_directory" ]]; then
  print -u2 "Update archives directory was not found: $archives_directory"
  exit 72
fi

if [[ ! -f "$update_archive" ]]; then
  print -u2 "Update archive was not found: $update_archive"
  exit 66
fi

distribution_archives=("$archives_directory"/*-distribution.zip(N))
if (( ${#distribution_archives} > 0 )); then
  print -u2 "Keep distribution ZIPs outside the Sparkle archives directory."
  exit 65
fi

if [[ ! -x "$generate_appcast" ]]; then
  xcodebuild -resolvePackageDependencies \
    -project "$project_root/ClipApp.xcodeproj" \
    -scheme ClipApp \
    -clonedSourcePackagesDirPath "${source_packages_directory:A}"
fi

if [[ ! -x "$generate_appcast" ]]; then
  print -u2 "Sparkle generate_appcast was not found: $generate_appcast"
  exit 69
fi

# Reuse the canonical signed feed so older releases and deltas remain available.
if [[ -f "$canonical_appcast" && "$canonical_appcast" != "$working_appcast" ]]; then
  cp "$canonical_appcast" "$working_appcast"
fi

(
  cd "$archives_directory"
  "$generate_appcast" \
    --account jp.co.aiv.clipApp \
    --download-url-prefix "$download_url" \
    --link https://github.com/abehuman/clipapp \
    -o appcast.xml \
    .
)

cp "$working_appcast" "$canonical_appcast"
print "Updated $canonical_appcast"
