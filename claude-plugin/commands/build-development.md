---
description: Build and install the development build (debug + expo-dev-client) that loads JS live from Metro
---

## Finding the app

The commands run `npx expo-build …` from the Expo app's folder: the one containing `expo-build.config.json`. Find it with `git ls-files --cached --others --exclude-standard "*expo-build.config.json"` from the repo root. If there are several, ask (AskUserQuestion) which app. If there are none, or `expo-build-kit` isn't in that folder's `package.json`, tell the user this project isn't set up for expo-build-kit (see https://github.com/linksman/expo-build-kit#setting-up-a-project) and stop.

When piping the output, capture the real exit code via `${PIPESTATUS[0]}`. Use a long timeout: builds take minutes.

1. If the user only wants to reconnect an already-installed dev build (for example after replugging the phone), run `npx expo-build dev open`. It skips the build.
2. Otherwise run `npx expo-build dev` in the app folder.
3. If it stops (no device, `expo-dev-client` not installed), report it and let the user decide.
4. Report the APK path and remind the user how to use it:
   - Keep Metro running with `npx expo start` (port 8081; set `METRO_PORT` for both if using another). Edits then appear on the phone without rebuilding.
   - Rebuild only after native-affecting changes (dependencies, `app.json`/`app.config.*`, `plugins/`, `patches/`, `modules/`).
   - Don't press `a` in the Expo CLI when the app uses the `dev-variant` plugin: it opens the main package id, not the suffixed one. Use `npx expo-build dev open` or the launcher icon.
   - Debug builds are slower; check performance and final behavior with `/build-install`.

Only run this when explicitly asked in the current turn. Don't build proactively or as a side effect of something else.
