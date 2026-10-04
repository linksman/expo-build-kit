---
description: Publish a JS-only hotfix over the air (EAS Update) to installed builds on the preview or production channel
---

## Finding the app

The commands run `npx expo-build …` from the Expo app's folder: the one containing `expo-build.config.json`. Find it with `git ls-files --cached --others --exclude-standard "*expo-build.config.json"` from the repo root. If there are several, ask (AskUserQuestion) which app. If there are none, or `expo-build-kit` isn't in that folder's `package.json`, tell the user this project isn't set up for expo-build-kit (see https://github.com/linksman/expo-build-kit#setting-up-a-project) and stop.

When piping the output, capture the real exit code via `${PIPESTATUS[0]}`. Use a long timeout: builds take minutes.

1. Ask (AskUserQuestion) which channel: **preview** (sideloaded `/build-install` builds; recommended first, so the fix can be checked on the test device) or **production** (Play Store builds). Ask for a one-line message describing the fix if the user hasn't given one.
2. Run `npx expo-build hotfix <channel> "<message>"` in the app folder.
3. It stops on its own gates; if it does, report the output and let the user decide. Don't work around a gate:
   - **Dirty tree**: commit or stash first.
   - **No release tag for the current version**: nothing installed can receive this update.
   - **Native-affecting files changed since that tag**: the fix needs a new store build (`/build-playstore`), not an OTA update. JS that calls native code the installed binary lacks would crash it.
   - **Failing checks.**
4. Report the channel, the runtime version it targets, the `ota-…` git tag it created and pushed, and that installed builds download it on their next launch and run it on the launch after that.

To roll back, re-publish from an earlier commit or run `npx eas update:rollback`. Only run this when explicitly asked in the current turn.
