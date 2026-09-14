#!/usr/bin/env bash
#
# Rename this starter template into a new project.
#
#   ./rename_project.sh <package_name> <bundle.id> [--dry-run] [--name "Display Name"]
#
# Rewrites: pubspec name, every `package:<old>/` import, Android namespace/applicationId/label,
# the Kotlin package directory and its `package` line, all iOS PRODUCT_BUNDLE_IDENTIFIERs,
# Info.plist CFBundleName/CFBundleDisplayName, and the README title.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

DRY_RUN=0
NEW_PKG=""
NEW_BUNDLE=""
DISPLAY_NAME=""
ARG_COUNT=0
CHANGES=""

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
bold()  { printf '\033[1m%s\033[0m\n' "$*"; }
dim()   { printf '\033[2m%s\033[0m\n' "$*"; }
die()   { red "error: $*"; exit 1; }
note()  { CHANGES="${CHANGES}${1}"$'\n'; }

usage() {
  cat <<'EOF'
Usage: ./rename_project.sh <package_name> <bundle.id> [options]

Arguments:
  package_name   Dart package name: lowercase_with_underscores, starts with a letter.
  bundle.id      Reverse-DNS bundle/application id, e.g. com.mycompany.myapp

Options:
  --dry-run, -n      Print the plan, write nothing.
  --name "My App"    Display name for the Android label and iOS CFBundleDisplayName.
                     Defaults to the package name in Title Case.
  -h, --help         This message.

Examples:
  ./rename_project.sh --dry-run my_app com.mycompany.myapp
  ./rename_project.sh my_app com.mycompany.myapp --name "My App"
EOF
}

# Flags may appear before or after the positional arguments.
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run|-n) DRY_RUN=1; shift ;;
    --name) [[ $# -ge 2 ]] || die "--name needs a value"; DISPLAY_NAME="$2"; shift 2 ;;
    --name=*) DISPLAY_NAME="${1#*=}"; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) die "unknown option: $1" ;;
    *)
      ARG_COUNT=$((ARG_COUNT + 1))
      case $ARG_COUNT in
        1) NEW_PKG="$1" ;;
        2) NEW_BUNDLE="$1" ;;
        *) die "too many arguments (got '$1')" ;;
      esac
      shift ;;
  esac
done

[[ $ARG_COUNT -eq 2 ]] || { usage; exit 1; }

# --- validate ---------------------------------------------------------------

[[ "$NEW_PKG" =~ ^[a-z][a-z0-9_]*$ ]] \
  || die "package name '$NEW_PKG' must be lowercase_with_underscores and start with a letter"
[[ "$NEW_PKG" != *__* ]] || die "package name '$NEW_PKG' must not contain a double underscore"
[[ "$NEW_PKG" != *_ ]]   || die "package name '$NEW_PKG' must not end with an underscore"

DART_RESERVED=" abstract as assert async await break case catch class const continue covariant default deferred do dynamic else enum export extends extension external factory false final finally for get hide if implements import in interface is late library mixin new null on operator part required rethrow return set show static super switch sync this throw true try typedef var void while with yield "
[[ "$DART_RESERVED" != *" $NEW_PKG "* ]] || die "'$NEW_PKG' is a Dart reserved word"

[[ "$NEW_BUNDLE" =~ ^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$ ]] \
  || die "bundle id '$NEW_BUNDLE' must be reverse-DNS, e.g. com.mycompany.myapp"

# Java/Kotlin keywords are illegal as Android package segments.
JAVA_RESERVED=" abstract assert boolean break byte case catch char class const continue default do double else enum extends final finally float for goto if implements import instanceof int interface long native new package private protected public return short static strictfp super switch synchronized this throw throws transient try void volatile while "
IFS='.' read -r -a BUNDLE_SEGMENTS <<< "$NEW_BUNDLE"
for seg in "${BUNDLE_SEGMENTS[@]}"; do
  [[ "$JAVA_RESERVED" != *" $seg "* ]] || die "bundle segment '$seg' is a Java/Kotlin keyword"
done

if [[ -z "$DISPLAY_NAME" ]]; then
  DISPLAY_NAME="$(printf '%s' "$NEW_PKG" | tr '_' ' ' \
    | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1')"
fi
[[ "$DISPLAY_NAME" != *'"'* ]] || die "display name must not contain a double quote"

# --- discover the current identifiers ---------------------------------------

[[ -f pubspec.yaml ]] || die "pubspec.yaml not found — run this from the project root"
OLD_PKG="$(awk '/^name:[[:space:]]/ { gsub(/["'\'']/, "", $2); print $2; exit }' pubspec.yaml)"
[[ -n "$OLD_PKG" ]] || die "could not read 'name:' from pubspec.yaml"

GRADLE="android/app/build.gradle.kts"
[[ -f "$GRADLE" ]] || GRADLE="android/app/build.gradle"
[[ -f "$GRADLE" ]] || die "android app gradle file not found"
OLD_BUNDLE="$(sed -n 's/^[[:space:]]*namespace[[:space:]]*=*[[:space:]]*["'\'']\([^"'\'']*\)["'\''].*/\1/p' "$GRADLE" | head -1)"
[[ -n "$OLD_BUNDLE" ]] || die "could not read the android namespace from $GRADLE"

if [[ "$OLD_PKG" == "$NEW_PKG" && "$OLD_BUNDLE" == "$NEW_BUNDLE" ]]; then
  green "Nothing to do — already named '$NEW_PKG' / '$NEW_BUNDLE'."
  exit 0
fi

bold "Rename plan"
printf '  package  %s  ->  %s\n' "$OLD_PKG" "$NEW_PKG"
printf '  bundle   %s  ->  %s\n' "$OLD_BUNDLE" "$NEW_BUNDLE"
printf '  display  %s\n' "$DISPLAY_NAME"
[[ $DRY_RUN -eq 1 ]] && dim "  (dry run — nothing will be written)"
echo

# In-place sed that works on BSD and GNU and keeps the file's permissions.
# Returns 0 only when the expression actually changes something.
sub() {
  local expr="$1" file="$2" tmp
  [[ -f "$file" ]] || return 1
  tmp="$(mktemp)"
  sed "$expr" "$file" > "$tmp"
  if cmp -s "$tmp" "$file"; then rm -f "$tmp"; return 1; fi
  [[ $DRY_RUN -eq 0 ]] && cat "$tmp" > "$file"
  rm -f "$tmp"
  return 0
}

# --- 1. pubspec name --------------------------------------------------------

sub "1,20s/^name:[[:space:]].*/name: $NEW_PKG/" pubspec.yaml \
  && note "pubspec.yaml         name: $NEW_PKG"

# --- 2. package: imports ----------------------------------------------------

SEARCH_DIRS=""
for d in lib test tool modules integration_test; do
  [[ -d "$d" ]] && SEARCH_DIRS="$SEARCH_DIRS $d"
done

IMPORT_COUNT=0
if [[ -n "$SEARCH_DIRS" ]]; then
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    grep -q "package:$OLD_PKG/" "$f" 2>/dev/null || continue
    sub "s|package:$OLD_PKG/|package:$NEW_PKG/|g" "$f" && IMPORT_COUNT=$((IMPORT_COUNT + 1))
  done < <(find $SEARCH_DIRS -type f \( -name '*.dart' -o -name '*.md' -o -name '*.yaml' \))
fi
[[ $IMPORT_COUNT -gt 0 ]] && note "package: imports     $IMPORT_COUNT file(s) rewritten"

# --- 3. android namespace + applicationId -----------------------------------

sub "s|$OLD_BUNDLE|$NEW_BUNDLE|g" "$GRADLE" \
  && note "$GRADLE   namespace + applicationId"

# --- 4. kotlin package dir + declaration ------------------------------------

OLD_KT_PATH="$(printf '%s' "$OLD_BUNDLE" | tr '.' '/')"
NEW_KT_PATH="$(printf '%s' "$NEW_BUNDLE" | tr '.' '/')"
KT_SRC="android/app/src/main/kotlin"

if [[ -d "$KT_SRC/$OLD_KT_PATH" ]]; then
  while IFS= read -r kt; do
    [[ -n "$kt" ]] || continue
    sub "s|^package $OLD_BUNDLE$|package $NEW_BUNDLE|" "$kt" \
      && note "$(basename "$kt")       package $NEW_BUNDLE"
  done < <(find "$KT_SRC/$OLD_KT_PATH" -name '*.kt')

  if [[ "$OLD_KT_PATH" != "$NEW_KT_PATH" ]]; then
    note "kotlin sources       $KT_SRC/$OLD_KT_PATH -> $KT_SRC/$NEW_KT_PATH"
    if [[ $DRY_RUN -eq 0 ]]; then
      mkdir -p "$KT_SRC/$NEW_KT_PATH"
      find "$KT_SRC/$OLD_KT_PATH" -maxdepth 1 -name '*.kt' -exec mv {} "$KT_SRC/$NEW_KT_PATH/" \;
      # Walk the old package dirs back up, deleting each while it is still empty.
      (cd "$KT_SRC" && rmdir -p "$OLD_KT_PATH" 2>/dev/null || true)
    fi
  fi
fi

# --- 5. android label -------------------------------------------------------

MANIFEST="android/app/src/main/AndroidManifest.xml"
sub "s|android:label=\"[^\"]*\"|android:label=\"$DISPLAY_NAME\"|" "$MANIFEST" \
  && note "AndroidManifest.xml  android:label=\"$DISPLAY_NAME\""

# --- 6. ios bundle ids (main app + every test target) -----------------------

PBX="ios/Runner.xcodeproj/project.pbxproj"
if [[ -f "$PBX" ]]; then
  PBX_HITS="$(grep -c "PRODUCT_BUNDLE_IDENTIFIER = $OLD_BUNDLE" "$PBX" || true)"
  # Suffixed ids such as <bundle>.RunnerTests are covered by the same substitution.
  sub "s|PRODUCT_BUNDLE_IDENTIFIER = $OLD_BUNDLE|PRODUCT_BUNDLE_IDENTIFIER = $NEW_BUNDLE|g" "$PBX" \
    && note "project.pbxproj      $PBX_HITS PRODUCT_BUNDLE_IDENTIFIER entries"
fi

# --- 7. ios Info.plist names ------------------------------------------------

PLIST="ios/Runner/Info.plist"
if [[ -f "$PLIST" ]]; then
  sub "/<key>CFBundleDisplayName<\/key>/{n;s|<string>.*</string>|<string>$DISPLAY_NAME</string>|;}" "$PLIST" \
    && note "Info.plist           CFBundleDisplayName = $DISPLAY_NAME"
  sub "/<key>CFBundleName<\/key>/{n;s|<string>.*</string>|<string>$NEW_PKG</string>|;}" "$PLIST" \
    && note "Info.plist           CFBundleName = $NEW_PKG"
fi

# --- 8. README title --------------------------------------------------------

sub "1s|^# .*|# $DISPLAY_NAME|" README.md \
  && note "README.md            title -> $DISPLAY_NAME"

# --- 9. stale IDE module file ----------------------------------------------

for iml in ./*.iml; do
  [[ -e "$iml" ]] || continue
  note "${iml#./}         stale IDE file, removed"
  [[ $DRY_RUN -eq 0 ]] && rm -f "$iml"
done

# --- summary ----------------------------------------------------------------

bold "Summary"
if [[ -z "$CHANGES" ]]; then
  dim "  no changes"
else
  printf '%s' "$CHANGES" | while IFS= read -r line; do
    [[ -n "$line" ]] && printf '  * %s\n' "$line"
  done
fi
echo

if [[ $DRY_RUN -eq 1 ]]; then
  dim "Dry run — nothing was written. Re-run without --dry-run to apply."
else
  green "Done."
  bold "Next:"
  echo "  flutter clean && flutter pub get"
  echo "  (cd ios && pod install)"
  echo "  flutter analyze"
fi
