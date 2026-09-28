# Video Trimmer task runner. Run `just` with no arguments to list recipes.
set shell := ["bash", "-euo", "pipefail", "-c"]

# Pass recipe parameters through as real shell arguments instead of just's
# textual `{{}}` interpolation, so a stray quote or semicolon in an argument
# is inert rather than executed.
set positional-arguments

# Default platform for `run` and `build`, used when the first argument is a
# flag rather than a platform. Override per call: `just device=windows build`.
device := "linux"

# List the available recipes.
[doc('List the available recipes')]
default:
    @just --list

# Run the static analyzer.
[doc('Run flutter analyze')]
[group('check')]
analyze:
    @flutter analyze

# Run the test suite.
[doc('Run flutter test')]
[group('check')]
test:
    @flutter test

# Format the Dart sources in place.
[doc('Format the Dart sources')]
[group('check')]
fmt:
    @dart format .

# Fail if any Dart source is unformatted, without writing.
[doc('Check formatting without writing')]
[group('check')]
fmt-check:
    @dart format --output=none --set-exit-if-changed .

# Run every read-only check.
[doc('Run analyze, format check, and tests')]
[group('check')]
check: analyze fmt-check test

# Run the app. The first argument is the platform; anything after it passes
# through to `flutter run`.
#
# The trailing "$@" must stay "$@" and not become "$*": with no positional
# parameters "$*" expands to a single empty word, so `just run` would pass an
# empty device name, and an argument containing a space would arrive joined
# to its neighbours. No test covers this, so it is easy to undo by accident.
[doc('Run the app on a platform')]
[group('dev')]
run *args:
    @platform="{{ device }}" \
    && if [[ -n "${1:-}" && "$1" != -* ]]; then platform="$1"; shift; fi \
    && flutter run -d "$platform" "$@"

# Build a bundle, regenerating the generated sources first so a bundle is
# never built from a stale app_version.g.dart. The first argument is the
# platform; anything after it passes through to `flutter build`, which
# defaults to release.
#
# The trailing "$@" must stay "$@" and not become "$*"; see the note on
# `run` above for why.
[doc('Build the app, regenerating generated sources first')]
[group('build')]
build *args:
    @dart run tool/generate_version.dart \
    && platform="{{ device }}" \
    && if [[ -n "${1:-}" && "$1" != -* ]]; then platform="$1"; shift; fi \
    && flutter build "$platform" "$@"

# Delete build output and the ephemeral plugin directories.
[doc('Delete build output')]
[group('build')]
clean:
    @flutter clean
