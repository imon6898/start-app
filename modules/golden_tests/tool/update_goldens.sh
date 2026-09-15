#!/usr/bin/env bash
# Regenerates the golden PNGs under test/golden/goldens/<os>/ for THIS machine.
# Goldens are platform-specific rasterisations — a set written on macOS will not
# match one written on Linux. Generate and verify on the same OS.
#
#   tool/update_goldens.sh                       # everything
#   tool/update_goldens.sh test/golden/buttons_golden_test.dart
set -euo pipefail

cd "$(dirname "$0")/.."

TARGET="${1:-test/golden}"
OS="$(uname -s)"
case "$OS" in
  Darwin) DIR=macos ;;
  Linux)  DIR=linux ;;
  *)      DIR="$(echo "$OS" | tr '[:upper:]' '[:lower:]')" ;;
esac

echo "Updating goldens for $DIR (from $OS)"
echo "Target: $TARGET"
echo

# --update-goldens writes instead of comparing; it never fails on a diff.
flutter test --update-goldens "$TARGET"

echo
echo "Wrote test/golden/goldens/$DIR/. Review every changed PNG before committing:"
git status --short test/golden || true
echo
echo "A golden you did not mean to change is a real regression. Open the image."
