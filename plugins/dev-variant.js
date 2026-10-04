// Makes the *debug* build (`expo-build dev`) a separate app from the release
// builds: application id `<package><suffix>` and launcher name `<name> (Dev)`.
// Without it, installing the debug APK replaces the sideloaded release app (same
// package, same debug signature), and Android refuses it outright over a
// Play-installed copy (different signature). Release builds are untouched.
//
// Note: services registered per package id (Firebase, Google Sign-In, Play
// Billing) won't recognize the suffixed id unless it's registered there too.
//
// app.json: ["expo-build-kit/plugins/dev-variant", { "suffix": ".dev", "name": "My App (Dev)" }]
const fs = require('fs');
const path = require('path');
const { withAppBuildGradle, withDangerousMod } = require('expo/config-plugins');
const { applyDevVariant, devStringsXml } = require('../lib/transforms');

module.exports = (config, options = {}) => {
  const suffix = options.suffix ?? '.dev';
  const name = options.name ?? `${config.name} (Dev)`;

  config = withAppBuildGradle(config, (mod) => {
    mod.modResults.contents = applyDevVariant(mod.modResults.contents, { suffix });
    return mod;
  });

  // The debug source set's resources override main's, so this renames only the
  // debug app (a resValue in build.gradle would clash with main's strings.xml).
  return withDangerousMod(config, [
    'android',
    async (mod) => {
      const valuesDir = path.join(mod.modRequest.platformProjectRoot, 'app/src/debug/res/values');
      fs.mkdirSync(valuesDir, { recursive: true });
      fs.writeFileSync(path.join(valuesDir, 'strings.xml'), devStringsXml(name));
      return mod;
    },
  ]);
};
