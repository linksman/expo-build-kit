// Pure string transforms shared by the config plugins (plugins/) and the build
// commands (lib/cmd-*.sh). Deliberately free of any `expo` import, so they're
// unit-testable in this repo without an Expo project installed.

/**
 * Release signing: adds a `playRelease` signing config backed by
 * <app>/keystores/release.jks, and makes buildTypes.release use it only when
 * PLAY_STORE_SIGNING=true is set for the Gradle run — otherwise release builds
 * keep the debug signature, so `expo-build install` sideloads are unaffected.
 * Passwords are read from the environment at build time (never written into the
 * generated project). Adds a guard that fails the Gradle run early instead of
 * producing a wrongly signed or unsigned bundle. Idempotent.
 */
const SIGNING_MARKER = '// expo-build-kit:play-signing';
// From android/app/ to <app>/keystores/.
const KEYSTORE = '../../keystores/release.jks';

function groovyString(value) {
  return String(value).replace(/\\/g, '\\\\').replace(/'/g, "\\'");
}

function applyPlaySigning(gradle, { keyAlias = 'upload' } = {}) {
  if (gradle.includes(SIGNING_MARKER)) return gradle;

  const signingConfig = `
        ${SIGNING_MARKER}: upload key, used when PLAY_STORE_SIGNING=true
        playRelease {
            storeFile file('${KEYSTORE}')
            storePassword System.getenv('PLAY_RELEASE_STORE_PASSWORD')
            keyAlias System.getenv('PLAY_RELEASE_KEY_ALIAS') ?: '${groovyString(keyAlias)}'
            keyPassword System.getenv('PLAY_RELEASE_KEY_PASSWORD')
        }`;

  const guard = `
${SIGNING_MARKER}: fail early and clearly instead of producing a wrongly signed or unsigned bundle.
if (System.getenv('PLAY_STORE_SIGNING') == 'true') {
    if (!file('${KEYSTORE}').exists()) {
        throw new GradleException("PLAY_STORE_SIGNING=true but keystores/release.jks is missing")
    }
    if (!System.getenv('PLAY_RELEASE_STORE_PASSWORD') || !System.getenv('PLAY_RELEASE_KEY_PASSWORD')) {
        throw new GradleException("PLAY_STORE_SIGNING=true but PLAY_RELEASE_STORE_PASSWORD / PLAY_RELEASE_KEY_PASSWORD are not set")
    }
}
`;

  // 1. Add the playRelease config right after the debug one inside signingConfigs { }.
  const debugConfig = /(signingConfigs\s*\{\s*debug\s*\{[^}]*\})/;
  if (!debugConfig.test(gradle)) throw new Error('expo-build-kit play-signing: signingConfigs.debug not found in app/build.gradle');
  let result = gradle.replace(debugConfig, `$1${signingConfig}`);

  // 2. In buildTypes.release, choose the signing config from PLAY_STORE_SIGNING.
  const releaseSigning = /(buildTypes\s*\{[\s\S]*?release\s*\{[\s\S]*?)signingConfig signingConfigs\.debug/;
  if (!releaseSigning.test(result)) throw new Error('expo-build-kit play-signing: release signingConfig not found in app/build.gradle');
  result = result.replace(
    releaseSigning,
    "$1signingConfig System.getenv('PLAY_STORE_SIGNING') == 'true' ? signingConfigs.playRelease : signingConfigs.debug",
  );

  return `${result.trimEnd()}\n${guard}`;
}

/**
 * Dev variant: gives the *debug* build its own application id suffix, so the
 * development build installs next to the release app instead of replacing it.
 * Idempotent.
 */
function applyDevVariant(gradle, { suffix = '.dev' } = {}) {
  const line = `applicationIdSuffix "${suffix}"`;
  if (gradle.includes(line)) return gradle;
  const debugBuildType = /(buildTypes\s*\{\s*debug\s*\{)/;
  if (!debugBuildType.test(gradle)) throw new Error('expo-build-kit dev-variant: buildTypes.debug not found in app/build.gradle');
  return gradle.replace(debugBuildType, `$1\n            ${line}`);
}

/** strings.xml for the debug source set, overriding app_name for the dev build only. */
function devStringsXml(appName) {
  const escaped = String(appName).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/'/g, "\\'");
  return `<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <string name="app_name">${escaped}</string>\n</resources>\n`;
}

/**
 * Sets expo.version and expo.android.versionCode in app.json text, changing only
 * those two values and keeping the rest of the file's formatting. Falls back to a
 * full 2-space rewrite if the targeted edit doesn't land where expected.
 */
function bumpAppJson(text, version, versionCode) {
  let s = text.replace(/("version"\s*:\s*)"[^"]*"/, `$1"${version}"`);
  if (/"versionCode"\s*:\s*\d+/.test(s)) s = s.replace(/("versionCode"\s*:\s*)\d+/, `$1${versionCode}`);
  else s = s.replace(/("android"\s*:\s*\{)/, `$1\n      "versionCode": ${versionCode},`);

  try {
    const parsed = JSON.parse(s);
    if (parsed.expo?.version === version && parsed.expo?.android?.versionCode === versionCode) return s;
  } catch {
    // fall through to the full rewrite
  }
  const parsed = JSON.parse(text);
  parsed.expo.version = version;
  parsed.expo.android = { ...parsed.expo.android, versionCode };
  return `${JSON.stringify(parsed, null, 2)}\n`;
}

module.exports = { applyPlaySigning, applyDevVariant, devStringsXml, bumpAppJson, SIGNING_MARKER };
