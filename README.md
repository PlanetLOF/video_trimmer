# video_trimmer

A video trimmer for Linux, macOS, and Windows, reimplemented from the GNOME
Video Trimmer. Drop in a video, set the start and end points, and trim it
without waiting for a re-encode.

## Requirements

`ffmpeg` and `ffprobe` must be on `PATH`. The app checks for both at startup
and, if either is missing, shows a page listing them with a button to re-check
after you install them.

| Platform | Install |
| --- | --- |
| Debian, Ubuntu | `sudo apt install ffmpeg` |
| Fedora | `sudo dnf install ffmpeg` |
| Arch | `sudo pacman -S ffmpeg` |
| macOS | `brew install ffmpeg` |
| Windows | `winget install Gyan.FFmpeg` |

The bundled Inter and JetBrains Mono fonts are SIL OFL 1.1; their licenses sit
next to the font files in `assets/fonts/`.

## Running

```sh
just run linux
```

or without `just`:

```sh
flutter run -d linux
```

## How trimming works

A trim is an `ffmpeg` invocation with `-ss` before `-i`, so it starts from the
earliest keyframe at or before your start point.

By default the streams are copied (`-c copy`). That is fast and lossless, but
the output cannot begin mid-GOP, so the first frame may land earlier than the
start you asked for. The **Precise** toggle re-encodes instead, which honours
the exact start and end; the encoder is `libx264` when the local `ffmpeg` has
it and `libvpx-vp9` otherwise, and an explicit video encoder is only applied to
`.mp4` and `.mkv` output. **Remove audio** adds `-an`. `.mp4` output is also
written with `+faststart`.

All streams are mapped with `-map 0` so subtitle and secondary audio tracks
survive the trim, and data streams are dropped with `-dn` because some cameras
(GoPro among them) write data streams that `ffmpeg` cannot process.

Preview playback uses `media_kit`, which is libmpv. A video can be opened from
the toolbar or dropped onto the window.

## Tasks

Recurring commands live in the `Justfile`; run `just` with no arguments to list
them. Every recipe is a thin wrapper, so the underlying command still works if
you have not got `just` installed.

| Command | Runs |
| --- | --- |
| `just analyze` | `flutter analyze` |
| `just test` | `flutter test` |
| `just fmt` | `dart format .` |
| `just fmt-check` | fails if anything is unformatted |
| `just check` | `analyze`, `fmt-check`, and `test` |
| `just run <platform>` | `flutter run -d <platform>` |
| `just build <platform>` | regenerates, then `flutter build <platform>` |
| `just clean` | `flutter clean` |

`run` and `build` take the platform as their first argument and pass everything
after it through to Flutter, so the platform reads the same way it does in a
plain `flutter` invocation:

```sh
just run windows
just build macos --profile
just build linux --debug
```

Omit the platform and it falls back to the `device` variable, which is `linux`
and can be overridden per call:

```sh
just build --debug
just device=windows run
```

## Versioning

The `version:` key in `pubspec.yaml` is the single source of truth for the app
version, which the About dialog reads. Edit it by hand, then regenerate the
Dart constant the UI displays. `just build` does that for you; on its own:

```sh
dart run tool/generate_version.dart
```

That writes `lib/generated/app_version.g.dart`. The native bundles pick the
version up from the same pubspec key on their own.

`flutter test` fails if you edit `version:` without regenerating, so the About
dialog cannot drift out of sync. The generated file is committed, so a fresh
checkout builds without a codegen step.
