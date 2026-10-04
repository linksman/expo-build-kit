// Sets the EAS Update channel the binary listens on, for local (non-EAS Build)
// builds, where nothing else sets the `expo-channel-name` request header —
// without it the update server can't route the binary and OTA updates never
// arrive. The channel comes from EXPO_UPDATES_CHANNEL at `expo prebuild` time:
// `expo-build playstore` sets `production`, everything else defaults to
// `preview`. Only meaningful with expo-updates installed.
//
// app.json: "expo-build-kit/plugins/update-channel"
module.exports = (config) => ({
  ...config,
  updates: {
    ...config.updates,
    requestHeaders: {
      ...config.updates?.requestHeaders,
      'expo-channel-name': process.env.EXPO_UPDATES_CHANNEL || 'preview',
    },
  },
});
