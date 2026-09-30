# Video Trimmer task runner. Run `just` with no arguments to list recipes.
set shell := ["bash", "-euo", "pipefail", "-c"]
set positional-arguments

# Default platform for `run` and `build`, derived from the current OS.
# Override per call: `just device=windows build`
device := os()

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

# Run the app. First arg = platform (default: current OS), rest passed to `flutter run`.
[doc('Run the app on a platform')]
[group('dev')]
run platform=os() *args:
    @flutter run -d "{{ platform }}" {{ args }}

# Build the app, regenerating generated sources first.
# First arg = platform (default: current OS), rest passed to `flutter build`.
[doc('Build the app, regenerating generated sources first')]
[group('build')]
build platform=os() *args:
    @dart run tool/generate_version.dart
    @flutter build "{{ platform }}" {{ args }}

# Get Flutter pub dependencies.
[doc('Get Flutter Pub')]
[group('build')]
get:
    @flutter pub get

# Upgrade Flutter pub dependencies.
[doc('Upgrade Flutter Pub')]
[group('build')]
up:
    @flutter pub upgrade

# Delete build output and ephemeral plugin directories.
[doc('Delete build output')]
[group('build')]
clean:
    @flutter clean

# Verify Flutter environment.
[doc('Run flutter doctor')]
[group('check')]
doctor:
    @flutter doctor -v

# Ensure Flutter is installed.
[doc('Ensure Flutter is installed')]
[group('build')]
install:
    @command -v flutter >/dev/null || { echo "Flutter not found. Install via https://flutter.dev"; exit 1; }

# Show version info.
[doc('Show Flutter and Dart versions')]
version:
    @flutter --version
    @dart --version