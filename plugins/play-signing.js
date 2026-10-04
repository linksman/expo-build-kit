// Release signing with the upload key (<app>/keystores/release.jks), used only
// when PLAY_STORE_SIGNING=true (set by `expo-build playstore`). See
// applyPlaySigning in lib/transforms.js.
//
// app.json: ["expo-build-kit/plugins/play-signing", { "keyAlias": "upload" }]
// (PLAY_RELEASE_KEY_ALIAS in the env file overrides keyAlias.)
const { withAppBuildGradle } = require('expo/config-plugins');
const { applyPlaySigning } = require('../lib/transforms');

module.exports = (config, options = {}) =>
  withAppBuildGradle(config, (mod) => {
    if (mod.modResults.language !== 'groovy') throw new Error('expo-build-kit play-signing: expected a Groovy app/build.gradle');
    mod.modResults.contents = applyPlaySigning(mod.modResults.contents, options);
    return mod;
  });
