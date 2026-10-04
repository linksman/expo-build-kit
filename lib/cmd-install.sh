# expo-build install <major|minor|patch|no_change> <apk|aab>
#
# Release build signed with the debug keystore, installed on the connected
# device, replacing the current install. A *release* build, so the JS bundle is
# embedded and the phone needs no Metro connection (a debug build hangs on the
# splash screen without one — that's what `expo-build dev` is for). Listens on
# the `preview` update channel, so `expo-build hotfix preview` reaches it but
# production hotfixes never do.

usage="usage: expo-build install <major|minor|patch|no_change> <apk|aab>   (current version: $APP_VERSION)"
version="$(next_version "${1:-}")" || die "$usage"
format="${2:-}"
case "$format" in apk|aab) ;; *) die "$usage" ;; esac
echo "Version: $APP_VERSION → $version ($format)"

# Gates — all before anything is bumped.
require_clean_tree
require_files
run_checks
android_env
require_single_device

load_env_file

commit=$(git -C "$REPO_ROOT" rev-parse --short HEAD)
n=$(next_build_number)
(cd "$APP_DIR" && bump_app_json "$version" "$n")
timestamp=$(date +%Y%m%d-%H%M)
# Shown wherever the app displays it (e.g. a dev menu), so a running build can be
# traced to its artifact and commit.
export EXPO_PUBLIC_BUILD_NAME="${n}-${version}-${commit}-${timestamp}"
echo "Building $EXPO_PUBLIC_BUILD_NAME"

prebuild preview
gradle_release "$format"

out="$BUILDS_DIR/${ARTIFACT_NAME}-release-${n}-${version}-${commit}-${timestamp}.${format}"
cp "$(release_output "$format")" "$out"

# adb can't take an .aab, so derive a device-specific APK set with bundletool
# (already in Gradle's cache via AGP). The release build type signs with the
# debug keystore, hence those --ks values.
if [ "$format" = apk ]; then
  adb install -r "$out"
else
  bundletool_jar=$(find ~/.gradle/caches/modules-2/files-2.1/com.android.tools.build/bundletool -name 'bundletool-*.jar' | sort -V | tail -1)
  [ -n "$bundletool_jar" ] || die "bundletool not found in ~/.gradle/caches"
  apks="$(mktemp -d)/app.apks"
  java -jar "$bundletool_jar" build-apks --bundle="$out" --output="$apks" --overwrite \
    --connected-device --adb="$ANDROID_HOME/platform-tools/adb" \
    --ks="$APP_DIR/android/app/debug.keystore" --ks-pass=pass:android --ks-key-alias=androiddebugkey --key-pass=pass:android
  java -jar "$bundletool_jar" install-apks --apks="$apks" --adb="$ANDROID_HOME/platform-tools/adb"
fi

commit_tag_push "$version" "$APP_VERSION" "$n"
echo "Done: $out (installed)"
