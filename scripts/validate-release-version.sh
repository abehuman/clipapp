#!/bin/zsh

set -euo pipefail

if (( $# < 1 || $# > 2 )); then
  print -u2 "Usage: $0 v<major>.<minor>.<patch> [baseline-appcast]"
  exit 64
fi

release_tag=$1
project_root=${0:A:h:h}
configuration=$project_root/Configurations/ClipApp.xcconfig
appcast=${2:-$project_root/docs/appcast.xml}

if [[ $release_tag != v<->.<->.<-> ]]; then
  print -u2 "Release tag must use the v<major>.<minor>.<patch> format: $release_tag"
  exit 65
fi

version=${release_tag#v}

configuration_value() {
  local key=$1
  awk -F= -v key="$key" '
    $1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
      value = $2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      print value
      exit
    }
  ' "$configuration"
}

marketing_version=$(configuration_value MARKETING_VERSION)
build_version=$(configuration_value CURRENT_PROJECT_VERSION)

if [[ $marketing_version != $version || $build_version != $version ]]; then
  print -u2 "Release tag $release_tag does not match ClipApp.xcconfig."
  print -u2 "MARKETING_VERSION=$marketing_version CURRENT_PROJECT_VERSION=$build_version"
  exit 65
fi

if [[ -e $appcast && ! -f $appcast ]]; then
  print -u2 "Baseline appcast is not a regular file: $appcast"
  exit 66
fi

if [[ -f $appcast ]]; then
  published_version=$(
    xmllint --xpath \
      'string(/*[local-name()="rss"]/*[local-name()="channel"]/*[local-name()="item"][1]/*[local-name()="shortVersionString"])' \
      "$appcast"
  )

  if [[ -n $published_version ]]; then
    if [[ $published_version != <->.<->.<-> ]]; then
      print -u2 "Latest appcast version is not semantic: $published_version"
      exit 65
    fi

    typeset -a candidate_parts published_parts
    candidate_parts=("${(@s:.:)version}")
    published_parts=("${(@s:.:)published_version}")

    if ! ((
      candidate_parts[1] > published_parts[1] ||
      (candidate_parts[1] == published_parts[1] && candidate_parts[2] > published_parts[2]) ||
      (candidate_parts[1] == published_parts[1] && candidate_parts[2] == published_parts[2] && candidate_parts[3] > published_parts[3])
    )); then
      print -u2 "Release version $version must be newer than appcast version $published_version."
      exit 65
    fi
  fi
fi

print -r -- "$version"
