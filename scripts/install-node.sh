#!/usr/bin/env bash
set -euo pipefail

version='22.23.3'
cache_root="${CUTLINE_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/cutline}"
install_root="$cache_root/node/$version"
binary="$install_root/bin/node"

case "$(uname -s)-$(uname -m)" in
  Linux-x86_64)
    platform='linux-x64'
    asset="node-v$version-linux-x64.tar.xz"
    expected='df450af89261115ef9f9e3830c3eeb2cc9213b63c720b1af623cb5dcbe2e02de'
    ;;
  Darwin-arm64|Darwin-aarch64)
    platform='darwin-arm64'
    asset="node-v$version-darwin-arm64.tar.xz"
    expected='72d5d8832b41c9d9646197af614ffd751406ea4d215060eb91b98864e1919a3e'
    ;;
  Darwin-x86_64)
    platform='darwin-x64'
    asset="node-v$version-darwin-x64.tar.xz"
    expected='ac41874c3352937119cfec39e1a98c578fe58ce8a86d7e785b89a4706015f305'
    ;;
  *)
    printf '%s\n' 'I found no pinned Node archive for this platform' >&2
    exit 1
    ;;
esac

if [ ! -x "$binary" ] || [ "$("$binary" --version 2>/dev/null || true)" != "v$version" ]; then
  mkdir -p "$cache_root/node"
  archive="$(mktemp "$cache_root/node/node.XXXXXX.tar.xz")"
  unpacked="$(mktemp -d "$cache_root/node/unpack.XXXXXX")"
  trap 'rm -f "$archive"; rm -rf "$unpacked"' EXIT
  curl --fail --silent --show-error --location --retry 3 \
    "https://nodejs.org/dist/v$version/$asset" \
    --output "$archive"
  if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "$archive" | cut -d ' ' -f 1)"
  else
    actual="$(shasum -a 256 "$archive" | cut -d ' ' -f 1)"
  fi
  if [ "$actual" != "$expected" ]; then
    printf '%s\n' 'I rejected a Node archive with a mismatched checksum' >&2
    exit 1
  fi
  tar -xJf "$archive" -C "$unpacked"
  rm -rf "$install_root"
  mv "$unpacked/node-v$version-$platform" "$install_root"
  trap 'rm -f "$archive"' EXIT
fi

printf '%s\n' "$binary"
