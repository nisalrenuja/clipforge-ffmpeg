#!/usr/bin/env bash
# Reproducible LGPL FFmpeg build for macOS arm64 (Clipforge, design D6).
#
#   ./build-macos.sh            # builds into ./out/ffmpeg-<ver>-macos-arm64.tar.xz
#
# Needs: Xcode CLT, cmake, ninja, pkg-config (e.g. `uv tool install cmake ninja pkgconf`).
# Static third-party libs; only Apple system frameworks are linked dynamically.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=versions.env
source "$HERE/versions.env"

[[ "$(uname -s)" == Darwin && "$(uname -m)" == arm64 ]] || { echo "run on Apple Silicon macOS" >&2; exit 1; }

WORK="$HERE/work"; SRC="$WORK/src"; PREFIX="$WORK/prefix"; OUT="$HERE/out"
JOBS="$(sysctl -n hw.ncpu)"
rm -rf "$PREFIX"; mkdir -p "$SRC" "$PREFIX" "$OUT"

export MACOSX_DEPLOYMENT_TARGET="$MACOS_MIN"
export CFLAGS="-mmacosx-version-min=$MACOS_MIN -O2"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-mmacosx-version-min=$MACOS_MIN"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"
export PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig"   # never pick up host .pc files

fetch() { # url file expected_sha256 var_name
  local url="$1" file="$SRC/$2" sha="$3" var="$4"
  [[ -f "$file" ]] || curl -fL --retry 3 -o "$file" "$url"
  local got; got="$(shasum -a 256 "$file" | cut -d' ' -f1)"
  if [[ -z "$sha" ]]; then
    echo "WARNING: $var not pinned; computed $got (record it in versions.env)" >&2
  elif [[ "$got" != "$sha" ]]; then
    echo "SHA-256 mismatch for $file: expected $sha got $got" >&2; exit 1
  fi
}

unpack() { rm -rf "$SRC/$2"; mkdir -p "$SRC/$2"; tar -xf "$SRC/$1" -C "$SRC/$2" --strip-components=1; }

# --- openh264 (BSD-2) -------------------------------------------------------------
fetch "https://github.com/cisco/openh264/archive/refs/tags/v$OPENH264_VERSION.tar.gz" \
  "openh264-$OPENH264_VERSION.tar.gz" "$OPENH264_SHA256" OPENH264_SHA256
unpack "openh264-$OPENH264_VERSION.tar.gz" openh264
make -C "$SRC/openh264" -j"$JOBS" OS=darwin ARCH=arm64 PREFIX="$PREFIX" \
  CFLAGS_OPT="$CFLAGS" LDFLAGS="$LDFLAGS" install-static

# --- kvazaar (BSD-3) --------------------------------------------------------------
fetch "https://github.com/ultravideo/kvazaar/archive/refs/tags/v$KVAZAAR_VERSION.tar.gz" \
  "kvazaar-$KVAZAAR_VERSION.tar.gz" "$KVAZAAR_SHA256" KVAZAAR_SHA256
unpack "kvazaar-$KVAZAAR_VERSION.tar.gz" kvazaar
cmake -S "$SRC/kvazaar" -B "$SRC/kvazaar/build" -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" -DCMAKE_OSX_DEPLOYMENT_TARGET="$MACOS_MIN" \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTS=OFF
cmake --build "$SRC/kvazaar/build" -j"$JOBS"
cmake --install "$SRC/kvazaar/build"

# --- SVT-AV1 (BSD-3-Clause-Clear + AOM patent licence) ----------------------------
fetch "https://gitlab.com/AOMediaCodec/SVT-AV1/-/archive/v$SVTAV1_VERSION/SVT-AV1-v$SVTAV1_VERSION.tar.gz" \
  "svtav1-$SVTAV1_VERSION.tar.gz" "$SVTAV1_SHA256" SVTAV1_SHA256
unpack "svtav1-$SVTAV1_VERSION.tar.gz" svtav1
cmake -S "$SRC/svtav1" -B "$SRC/svtav1/build" -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_OSX_DEPLOYMENT_TARGET="$MACOS_MIN" \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DBUILD_SHARED_LIBS=OFF -DBUILD_APPS=OFF -DBUILD_DEC=OFF -DBUILD_TESTING=OFF
cmake --build "$SRC/svtav1/build" -j"$JOBS"
cmake --install "$SRC/svtav1/build"

# --- FFmpeg (LGPL-2.1-or-later) ---------------------------------------------------
fetch "https://ffmpeg.org/releases/ffmpeg-$FFMPEG_VERSION.tar.xz" \
  "ffmpeg-$FFMPEG_VERSION.tar.xz" "$FFMPEG_SHA256" FFMPEG_SHA256
unpack "ffmpeg-$FFMPEG_VERSION.tar.xz" ffmpeg
cd "$SRC/ffmpeg"
./configure \
  --prefix="$PREFIX" \
  --pkg-config=pkg-config --pkg-config-flags=--static \
  --extra-cflags="$CFLAGS -I$PREFIX/include" --extra-ldflags="$LDFLAGS -L$PREFIX/lib" \
  --extra-libs="-lc++" \
  --disable-gpl --disable-nonfree --disable-autodetect \
  --disable-shared --enable-static \
  --disable-doc --disable-ffplay --disable-network --disable-debug \
  --enable-videotoolbox --enable-audiotoolbox --enable-zlib \
  --enable-libopenh264 --enable-libkvazaar --enable-libsvtav1
make -j"$JOBS"
make install

# --- package ----------------------------------------------------------------------
NAME="ffmpeg-$FFMPEG_VERSION-macos-arm64"
STAGE="$WORK/$NAME"; rm -rf "$STAGE"; mkdir -p "$STAGE"
cp "$PREFIX/bin/ffmpeg" "$PREFIX/bin/ffprobe" "$STAGE/"
strip -x "$STAGE/ffmpeg" "$STAGE/ffprobe"
cp "$SRC/ffmpeg/COPYING.LGPLv2.1" "$STAGE/LICENSE-FFmpeg-LGPL-2.1.txt"
cp "$SRC/openh264/LICENSE" "$STAGE/LICENSE-openh264.txt"
cp "$SRC/kvazaar/LICENSE" "$STAGE/LICENSE-kvazaar.txt"
cp "$SRC/svtav1/LICENSE.md" "$STAGE/LICENSE-SVT-AV1.md"
cp "$SRC/svtav1/PATENTS.md" "$STAGE/PATENTS-SVT-AV1.md"
{
  echo "Clipforge LGPL FFmpeg build for macOS arm64 (min macOS $MACOS_MIN)"
  echo "FFmpeg $FFMPEG_VERSION  https://ffmpeg.org/releases/ffmpeg-$FFMPEG_VERSION.tar.xz"
  echo "openh264 $OPENH264_VERSION  https://github.com/cisco/openh264"
  echo "kvazaar $KVAZAAR_VERSION  https://github.com/ultravideo/kvazaar"
  echo "SVT-AV1 $SVTAV1_VERSION  https://gitlab.com/AOMediaCodec/SVT-AV1"
  echo "Build script: https://github.com/nisalrenuja/clipforge-ffmpeg"
  echo; "$STAGE/ffmpeg" -hide_banner -buildconf
} > "$STAGE/BUILDINFO.txt"

# Licence gate (same check as Clipforge's fetch script).
if "$STAGE/ffmpeg" -hide_banner -buildconf | grep -qE -- '--enable-(gpl|nonfree)'; then
  echo "build is not LGPL" >&2; exit 1
fi
# Only system libraries/frameworks may be dynamically linked.
if otool -L "$STAGE/ffmpeg" | tail -n +2 | grep -vE '^\s+(/usr/lib/|/System/Library/)'; then
  echo "unexpected non-system dynamic dependency" >&2; exit 1
fi

tar -C "$WORK" -cJf "$OUT/$NAME.tar.xz" "$NAME"
( cd "$OUT" && shasum -a 256 "$NAME.tar.xz" > "$NAME.tar.xz.sha256" )
cat "$OUT/$NAME.tar.xz.sha256"
