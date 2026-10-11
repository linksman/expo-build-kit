// Turns on R8's optimizations and optimized resource shrinking for release
// builds: the two settings Play Console's "Improve your app's memory and
// performance with R8 optimisation" recommendation checks. Only has an effect
// when the app minifies release builds (expo-build-properties'
// enableMinifyInReleaseBuilds; optimized resource shrinking also needs
// enableShrinkResourcesInReleaseBuilds). Needs the Android Gradle plugin 8.6+.
//
// Optimization can strip or rename code that's only reached by reflection.
// Test a release build on a device before shipping, and add keep rules
// (expo-build-properties' extraProguardRules) for anything that breaks.
//
// app.json: "expo-build-kit/plugins/r8-optimization"
const { withAppBuildGradle, withGradleProperties } = require('expo/config-plugins');
const { applyR8Optimization } = require('../lib/transforms');

const SHRINKING = 'android.r8.optimizedResourceShrinking';

module.exports = (config) => {
  config = withAppBuildGradle(config, (mod) => {
    if (mod.modResults.language !== 'groovy') throw new Error('expo-build-kit r8-optimization: expected a Groovy app/build.gradle');
    mod.modResults.contents = applyR8Optimization(mod.modResults.contents);
    return mod;
  });
  return withGradleProperties(config, (mod) => {
    mod.modResults = mod.modResults.filter((item) => !(item.type === 'property' && item.key === SHRINKING));
    mod.modResults.push({ type: 'property', key: SHRINKING, value: 'true' });
    return mod;
  });
};
