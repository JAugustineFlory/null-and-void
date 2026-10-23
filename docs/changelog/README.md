# Changelog entries waiting to go into the README

Every pull request that changes what players see adds **one new file here** instead of editing
the README's Changelog. Separate files never conflict, so pull requests stop blocking each other
on the same README lines.

- Name the file after your branch or change, for example `docs/changelog/high-tops-unlock.md`.
- Write one line per change, in the README's style:
  `- **Added:** block a hit in a real fight to unlock the High-tops.`
  Use **New**, **Added**, **Changed** or **Fixed**.
- No spoilers: describe features, never plot beats, twists or secrets.

The Game design plan thread folds these lines into the README's Changelog when a release ships,
and deletes the files. Each release gets one drop-down, newest first, titled with its version and
date (`v0.8 - 2026-10-30`); fix builds (`v0.8.1`, `v0.8.2`) are listed inside their release's
drop-down. The newest release starts open; the rest start closed. See "Releases" in CLAUDE.md.
