#!/usr/bin/env bash
set -euo pipefail

version='2.6.0'
cache_root="${CUTLINE_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/cutline}"
binary="$cache_root/bin/opam"
mkdir -p "$cache_root/bin"

case "$(uname -s)-$(uname -m)" in
  Linux-x86_64)
    asset='opam-2.6.0-x86_64-linux'
    expected='a59184447f881005dae70b2ae455c3a7e9549834a41c635c49a5a28235eca758'
    ;;
  Darwin-arm64|Darwin-aarch64)
    asset='opam-2.6.0-arm64-macos'
    expected='b57ed6cc082e560063989a285c59786b7c670087da2d317a87e4ba4c7973e71f'
    ;;
  Darwin-x86_64)
    asset='opam-2.6.0-x86_64-macos'
    expected='ebf457f96860d7e89e3aa68a8cbee6c8a8569a8f9677918fcf15c29e1873b072'
    ;;
  *)
    printf '%s\n' 'I found no pinned opam binary for this platform' >&2
    exit 1
    ;;
esac

if [ ! -x "$binary" ] || [ "$("$binary" --version 2>/dev/null || true)" != "$version" ]; then
  temporary="$cache_root/bin/opam.temporary"
  curl --fail --silent --show-error --location --retry 3 \
    "https://github.com/ocaml/opam/releases/download/$version/$asset" \
    --output "$temporary"
  if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "$temporary" | cut -d ' ' -f 1)"
  else
    actual="$(shasum -a 256 "$temporary" | cut -d ' ' -f 1)"
  fi
  if [ "$actual" != "$expected" ]; then
    rm -f "$temporary"
    printf '%s\n' 'I rejected an opam binary with a mismatched checksum' >&2
    exit 1
  fi
  mv "$temporary" "$binary"
  chmod 755 "$binary"
fi

printf '%s\n' "$binary"
