#!/usr/bin/env bash
set -euo pipefail

version='0.19.2'
cache_root="${CUTLINE_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/cutline}/elm/$version"
binary="$cache_root/elm"
mkdir -p "$cache_root"

case "$(uname -s)-$(uname -m)" in
  Linux-x86_64)
    asset='elm-0.19.2-linux-x64.gz'
    expected='66320d27701654fa11bd0e8d84bdf9829694d5770c8dcee2dede6160fad58737'
    ;;
  Darwin-arm64|Darwin-aarch64)
    asset='elm-0.19.2-mac-arm.gz'
    expected='8b02a7fac1643b39acb87ae2a8e10f0f1534fe61940ca08ab17dfc2ac98115c8'
    ;;
  Darwin-x86_64)
    asset='elm-0.19.2-mac-x64.gz'
    expected='bcfbec1ee85bf87e29da23ea6cb597caa4613b74df77b4a3a40d881df1fa0410'
    ;;
  *)
    printf '%s\n' 'I found no pinned elm compiler asset for this platform' >&2
    exit 1
    ;;
esac

if [ ! -x "$binary" ] || [ "$("$binary" --version 2>/dev/null || true)" != "$version" ]; then
  archive="$(mktemp "$cache_root/elm.XXXXXX.gz")"
  trap 'rm -f "$archive"' EXIT
  curl --fail --silent --show-error --location --retry 3 \
    "https://github.com/elm/compiler/releases/download/$version/$asset" \
    --output "$archive"
  if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "$archive" | cut -d ' ' -f 1)"
  else
    actual="$(shasum -a 256 "$archive" | cut -d ' ' -f 1)"
  fi
  if [ "$actual" != "$expected" ]; then
    printf '%s\n' 'I rejected an elm archive with a mismatched checksum' >&2
    exit 1
  fi
  gzip --decompress --stdout "$archive" > "$binary"
  chmod 755 "$binary"
fi

printf '%s\n' "$binary"
