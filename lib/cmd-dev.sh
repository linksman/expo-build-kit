# expo-build dev [open]
#
# Debug build with expo-dev-client that loads its JS live from Metro, so edits
# show up on the phone in seconds. With the dev-variant plugin it installs as a
# separate app (<package>.dev, "<name> (Dev)") next to the release app, with its
# own storage. Rebuild only after native changes; otherwise keep Metro running
# (`npx expo start`, port 8081 or METRO_PORT) and use `expo-build dev open` to
# reconnect. Don't press `a` in the Expo CLI: it targets the main package id,
# not the .dev one.
#
# No version bump, tag, or clean-tree/check gates: a throwaway build, never
# distributed.

mode="${1:-build}"
case "$mode" in build|open) ;; *) die "usage: expo-build dev [open]" ;; esac
[ "$HAS_DEV_CLIENT" = 1 ] || die "expo-dev-client isn't installed — run: npx expo install expo-dev-client"
[ -n "$ANDROID_PACKAGE" ] || die "app.json has no expo.android.package"

port="${METRO_PORT:-8081}"
package="${ANDROID_PACKAGE}${DEV_SUFFIX}"

android_env
require_single_device

if [ "$mode" = build ]; then
  prebuild preview
  # Debug build: no embedded JS bundle, so no createReleaseUpdatesResources.
  (cd "$APP_DIR/android" && ./gradlew assembleDebug --console=plain)
  mkdir -p "$BUILDS_DIR"
  out="$BUILDS_DIR/${ARTIFACT_NAME}-dev-$(git -C "$REPO_ROOT" rev-parse --short HEAD)-$(date +%Y%m%d-%H%M).apk"
  cp "$APP_DIR/android/app/build/outputs/apk/debug/app-debug.apk" "$out"
  adb install -r "$out"
  echo "Installed $out"
fi

# Let the phone reach Metro on this machine over USB as localhost.
adb reverse "tcp:${port}" "tcp:${port}"

# Open the dev app straight into this Metro server (the expo-dev-client deep link).
adb shell am start -a android.intent.action.VIEW \
  -d "exp+${SLUG}://expo-development-client/?url=http%3A%2F%2Flocalhost%3A${port}" \
  "$package" >/dev/null

echo "Opened ${package} against Metro on port ${port}. If Metro isn't running yet: npx expo start, then reload from the dev menu."
