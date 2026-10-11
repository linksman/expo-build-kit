---
description: Pull first (stops unless already up to date), run npm run check (typecheck, lint, tests), then stage all changes, commit with an auto-generated message, and push to the current branch (blocked if the check fails)
---

## Finding the app

The check runs in the Expo app's folder: the one containing `expo-build.config.json`. Find it with `git ls-files --cached --others --exclude-standard "*expo-build.config.json"` from the repo root (it may be the root itself, or a subfolder such as `frontend/`). If there are several, ask (AskUserQuestion) which app. If there are none, tell the user this project isn't set up for expo-build-kit (see https://github.com/linksman/expo-build-kit#setting-up-a-project) and stop.

## Steps

Stage, commit, and push everything currently changed in this repo:

1. Pull first, before looking at or running anything else: run `git pull --ff-only` from the repo root. Judge it by what it prints on stdout: continue only if that is exactly `Already up to date.` On anything else, stop immediately and don't stage, commit or push. That covers new commits pulled in, a pull that fails, diverged branches and conflicts with local changes. Show the user the output and let them decide how to proceed. (Fetch lines on stderr such as `From github.com:…` don't count on their own.) If the current branch has no upstream yet, there's nothing to pull: skip this step.
2. Run `git status` and `git diff` (staged + unstaged) to see everything that changed, and `git log --oneline -10` to match this repo's commit message style. If the repo has no commits yet, use the house style: short, lowercase, no trailing period (e.g. "session composer", "currency button").
3. Run `npm run check` in the app folder: typecheck, lint and tests, the same script CI runs. Judge it by its exit code (when piping the output, capture it via `${PIPESTATUS[0]}`); `expo lint`'s last line counts only auto-fixable problems, so it can say "0 errors" when there are some. If it fails, stop immediately: do not stage, commit, or push anything. Report the failing command's output to the user and let them decide how to proceed. Don't attempt to fix the failure yourself unless they ask.
4. Stage all changes with `git add -A`. If anything looks like it might be a secret, stop and warn instead of staging it: `.env*`, `keystores/`, `*.jks`, credentials, keys, and the files named by `requiredFiles` and `envFile` in `expo-build.config.json` (e.g. `google-services.json`). These should be gitignored, so one showing up means something is misconfigured.
5. Write a commit message: a short lowercase title line (in this repo's style, no trailing period), then a blank line, then a bulleted list (`- `) with one bullet per distinct change, so a reader can scan the body instead of parsing prose. Keep each bullet to one line. End with the attribution trailer(s) this session is configured to add to commits (the `Co-Authored-By:` line for the current model, plus any session link it specifies). Never copy a trailer from an earlier commit.
6. Commit, then push to the current branch's upstream (`git push`). If the branch has no upstream yet, push with `git push -u origin <current-branch-name>`.
7. Report the commit hash and confirm the push succeeded.

If there is nothing to commit, say so and stop. Don't create an empty commit.
