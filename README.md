# clipforge-ffmpeg

Reproducible **LGPL** FFmpeg builds bundled with [Clipforge](https://github.com/nisalrenuja/Clipforge) (design D6).

| Component | Version | Licence |
| --- | --- | --- |
| FFmpeg | 7.1.5 | LGPL-2.1-or-later (`--disable-gpl --disable-nonfree`) |
| openh264 | 2.7.0 | BSD-2-Clause |
| Kvazaar | 2.3.2 | BSD-3-Clause |
| SVT-AV1 | 2.3.0 | BSD-3-Clause-Clear + AOM patent licence |

Versions and source SHA-256 checksums are pinned in [`versions.env`](versions.env).

## macOS arm64

```sh
uv tool install cmake ninja pkgconf   # or any cmake/ninja/pkg-config
./build-macos.sh
```

The output goes to `out/ffmpeg-<ver>-macos-arm64.tar.xz`, with a `.sha256` file next to it. The build:

- links all third-party libraries statically (only Apple system frameworks are dynamic)
- targets macOS 13.0 at minimum
- includes VideoToolbox, openh264, Kvazaar and SVT-AV1
- has no network protocols, ffplay or docs
- fails if the result is not LGPL or links non-system dynamic libraries

## Releasing

Build on an Apple Silicon Mac, then:

```sh
gh release create v7.1.5-1 out/ffmpeg-7.1.5-macos-arm64.tar.xz out/ffmpeg-7.1.5-macos-arm64.tar.xz.sha256 \
  --title "FFmpeg 7.1.5 (macOS arm64, LGPL)" --notes-file work/ffmpeg-7.1.5-macos-arm64/BUILDINFO.txt
```

Then update `resources/ffmpeg/manifest.json` in Clipforge with the new URL and SHA-256.

Bump the pins deliberately when FFmpeg ships security fixes. FFmpeg parses untrusted media, so check <https://ffmpeg.org/security.html> at every Clipforge release.

## Notes

- Kvazaar has no ARM SIMD, so CPU HEVC on Mac is slow. VideoToolbox is the primary encoder on macOS.
- The LGPL licence does not settle H.264/HEVC patent licensing for a commercial product. That needs review before any paid Clipforge build.
