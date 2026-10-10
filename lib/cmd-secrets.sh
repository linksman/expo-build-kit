# expo-build secrets [play-service-account.json]
#
# Uploads what a GitHub Actions build needs (see README, "Building in GitHub
# Actions") as repository secrets, without printing any values:
#   ENV_LOCAL             — the whole env file (EXPO_PUBLIC_* keys, Sentry
#                           credentials, keystore passwords)
#   PLAY_KEYSTORE_BASE64  — <app>/keystores/release.jks, base64-encoded
#   one per requiredFiles entry, named after the file: google-services.json →
#                           GOOGLE_SERVICES_JSON (the file's contents as-is)
#   PLAY_SERVICE_ACCOUNT_JSON — only when a Google Play service-account key is
#                           given, for uploading playstore builds to a track.
#                           Pass an absolute path; delete the key file after.
# Re-run after changing any of them.

command -v gh >/dev/null || die "needs the GitHub CLI (gh) — brew install gh && gh auth login"
[ -f "$ENV_FILE" ] || die "missing $ENV_FILE"
play_key="${1:-}"
if [ -n "$play_key" ]; then
  [ -f "$play_key" ] || die "no such file: $play_key (pass the service-account key's absolute path)"
  [ "$(jq -r '.type // empty' "$play_key" 2>/dev/null)" = service_account ] \
    || die "$play_key isn't a Google service-account JSON key"
fi

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
if [ -n "$play_key" ]; then
  gh secret set PLAY_SERVICE_ACCOUNT_JSON < "$play_key"
  echo "Stored PLAY_SERVICE_ACCOUNT_JSON ($(jq -r .client_email "$play_key")). Delete the key file now."
fi
gh secret list
