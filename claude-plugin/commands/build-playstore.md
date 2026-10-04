---
description: Build a release AAB signed with the upload key, for Play Store submission (no device install)
---

## Finding the app

The commands run `npx expo-build …` from the Expo app's folder: the one containing `expo-build.config.json`. Find it with `git ls-files --cached --others --exclude-standard "*expo-build.config.json"` from the repo root. If there are several, ask (AskUserQuestion) which app. If there are none, or `expo-build-kit` isn't in that folder's `package.json`, tell the user this project isn't set up for expo-build-kit (see https://github.com/linksman/expo-build-kit#setting-up-a-project) and stop.

When piping the output, capture the real exit code via `${PIPESTATUS[0]}`. Use a long timeout: builds take minutes.

1. Read `expo.version` from the app's `app.json`, show it, and ask (AskUserQuestion) whether to bump **major**, **minor**, **patch**, or leave it unchanged (`no_change`).
2. Run `npx expo-build playstore <bump>` in the app folder.
3. If a gate stops it (dirty tree, a failing check, a missing file, no device or more than one), report the output and let the user decide. Don't work around a gate or fix a failing check unless asked. A missing keystore, env file or password is a one-time setup step: point the user at the README's signing section rather than creating one.
4. Report: the version and build number, the commit built from and the bump commit, whether a new tag was created, the artifact path, and the "Signed by" line (it must not be an Android Debug cert; the command fails if it is). Remind the user this is the file to upload to Play Console; there's no device install.

Only run this when explicitly asked in the current turn. Don't build proactively or as a side effect of something else.
