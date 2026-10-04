---
description: Build a release APK or AAB (debug-signed) and install it on the connected Android device, replacing the current install
---

## Finding the app

The commands run `npx expo-build …` from the Expo app's folder: the one containing `expo-build.config.json`. Find it with `git ls-files --cached --others --exclude-standard "*expo-build.config.json"` from the repo root. If there are several, ask (AskUserQuestion) which app. If there are none, or `expo-build-kit` isn't in that folder's `package.json`, tell the user this project isn't set up for expo-build-kit (see https://github.com/linksman/expo-build-kit#setting-up-a-project) and stop.

When piping the output, capture the real exit code via `${PIPESTATUS[0]}`. Use a long timeout: builds take minutes.

1. Read `expo.version` from the app's `app.json`, show it, and ask (AskUserQuestion) whether to bump **major**, **minor**, **patch**, or leave it unchanged (`no_change`).
2. Ask (AskUserQuestion) for the format: **APK** (recommended; installs directly) or **AAB** (the Play format; installed via a bundletool-derived APK set).
3. Run `npx expo-build install <bump> <apk|aab>` in the app folder.
4. If a gate stops it (dirty tree, a failing check, a missing file, no device or more than one), report the output and let the user decide. Don't work around a gate or fix a failing check unless asked.
5. Report: the format, version and build number, the commit built from and the bump commit, whether a new tag was created or an existing one was kept, the artifact path, and that the install succeeded (or the install error).

Only run this when explicitly asked in the current turn. Don't build proactively or as a side effect of something else.
