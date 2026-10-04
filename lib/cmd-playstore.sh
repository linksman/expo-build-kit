# expo-build playstore <major|minor|patch|no_change>
#
# Release AAB signed with the upload key (<app>/keystores/release.jks), for Play
# Console. Listens on the `production` update channel. Needs the play-signing
# plugin in app.json; the keystore passwords come from the env file
# (PLAY_RELEASE_STORE_PASSWORD / PLAY_RELEASE_KEY_PASSWORD, optionally
# PLAY_RELEASE_KEY_ALIAS), which build.gradle reads via System.getenv().

usage="usage: expo-build playstore <major|minor|patch|no_change>   (current version: $APP_VERSION)"
version="$(next_version "${1:-}")" || die "$usage"
echo "Version: $APP_VERSION → $version"

# Signing prerequisites (names checked, values never printed).
[ -f "$APP_DIR/keystores/release.jks" ] || die "missing $APP_DIR/keystores/release.jks (see README: one-time signing setup)"
[ -f "$ENV_FILE" ] || die "missing $ENV_FILE with the keystore passwords"
for name in PLAY_RELEASE_STORE_PASSWORD PLAY_RELEASE_KEY_PASSWORD; do
  grep -q "^${name}=." "$ENV_FILE" || die "missing ${name} in $ENV_FILE"
done
grep -q 'expo-build-kit/plugins/play-signing' "$APP_DIR/app.json" || die "add \"expo-build-kit/plugins/play-signing\" to app.json plugins"

# Gates — all before anything is bumped.
require_clean_tree
require_files
run_checks
android_env

commit=$(git -C "$REPO_ROOT" rev-parse --short HEAD)
n=$(next_build_number)
(cd "$APP_DIR" && bump_app_json "$version" "$n")
timestamp=$(date +%Y%m%d-%H%M)
export EXPO_PUBLIC_BUILD_NAME="${n}-${version}-${commit}-${timestamp}-playstore"
echo "Building $EXPO_PUBLIC_BUILD_NAME"

load_env_file
export PLAY_STORE_SIGNING=true

prebuild production
gradle_release aab

out="$BUILDS_DIR/${ARTIFACT_NAME}-playstore-${n}-${version}-${commit}-${timestamp}.aab"
cp "$(release_output aab)" "$out"

# Play Console rejects a debug-signed upload; catch it here instead.
signer=$(jarsigner -verify -verbose -certs "$out" | grep -m1 "CN=" || true)
echo "Signed by: ${signer:-unknown}"
case "$signer" in
  *"CN=Android Debug"*|"")
    die "not signed with the upload key — don't upload $out (app.json was bumped but not committed: git checkout it)" ;;
esac

commit_tag_push "$version" "$APP_VERSION" "$n"
echo "Done: $out — upload this file to Play Console."
