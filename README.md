# expo-build-kit

Local Android build commands for Expo apps: install a release build on your phone, build a Play-signed AAB, run a development build against Metro, and publish JS-only hotfixes over the air. Builds run on your machine through `expo prebuild` + Gradle. EAS Build isn't used.

It comes in three parts:

- **`expo-build` CLI**: the commands, as bash scripts. Works from any terminal.
- **Config plugins** that the commands rely on: release signing, a separate dev-build app id, and the OTA update channel.
- **A Claude Code plugin**: `/build-install`, `/build-playstore`, `/build-development` and `/publish-hotfix` slash commands that ask for the arguments, run the CLI and report.

## Commands

Run from the Expo app's folder (the one with `expo-build.config.json`):

| Command | What it does |
|---|---|
| `npx expo-build install <major\|minor\|patch\|no_change> <apk\|aab>` | Release build, debug-signed, installed on the connected device. `preview` update channel. |
| `npx expo-build playstore <major\|minor\|patch\|no_change>` | Release AAB signed with the upload key, for Play Console. `production` update channel. |
| `npx expo-build dev [open]` | Debug build with `expo-dev-client` that loads JS live from Metro. `open` skips the build and just reconnects. |
| `npx expo-build hotfix <preview\|production> "<message>"` | JS-only EAS Update to installed builds of the current version. |

**`install` and `playstore`** run these steps in order:
1. Check the working tree is clean.
2. Check the required files exist.
3. Run your checks.
4. Bump `expo.version` and `expo.android.versionCode` in `app.json`. The build number is a shared counter in `<buildsDir>/.build_number`.
5. Run prebuild and the Gradle build.
6. Copy the artifact to `buildsDir`.
7. For `install`: install it on the device. For `playstore`: fail if the AAB is debug-signed.
8. Commit `app.json`, tag `<tagPrefix><version>`, and push both.

**`hotfix`** refuses to publish when anything native-affecting changed since the current version's tag:
- dependencies and lockfiles
- `app.json` / `app.config.*`
- `eas.json`
- `plugins/`, `patches/`, `modules/`
- anything you list in `nativePaths`

Those changes need a new store build. Builds pick an update up on their next launch and run it on the one after.

## One-time machine setup

Create `~/.config/expo-build/env.sh`:

```bash
export ANDROID_HOME="/usr/local/share/android-commandlinetools"
export JAVA_HOME="$(brew --prefix openjdk@17)/libexec/openjdk.jdk/Contents/Home"
```

JAVA_HOME must point at JDK 17, because newer JDKs fail React Native's Gradle plugin resolution. Set `EXPO_BUILD_ENV` to use a different file.

Install the slash commands in Claude Code:

```
/plugin marketplace add linksman/expo-build-kit
/plugin install expo-build-kit@expo-build-kit
```

## Setting up a project

1. **Install** in the Expo app's folder, pinned to a release tag:

   ```bash
   npm install --save-dev github:linksman/expo-build-kit#v0.1.0
   ```

2. **Add `expo-build.config.json`** next to `app.json`. All paths are relative to this file's folder:

   ```json
   {
     "checks": ["npx tsc --noEmit", "npm test"],
     "buildsDir": "builds",
     "requiredFiles": [],
     "nativePaths": [],
     "tagPrefix": "v",
     "envFile": ".env.local",
     "artifactName": "my-app"
   }
   ```

   | Key | Default | Meaning |
   |---|---|---|
   | `checks` | `[]` | Shell commands run in the app folder before `install`, `playstore` and `hotfix`. Any failure stops the run before anything is bumped. |
   | `buildsDir` | `builds` | Where artifacts and the `.build_number` counter go. In a monorepo, `../builds` keeps them at the repo root. |
   | `requiredFiles` | `[]` | Files that must exist before building (e.g. `google-services.json`). |
   | `nativePaths` | `[]` | Extra paths (beyond the defaults above) whose change blocks a hotfix. |
   | `tagPrefix` | `v` | Release tags are `<tagPrefix><version>`. Use e.g. `mobile-v` when other parts of the repo are tagged too. |
   | `envFile` | `.env.local` | Sourced for `playstore` (keystore passwords) and `hotfix` (`EXPO_PUBLIC_*`, Sentry). |
   | `artifactName` | `expo.slug` | Prefix of the artifact file names. |

3. **Add the plugins you need** to `app.json`:

   ```json
   "plugins": [
     ["expo-build-kit/plugins/play-signing", { "keyAlias": "upload" }],
     ["expo-build-kit/plugins/dev-variant", { "suffix": ".dev" }],
     "expo-build-kit/plugins/update-channel"
   ]
   ```

   - **`play-signing`** is required for `playstore`. Release builds sign with `<app>/keystores/release.jks` only when `PLAY_STORE_SIGNING=true`, which `playstore` sets. Otherwise they keep the debug signature. The passwords come from the env file: `PLAY_RELEASE_STORE_PASSWORD`, `PLAY_RELEASE_KEY_PASSWORD`, and optionally `PLAY_RELEASE_KEY_ALIAS`, which overrides `keyAlias`.
   - **`dev-variant`** is optional. It gives the debug build its own application id (`<package>.dev`) and the name "`<name> (Dev)`", so `dev` installs next to the release app instead of replacing it. Services registered per package id (Firebase, Google Sign-In, Play Billing) won't recognize the suffixed id unless you register it there too.
   - **`update-channel`** is needed for OTA hotfixes with `expo-updates`. It writes the `expo-channel-name` header into the binary at prebuild time. Local builds have no EAS Build to set it.

4. **Optionally add npm scripts**, e.g. `"build:install": "expo-build install"`, or just use `npx expo-build`.

5. **Gitignore** `builds/`, `android/`, `ios/`, `keystores/` and `.env*.local`.

### Signing (once per app)

```bash
mkdir -p keystores
keytool -genkeypair -v -keystore keystores/release.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

Put `PLAY_RELEASE_STORE_PASSWORD` and `PLAY_RELEASE_KEY_PASSWORD` in `.env.local`. Back up the keystore and passwords somewhere safe: losing them means you can no longer update the app with this key.

### OTA hotfixes

You need four things:
- `expo-updates` installed
- `updates.url` and `runtimeVersion: { "policy": "appVersion" }` in `app.json`
- the `update-channel` plugin
- an EAS project you're logged into (`npx eas login`)

Builds made before you add the plugin carry no channel and can't receive updates.

## Development

```bash
npm test   # unit tests for the config resolver and the Gradle/app.json transforms
```

To release, bump `version` in `package.json` and `claude-plugin/.claude-plugin/plugin.json`, then tag `v<version>`. Projects pin a tag, so changes reach them only when they update the pin.
