---
description: Preview the commit message commit-push would use, without staging, committing, or pushing anything
---

Compose the commit message for everything currently changed in this repo, and print it to the screen. Do not stage, commit, or push anything.

1. Run `git status` and `git diff` (staged + unstaged) to see everything that changed, and `git log --oneline -10` to match this repo's commit message style. If the repo has no commits yet, use the house style: short, lowercase, no trailing period (e.g. "session composer", "currency button").
2. Write a commit message exactly as `commit-push` would: a short lowercase title line (in this repo's style, no trailing period), then a blank line, then a bulleted list (`- `) with one bullet per distinct change, so a reader can scan the body instead of parsing prose. Keep each bullet to one line. End with the attribution trailer(s) this session is configured to add to commits (the `Co-Authored-By:` line for the current model, plus any session link it specifies). Never copy a trailer from an earlier commit.
3. Print the complete message in a fenced code block in your reply, and nothing else of substance: no analysis, no offer to commit. Do not run `git add`, `git commit`, or `git push`.

If there is nothing changed to describe, say so and stop.
