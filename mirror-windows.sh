#!/usr/bin/env bash
# Mirror a pinned BtbN Windows x64 LGPL FFmpeg build as a slim, checksummed archive.
#   ./mirror-windows.sh      -> out/ffmpeg-<ver>-windows-x64.zip (+ .sha256)
# Needs: gh (authenticated), unzip, zip, strings.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=versions.env
source "$HERE/versions.env"
WORK="$HERE/work/win"; OUT="$HERE/out"; mkdir -p "$WORK" "$OUT"

[[ -f "$WORK/$WIN_BTBN_ASSET" ]] || gh release download "$WIN_BTBN_TAG" --repo BtbN/FFmpeg-Builds \
  --pattern "$WIN_BTBN_ASSET" --dir "$WORK"
got="$(shasum -a 256 "$WORK/$WIN_BTBN_ASSET" | cut -d' ' -f1)"
[[ "$got" == "$WIN_BTBN_SHA256" ]] || { echo "SHA-256 mismatch: $got" >&2; exit 1; }

rm -rf "$WORK/x"; mkdir -p "$WORK/x"; unzip -q "$WORK/$WIN_BTBN_ASSET" -d "$WORK/x"
SRC="$(dirname "$(find "$WORK/x" -name ffmpeg.exe | head -1)")/.."
strings "$SRC/bin/ffmpeg.exe" > "$WORK/strings.txt"   # avoid SIGPIPE under pipefail
CONF="$(grep -m1 -- '--enable-' "$WORK/strings.txt")"
if grep -qE -- '--enable-(gpl|nonfree)( |$)' <<<"$CONF"; then echo "not LGPL" >&2; exit 1; fi
for lib in libopenh264 libkvazaar libsvtav1 amf ffnvcodec libvpl; do
  grep -q -- "--enable-$lib" <<<"$CONF" || { echo "missing --enable-$lib" >&2; exit 1; }
done

NAME="ffmpeg-$FFMPEG_VERSION-windows-x64"
STAGE="$WORK/$NAME"; rm -rf "$STAGE"; mkdir -p "$STAGE"
cp "$SRC/bin/ffmpeg.exe" "$SRC/bin/ffprobe.exe" "$STAGE/"
cp "$SRC/LICENSE.txt" "$STAGE/LICENSE-FFmpeg.txt"
{
  echo "Clipforge mirror of a BtbN FFmpeg Windows x64 LGPL build"
  echo "Source: https://github.com/BtbN/FFmpeg-Builds/releases/tag/$WIN_BTBN_TAG"
  echo "Asset:  $WIN_BTBN_ASSET  sha256=$WIN_BTBN_SHA256"
  echo "Build scripts and component sources: https://github.com/BtbN/FFmpeg-Builds"
  echo; echo "configuration: $CONF"
} > "$STAGE/BUILDINFO.txt"
rm -f "$OUT/$NAME.zip"; (cd "$WORK" && zip -qr -X "$OUT/$NAME.zip" "$NAME")
(cd "$OUT" && shasum -a 256 "$NAME.zip" > "$NAME.zip.sha256")
cat "$OUT/$NAME.zip.sha256"
