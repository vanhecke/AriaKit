#!/usr/bin/env bash
# Build libaria2 (shared) from the pinned aria2 release into a prefix.
#   ./Scripts/libaria2.sh                    install into .deps/libaria2 (default)
#   ./Scripts/libaria2.sh --prefix /usr/local
# Idempotent: exits early if <prefix>/lib/pkgconfig/libaria2.pc exists.
# Linux: no-op — install `libaria2-0-dev` with apt instead.
# macOS deps: brew install pkgconf c-ares libssh2 sqlite openssl@3
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

VERSION=1.37.0
SHA256=60a420ad7085eb616cb6e2bdf0a7206d68ff3d37fb5a956dc44242eb2f79b66b
PREFIX="$PWD/.deps/libaria2"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix) PREFIX=$2; shift 2 ;;
    -h|--help) sed -n '2,7p' "$0"; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 64 ;;
  esac
done

if [[ "$(uname -s)" != Darwin ]]; then
  exit 0
fi
if [[ -f "$PREFIX/lib/pkgconfig/libaria2.pc" ]]; then
  exit 0
fi

BREW=$(brew --prefix)
WORK="$PWD/.deps/build"
TARBALL="$WORK/aria2-$VERSION.tar.xz"
mkdir -p "$WORK"
if [[ ! -f "$TARBALL" ]]; then
  curl -fsSL -o "$TARBALL" \
    "https://github.com/aria2/aria2/releases/download/release-$VERSION/aria2-$VERSION.tar.xz"
fi
echo "$SHA256  $TARBALL" | shasum -a 256 -c - >&2
rm -rf "$WORK/aria2-$VERSION"
tar -xJf "$TARBALL" -C "$WORK"

cd "$WORK/aria2-$VERSION"
export PKG_CONFIG_PATH="$BREW/opt/openssl@3/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
export LIBS="-framework Security"
export MACOSX_DEPLOYMENT_TARGET=15.0
./configure --prefix="$PREFIX" \
  --enable-libaria2 --enable-shared --disable-static --disable-nls \
  --with-openssl --without-appletls --without-gnutls \
  --without-libgmp --without-libnettle --without-libgcrypt \
  --with-libssh2 --with-libcares --with-sqlite3 \
  >"$WORK/configure.log" 2>&1 || { tail -40 "$WORK/configure.log" >&2; exit 1; }
make -j"$(sysctl -n hw.ncpu)" >"$WORK/make.log" 2>&1 || { tail -40 "$WORK/make.log" >&2; exit 1; }
make install >"$WORK/install.log" 2>&1 || { tail -40 "$WORK/install.log" >&2; exit 1; }
echo "libaria2 $VERSION installed in $PREFIX" >&2
