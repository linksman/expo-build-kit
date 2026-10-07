# expo-build secrets
#
# Uploads what a GitHub Actions build needs (see README, "Building in GitHub
# Actions") as repository secrets, without printing any values:
#   ENV_LOCAL             — the whole env file (EXPO_PUBLIC_* keys, Sentry
#                           credentials, keystore passwords)
#   PLAY_KEYSTORE_BASE64  — <app>/keystores/release.jks, base64-encoded
#   one per requiredFiles entry, named after the file: google-services.json →
#                           GOOGLE_SERVICES_JSON (the file's contents as-is)
# Re-run after changing any of them.

command -v gh >/dev/null || die "needs the GitHub CLI (gh) — brew install gh && gh auth login"
[ -f "$ENV_FILE" ] || die "missing $ENV_FILE"

cd "$REPO_ROOT"
gh secret set ENV_LOCAL < "$ENV_FILE"
if [ -f "$APP_DIR/keystores/release.jks" ]; then
  base64 < "$APP_DIR/keystores/release.jks" | tr -d '\n' | gh secret set PLAY_KEYSTORE_BASE64
else
  echo "No keystores/release.jks — skipped PLAY_KEYSTORE_BASE64 (playstore builds in CI will fail without it)."
fi
for f in ${REQUIRED_FILES[@]+"${REQUIRED_FILES[@]}"}; do
  [ -f "$f" ] || die "missing required file $f"
  name=$(basename "$f" | tr '[:lower:]' '[:upper:]' | tr -c 'A-Z0-9\n' '_')
  gh secret set "$name" < "$f"
done
gh secret list
