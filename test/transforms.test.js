const test = require('node:test');
const assert = require('node:assert/strict');
const { applyPlaySigning, applyDevVariant, devStringsXml, bumpAppJson, SIGNING_MARKER } = require('../lib/transforms');

// The relevant part of the React Native template's android/app/build.gradle.
const GRADLE = `android {
    signingConfigs {
        debug {
            storeFile file('debug.keystore')
            storePassword 'android'
            keyAlias 'androiddebugkey'
            keyPassword 'android'
        }
    }
    buildTypes {
        debug {
            signingConfig signingConfigs.debug
        }
        release {
            // Caution! In production, you need to generate your own keystore file.
            signingConfig signingConfigs.debug
            minifyEnabled enableMinifyInReleaseBuilds
        }
    }
}
`;

test('play signing adds the config, switches release, and appends the guard', () => {
  const out = applyPlaySigning(GRADLE, { keyAlias: 'vacationsignal' });
  assert.match(out, /playRelease \{[\s\S]*storeFile file\('\.\.\/\.\.\/keystores\/release\.jks'\)/);
  assert.match(out, /keyAlias System\.getenv\('PLAY_RELEASE_KEY_ALIAS'\) \?: 'vacationsignal'/);
  assert.match(out, /release \{[\s\S]*signingConfig System\.getenv\('PLAY_STORE_SIGNING'\) == 'true' \? signingConfigs\.playRelease : signingConfigs\.debug/);
  // The debug build type keeps the debug signature.
  assert.match(out, /debug \{\n\s*signingConfig signingConfigs\.debug/);
  assert.match(out, /throw new GradleException\("PLAY_STORE_SIGNING=true but keystores\/release\.jks is missing"\)/);
});

test('play signing defaults the alias to upload and escapes quotes', () => {
  assert.match(applyPlaySigning(GRADLE), /\?: 'upload'/);
  assert.match(applyPlaySigning(GRADLE, { keyAlias: "o'k" }), /\?: 'o\\'k'/);
});

test('play signing is idempotent', () => {
  const once = applyPlaySigning(GRADLE);
  assert.equal(applyPlaySigning(once), once);
  assert.equal(once.split(SIGNING_MARKER).length - 1, 2);
});

test('play signing throws on an unexpected build.gradle', () => {
  assert.throws(() => applyPlaySigning('android {}'), /signingConfigs\.debug not found/);
});

test('dev variant adds the suffix to the debug build type only', () => {
  const out = applyDevVariant(GRADLE, { suffix: '.dev' });
  assert.match(out, /buildTypes \{\n\s*debug \{\n\s*applicationIdSuffix "\.dev"/);
  assert.equal(out.split('applicationIdSuffix').length - 1, 1);
  assert.equal(applyDevVariant(out, { suffix: '.dev' }), out);
});

test('dev strings.xml escapes the app name', () => {
  assert.match(devStringsXml("Tom & Jerry's (Dev)"), /<string name="app_name">Tom &amp; Jerry\\'s \(Dev\)<\/string>/);
});

test('bumpAppJson changes only version and versionCode, keeping formatting', () => {
  const text = `{
  "expo": {
    "name": "X",
    "version": "1.2.3",
    "runtimeVersion": { "policy": "appVersion" },
    "android": { "package": "a.b", "versionCode": 7 }
  }
}
`;
  const out = bumpAppJson(text, '1.3.0', 8);
  assert.equal(out, text.replace('"1.2.3"', '"1.3.0"').replace('"versionCode": 7', '"versionCode": 8'));
});

test('bumpAppJson adds a missing versionCode', () => {
  const text = '{\n  "expo": {\n    "version": "1.0.0",\n    "android": {\n      "package": "a.b"\n    }\n  }\n}\n';
  const parsed = JSON.parse(bumpAppJson(text, '1.0.1', 3));
  assert.equal(parsed.expo.version, '1.0.1');
  assert.equal(parsed.expo.android.versionCode, 3);
  assert.equal(parsed.expo.android.package, 'a.b');
});

test('bumpAppJson falls back to a rewrite when another "version" key comes first', () => {
  const text = '{"expo":{"plugins":[["p",{"version":"9"}]],"version":"1.0.0","android":{"versionCode":1}}}';
  const parsed = JSON.parse(bumpAppJson(text, '2.0.0', 2));
  assert.equal(parsed.expo.version, '2.0.0');
  assert.equal(parsed.expo.android.versionCode, 2);
  assert.equal(parsed.expo.plugins[0][1].version, '9');
});
