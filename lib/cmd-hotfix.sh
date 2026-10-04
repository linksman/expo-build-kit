# expo-build hotfix <preview|production> "<message>"
#
# Publishes a JS-only update over the air (EAS Update) to installed builds:
#   preview    — `expo-build install` sideloads (try a fix on the test device first)
#   production — `expo-build playstore` builds
#
# Assumes runtimeVersion's "appVersion" policy: an update reaches only builds of
# the current app.json version. JS that needs native code the installed binary
# doesn't have would crash it, so this refuses when anything native-affecting
# changed since that version's release tag.

[ "$HAS_UPDATES" = 1 ] || die "expo-updates isn't installed — OTA hotfixes need it (and the update-channel plugin)"
channel="${1:-}"
message="${2:-}"
case "$channel" in preview|production) ;; *) die "usage: expo-build hotfix <preview|production> \"<message>\"" ;; esac
[ -n "$message" ] || die "a message is required"

version="$APP_VERSION"
tag="${TAG_PREFIX}${version}"

require_clean_tree

# Native-change gate — only JS/assets may differ from the installed binary.
git -C "$REPO_ROOT" rev-parse -q --verify "refs/tags/${tag}" >/dev/null \
  || die "no ${tag} tag — there's no released ${version} build to update"
if ! git -C "$REPO_ROOT" diff --quiet "$tag" HEAD -- "${NATIVE_PATHS[@]}"; then
  echo "Native-affecting files changed since ${tag} — this needs a new store build, not an OTA update:"
  git -C "$REPO_ROOT" diff --stat "$tag" HEAD -- "${NATIVE_PATHS[@]}"
  exit 1
fi

require_files
run_checks

# EXPO_PUBLIC_* keys (and Sentry credentials, if any) for the bundle, plus a
# build name so a running OTA bundle can be traced to its commit.
if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  set +a
fi
export EXPO_UPDATES_CHANNEL="$channel"
commit=$(git -C "$REPO_ROOT" rev-parse --short HEAD)
timestamp=$(date +%Y%m%d-%H%M)
build=$(cat "$BUILDS_DIR/.build_number" 2>/dev/null || echo 0)
export EXPO_PUBLIC_BUILD_NAME="${build}-${version}-${commit}-${timestamp}-ota-${channel}"
echo "Publishing $EXPO_PUBLIC_BUILD_NAME to channel '$channel' (runtime ${version})"

# Android only for now — no iOS build flow exists in this kit.
(
  cd "$APP_DIR"
  npx eas update --channel "$channel" --environment "$channel" --platform android \
    --message "${message} (${commit})" --non-interactive
  if [ "$HAS_SENTRY" = 1 ]; then
    # So Sentry can symbolicate crashes from this update.
    npx sentry-expo-upload-sourcemaps dist
  fi
)

ota_tag="ota-${channel}-${TAG_PREFIX}${version}-${timestamp}"
git -C "$REPO_ROOT" tag "$ota_tag"
git -C "$REPO_ROOT" push origin "$ota_tag"

echo "Done: $ota_tag — installed ${version} builds on '$channel' download it on their next launch and run it on the one after."
