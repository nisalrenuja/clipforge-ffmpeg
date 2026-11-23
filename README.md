# clipforge-ffmpeg

Reproducible **LGPL** FFmpeg builds bundled with [Clipforge](https://github.com/nisalrenuja/Clipforge) (design D6).

| Component | Version | Licence |
| --- | --- | --- |
| FFmpeg | 8.1.3 | LGPL-2.1-or-later (`--disable-gpl --disable-nonfree`) |
| openh264 | 2.7.0 | BSD-2-Clause |
| Kvazaar | 2.3.2 | BSD-3-Clause |
| SVT-AV1 | 3.1.2 | BSD-3-Clause-Clear + AOM patent licence |

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

## Windows x64

BtbN's LGPL build (with NVENC, AMF, QSV/libvpl, openh264, Kvazaar and SVT-AV1) is mirrored here, because BtbN prunes dated autobuilds. The pin lives in `versions.env` (`WIN_BTBN_*`).

```sh
./mirror-windows.sh   # verifies the BtbN SHA-256 and the LGPL + encoder flags, then writes a slim zip
```

BtbN's LGPL builds use `--enable-version3` (LGPL-3.0-or-later), which is still redistributable. Their build scripts are at <https://github.com/BtbN/FFmpeg-Builds>.

## whisper.cpp (speech-to-text)

Clipforge also bundles [whisper.cpp](https://github.com/ggml-org/whisper.cpp) (MIT) for local transcription. Unlike FFmpeg, it is built in GitHub Actions by [`build-whisper.yml`](.github/workflows/build-whisper.yml), pinned by `WHISPER_VERSION` and `WHISPER_SHA256` in `versions.env`:

| Platform | Build | GPU | Notes |
| --- | --- | --- | --- |
| Windows x64 | clang + Ninja, shared libraries | Vulkan (NVIDIA, Intel, AMD), loaded at runtime | Falls back to the CPU when the driver has no Vulkan loader. CPU variants (SSE4.2 to AVX-512) are picked at runtime. A UTF-8 code page manifest makes non-ASCII paths work. |
| macOS arm64 | static, macOS 13.0+ | Metal, library embedded | One `whisper-cli` binary that links only system libraries |

Each job smoke-tests the result by transcribing the JFK sample from a non-ASCII folder. To publish, run the workflow from the Actions tab with **release** ticked. It creates `whisper-v<version>-<revision>`. Then update `resources/whisper/manifest.json` in Clipforge.

The speech model itself (`ggml-large-v3-turbo-q5_0.bin`, MIT) is not rebuilt here. Clipforge pins it by Hugging Face commit and SHA-256.

## Releasing

Build on an Apple Silicon Mac, then:

```sh
gh release create v8.1.3-1 out/ffmpeg-8.1.3-*.{tar.xz,zip}* --title "FFmpeg 8.1.3 (LGPL)"
```

Then update `resources/ffmpeg/manifest.json` in Clipforge with the new URL and SHA-256.

Bump the pins deliberately when FFmpeg ships security fixes. FFmpeg parses untrusted media, so check <https://ffmpeg.org/security.html> at every Clipforge release.

## Notes

- Kvazaar has no ARM SIMD, so CPU HEVC on Mac is slow. VideoToolbox is the primary encoder on macOS.
- The LGPL licence does not settle H.264/HEVC patent licensing for a commercial product. That needs review before any paid Clipforge build.
