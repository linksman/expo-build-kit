# Shared helpers for the expo-build commands (lib/cmd-*.sh). Sourced by
# bin/expo-build with KIT_DIR set and the working directory at the Expo app.

die() { echo "expo-build: $*" >&2; exit 1; }

# Loads expo-build.config.json (+ app.json/package.json) into shell variables —
# see lib/config.js for the full list.
load_config() {
  local out
  out="$(node "$KIT_DIR/lib/config.js")" || die "couldn't read expo-build.config.json"
  eval "$out"
}

# next_version <major|minor|patch|no_change> → prints the new version string.
next_version() {
  local major minor patch
  IFS=. read -r major minor patch <<< "$APP_VERSION"
  case "${1:-}" in
    major)     echo "$((major + 1)).0.0" ;;
    minor)     echo "${major}.$((minor + 1)).0" ;;
    patch)     echo "${major}.${minor}.$((patch + 1))" ;;
    no_change) echo "$APP_VERSION" ;;
    *) return 1 ;;
  esac
}

# The git tag a release must match exactly, so nothing uncommitted may be in the tree.
require_clean_tree() {
  if [ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]; then
    echo "Working tree is dirty — commit or stash first:"; git -C "$REPO_ROOT" status --short; exit 1
  fi
}

require_files() {
  local f
  for f in ${REQUIRED_FILES[@]+"${REQUIRED_FILES[@]}"}; do
    [ -e "$f" ] || die "missing required file: $f"
  done
}

# The project's own gates (expo-build.config.json "checks"), run in the app folder.
run_checks() {
  local c
  for c in ${CHECKS[@]+"${CHECKS[@]}"}; do
    echo "→ $c"
    (cd "$APP_DIR" && bash -c "$c")
  done
}

android_env() {
  # shellcheck source=android-env.sh
  source "$KIT_DIR/lib/android-env.sh"
}

# There's no emulator setup assumed, and guessing between several devices could
# install on the wrong one.
require_single_device() {
  local count
  count=$(adb devices | awk 'NR > 1 && $2 == "device"' | wc -l | tr -d ' ')
  if [ "$count" != "1" ]; then
    echo "Expected exactly one connected device, found ${count}:"; adb devices -l; exit 1
  fi
}

# Shared counter across install and playstore builds. versionCode must go up
# every build: Android silently refuses to replace an installed app with the
# same or lower versionCode.
next_build_number() {
  mkdir -p "$BUILDS_DIR"
  local n=$(( $(cat "$BUILDS_DIR/.build_number" 2>/dev/null || echo 0) + 1 ))
  echo "$n" > "$BUILDS_DIR/.build_number"
  echo "$n"
}

# bump_app_json <version> <versionCode> — edits only those two values.
bump_app_json() {
  node -e "
const fs = require('fs');
const { bumpAppJson } = require(process.argv[1]);
fs.writeFileSync('app.json', bumpAppJson(fs.readFileSync('app.json', 'utf8'), process.argv[2], Number(process.argv[3])));
" "$KIT_DIR/lib/transforms.js" "$1" "$2"
}

# prebuild <update channel> — regenerates the disposable android/ folder. The
# channel is read by plugins/update-channel.js and baked into the manifest here.
prebuild() {
  export EXPO_UPDATES_CHANNEL="$1"
  (cd "$APP_DIR" && npx expo prebuild --platform android)
  echo "sdk.dir=$ANDROID_HOME" > "$APP_DIR/android/local.properties"
}

# gradle_release <apk|aab>
# createReleaseUpdatesResources (expo-updates only — the task doesn't exist
# otherwise) is force-rerun every time: its up-to-date check misses newly-added
# local assets and silently ships a stale embedded-asset manifest (images just
# don't render, no error anywhere). Never run ./gradlew clean — it has broken
# RN's C++ codegen before.
gradle_release() {
  (
    cd "$APP_DIR/android"
    if [ "$HAS_UPDATES" = 1 ]; then
      ./gradlew createReleaseUpdatesResources --rerun-tasks --console=plain
    fi
    if [ "$1" = apk ]; then ./gradlew assembleRelease --console=plain; else ./gradlew bundleRelease --console=plain; fi
  )
}

release_output() {
  if [ "$1" = apk ]; then echo "$APP_DIR/android/app/build/outputs/apk/release/app-release.apk"
  else echo "$APP_DIR/android/app/build/outputs/bundle/release/app-release.aab"; fi
}

# commit_tag_push <version> <old version> <build number>
commit_tag_push() {
  local version="$1" old="$2" n="$3" tag="${TAG_PREFIX}$1" app_json
  if [ "$APP_REL" = . ]; then app_json=app.json; else app_json="$APP_REL/app.json"; fi
  (
    cd "$REPO_ROOT"
    git add "$app_json"
    if [ "$version" = "$old" ]; then git commit -m "Bump build to ${n}"
    else git commit -m "Bump version to ${version} (build ${n})"; fi
    git push origin "$(git rev-parse --abbrev-ref HEAD)"
    if ! git rev-parse -q --verify "refs/tags/${tag}" >/dev/null; then
      git tag "$tag"
      git push origin "$tag"
    else
      echo "Tag ${tag} already exists — left in place."
    fi
  )
}
