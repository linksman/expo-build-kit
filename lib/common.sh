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

# The project's own gates (expo-build.config.json "checks"), run in the app folder,
# then the CI gate when "ciWorkflow" is set.
run_checks() {
  local c
  for c in ${CHECKS[@]+"${CHECKS[@]}"}; do
    echo "→ $c"
    (cd "$APP_DIR" && bash -c "$c")
  done
  [ -z "$CI_WORKFLOW" ] || require_ci_green
}

# The commit whose CI result stands for HEAD: HEAD itself, minus any trailing
# kit "Bump …" commits that touched only app.json — so back-to-back builds don't
# wait for a full CI rerun of a version bump.
ci_commit() {
  local sha app_json
  if [ "$APP_REL" = . ]; then app_json=app.json; else app_json="$APP_REL/app.json"; fi
  sha=$(git -C "$REPO_ROOT" rev-parse HEAD)
  while git -C "$REPO_ROOT" log -1 --format=%s "$sha" | grep -qE '^Bump (version|build) to ' \
    && [ "$(git -C "$REPO_ROOT" diff-tree --no-commit-id --name-only -r "$sha")" = "$app_json" ]; do
    sha=$(git -C "$REPO_ROOT" rev-parse "${sha}^")
  done
  echo "$sha"
}

# Instead of re-running the tests locally: HEAD must be pushed and the
# "ciWorkflow" GitHub Actions workflow must have passed on it. A run still in
# progress is watched until it finishes. Needs the gh CLI, logged in.
require_ci_green() {
  local wf="$CI_WORKFLOW" sha run status conclusion upstream
  [ -f "$REPO_ROOT/.github/workflows/$wf" ] || die "ciWorkflow \"$wf\" not found in .github/workflows/"
  command -v gh >/dev/null || die "ciWorkflow needs the GitHub CLI (gh) — brew install gh && gh auth login"
  upstream=$(git -C "$REPO_ROOT" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null) \
    || die "branch has no upstream — push it first so CI can run"
  git -C "$REPO_ROOT" fetch -q "${upstream%%/*}"
  [ -z "$(git -C "$REPO_ROOT" rev-list "${upstream}..HEAD")" ] \
    || die "HEAD isn't pushed to ${upstream} — push it and let CI run first"

  sha=$(ci_commit)
  echo "→ CI ($wf) on ${sha:0:7}"
  run=$(cd "$REPO_ROOT" && gh run list --workflow "$wf" --commit "$sha" --limit 1 \
    --json databaseId,status,conclusion --jq '.[0] | "\(.databaseId) \(.status) \(.conclusion)"')
  [ -n "$run" ] || die "no $wf run for ${sha:0:7} yet — wait for GitHub to start it (or run it via workflow_dispatch)"
  read -r run status conclusion <<< "$run"

  if [ "$status" != completed ]; then
    echo "CI run $run is $status — waiting for it to finish…"
    (cd "$REPO_ROOT" && gh run watch "$run" --compact --interval 15 >/dev/null) || true
    conclusion=$(cd "$REPO_ROOT" && gh run view "$run" --json conclusion --jq .conclusion)
  fi
  if [ "$conclusion" != success ]; then
    (cd "$REPO_ROOT" && gh run view "$run" --json url --jq .url) >&2 || true
    die "CI run $run on ${sha:0:7} finished with \"$conclusion\" — fix it before building"
  fi
  echo "CI passed (run $run)."
}

# Exports every variable in the env file (when it exists): EXPO_PUBLIC_* keys
# for the JS bundle, build-time credentials such as SENTRY_ORG / SENTRY_PROJECT /
# SENTRY_AUTH_TOKEN (Sentry's Gradle plugin uploads source maps in every release
# build and fails without them), and the keystore passwords. The Expo CLI
# auto-loads .env files, but a bare ./gradlew doesn't.
load_env_file() {
  if [ -f "$ENV_FILE" ]; then
    set -a
    # shellcheck source=/dev/null
    source "$ENV_FILE"
    set +a
  fi
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
