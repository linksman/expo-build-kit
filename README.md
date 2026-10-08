# expo-build-kit

Local Android build commands for Expo apps: install a release build on your phone, build a Play-signed AAB, run a development build against Metro, and publish JS-only hotfixes over the air. Builds run on your machine through `expo prebuild` + Gradle. EAS Build isn't used.

It comes in three parts:

- **`expo-build` CLI**: the commands, as bash scripts. Works from any terminal.
- **Config plugins** that the commands rely on: release signing, a separate dev-build app id, and the OTA update channel.
- **A Claude Code plugin**: `/build-install`, `/build-playstore`, `/build-development` and `/publish-hotfix` slash commands that ask for the arguments, run the CLI and report. It also has `/commit-push` (runs the app's `npm run check`, then commits with a generated message and pushes) and `/commit-message` (previews that message), so projects don't keep their own copies.

## Commands

Run from the Expo app's folder (the one with `expo-build.config.json`):

| Command | What it does |
|---|---|
| `npx expo-build install <major\|minor\|patch\|no_change> <apk\|aab>` | Release build, debug-signed, installed on the connected device. `preview` update channel. |
| `npx expo-build playstore <major\|minor\|patch\|no_change>` | Release AAB signed with the upload key, for Play Console. `production` update channel. |
| `npx expo-build dev [open]` | Debug build with `expo-dev-client` that loads JS live from Metro. `open` skips the build and just reconnects. |
| `npx expo-build hotfix <preview\|production> "<message>"` | JS-only EAS Update to installed builds of the current version. |
| `npx expo-build secrets` | Uploads the env file, Play keystore and `requiredFiles` as GitHub Actions secrets, for [building in GitHub Actions](#building-in-github-actions). |

**`install` and `playstore`** run these steps in order:
1. Check the working tree is clean.
2. Check the required files exist.
3. Run your checks, and/or confirm CI passed on HEAD (`ciWorkflow`).
4. Bump `expo.version` and `expo.android.versionCode` in `app.json`. The build number is the committed `versionCode` + 1, so local and CI builds share one sequence.
5. Run prebuild and the Gradle build.
6. Copy the artifact to `buildsDir`.
7. For `install`: install it on the device. For `playstore`: fail if the AAB is debug-signed.
8. Commit `app.json`, tag `<tagPrefix><version>` on that commit, and push both. If the branch moved on meanwhile, the bump is rebased onto it; the tag stays on the commit that was built.

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
   | `ciWorkflow` | — | A GitHub Actions workflow file in `.github/workflows/` (e.g. `ci.yml`). When set, `install`, `playstore` and `hotfix` require HEAD to be pushed and that workflow's latest run on it to have succeeded, instead of re-running the tests locally. A run still in progress is watched until it finishes. Trailing kit `Bump …` commits that only touch `app.json` are skipped back to the commit before them, so back-to-back builds don't wait for CI on a version bump. Needs the `gh` CLI, logged in. Use it only when that workflow runs every test you'd otherwise list in `checks`. It can be combined with `checks` (they run first). |
   | `buildsDir` | `builds` | Where artifacts go. In a monorepo, `../builds` keeps them at the repo root. |
   | `requiredFiles` | `[]` | Files that must exist before building (e.g. `google-services.json`). |
   | `nativePaths` | `[]` | Extra paths (beyond the defaults above) whose change blocks a hotfix. |
   | `tagPrefix` | `v` | Release tags are `<tagPrefix><version>`. Use e.g. `mobile-v` when other parts of the repo are tagged too. |
   | `envFile` | `.env.local` | Loaded before `install`, `playstore` and `hotfix` run Gradle or EAS: `EXPO_PUBLIC_*` keys, build-time credentials such as Sentry's (its Gradle plugin uploads source maps in every release build and fails without `SENTRY_ORG`/`SENTRY_PROJECT`/`SENTRY_AUTH_TOKEN`), and the keystore passwords. |
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

4. **Add a root shortcut** (optional). An executable `expo-build` file at the repo root gives the same command in every project (`./expo-build install patch apk`), even when the app is in a subfolder. Set the `cd` line to the app's folder (`.` when the app is at the root):

   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   cd "$(dirname "$0")/frontend"
   bin=node_modules/.bin/expo-build
   [ -x "$bin" ] || { echo "expo-build-kit isn't installed in $(pwd) — run npm install there first" >&2; exit 1; }
   exec "$bin" "$@"
   ```

   Don't use `npx expo-build` from a folder where the kit isn't installed: npx would look for an `expo-build` package on the npm registry instead.

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

## Building in GitHub Actions

The kit ships a reusable workflow, `.github/workflows/build.yml`, that builds on request only. Each app calls it from a short workflow (`templates/build.yml`): the repo's **Actions** tab → **Build** → **Run workflow**, then pick the type (`install-apk`, `install-aab`, `playstore`, `dev`) and the version bump. The APK or AAB is attached to the run, unzipped, for 90 days. Fixes to the build go into the kit's workflow, and every app picks them up when it bumps the tag it calls.

It runs the same commands as a local build with `EXPO_BUILD_CI=1`, which skips everything that needs a phone: `install` and `dev` only build and copy the artifact into `buildsDir`. Bumping, committing, tagging and pushing work as they do locally, done by `github-actions[bot]`. Versioned builds must run from the default branch; `dev` can run from any branch and skips the version bump. One build runs at a time.

It also handles the GitHub runner: it frees disk space (the runner starts with ~14 GB), allows 90 minutes (a cold build takes ~1h), raises Gradle's heap and Metaspace (the generated cap runs out in release lint), and builds only the ABIs each type needs (`arm64-v8a` for install/dev, plus `armeabi-v7a` for playstore).

To set it up:
1. Copy `node_modules/expo-build-kit/templates/build.yml` to `.github/workflows/build.yml`. If the Expo app isn't at the repo root, set `app-dir` (e.g. `app-dir: frontend`). Keep the `@vX.Y.Z` tag in `uses:` the same as the kit version in `package.json`.
2. Run `npx expo-build secrets`. It stores the env file as `ENV_LOCAL`, `keystores/release.jks` as `PLAY_KEYSTORE_BASE64`, and each `requiredFiles` entry under its file name in upper case with non-alphanumerics as `_` (`google-services.json` → `GOOGLE_SERVICES_JSON`). Re-run it whenever any of them changes. The workflow writes all of them back (to `envFile` and each `requiredFiles` path) before building; the caller passes them with `secrets: inherit`.
3. Set `ciWorkflow` too, so versioned builds wait for a passed CI run instead of running the tests in the build job. Without it, the build job runs `checks`.
4. If the default branch is protected, allow GitHub Actions to push to it.

After installing a CI `dev` build, connect it to Metro locally with `expo-build dev open`.

## Development

```bash
npm test   # unit tests for the config resolver and the Gradle/app.json transforms
```

To release, bump `version` in `package.json` and `claude-plugin/.claude-plugin/plugin.json`, then tag `v<version>`. Projects pin a tag, so changes reach them only when they update the pin.
