---
name: dockmagic-github-release
description: Prepare and publish DockMagic macOS versions with GitHub CLI. Use when discovering the current GitHub release version, validating a newer release from a non-main branch, passing the full test gates, producing a verified Developer ID DMG, publishing a GitHub Release, and merging the released commit into main.
---

# DockMagic GitHub Release

Release DockMagic from the current feature or release branch. Keep all release notes, changelog entries, commit messages, tag titles, and user-facing release output in English.

## Release contract

- Distribute DockMagic directly, never through the Mac App Store.
- Use Developer ID Application signing, Hardened Runtime, Apple notarization, stapling, and Gatekeeper verification. Never substitute an ad-hoc or unsigned production artifact.
- Use `origin` and `main` unless repository inspection proves a different configured remote or default branch.
- Discover and report the current published GitHub version before accepting the target version or starting any release build.
- Use a semantic version supplied or approved by the user. Format the tag as `v<version>` and the primary asset as `DockMagic-<version>.dmg`.
- Require a fresh full `DockMagicTests` run with every discovered unit test passing before archive or DMG creation. Focused reruns never replace this gate.
- Build from the exact commit referenced by the release tag. Keep build products in a unique temporary directory outside the repository.
- Publish the GitHub Release before merging the released branch into `main`, as requested for this repository.

## Authorization and stopping rules

Read-only inspection, local note drafting, builds, and tests may proceed without a remote mutation.

Require two explicit checkpoints:

1. Before creating the release-preparation commit, show the intended version, build number, changelog entry, and exact staged files.
2. Before the first remote mutation, show the release commit, tag, DMG path, size, SHA-256, verification results, release notes, source branch, and planned `main` update.

Do not stash, discard, reset, clean, force-push, move an existing tag, overwrite an existing release asset, delete a release, or delete a branch without separate explicit authorization. Never print or store signing passwords, Apple credentials, GitHub tokens, or notarization secrets in the repository.

Stop at the first failed required check. If a remote step has already succeeded, report the exact partial state and resume idempotently; do not attempt an automatic rollback. Never merge into `main` unless the GitHub Release is published (non-draft) and its uploaded asset has been verified.

## 1. Establish release inputs and repository state

1. Resolve the repository root with `git rev-parse --show-toplevel` and run from it.
2. Verify that `git`, `gh`, `xcodebuild`, `xcrun`, `codesign`, `security`, `spctl`, `hdiutil`, and `shasum` are available.
3. Verify GitHub authentication with `gh auth status`, resolve the repository with `gh repo view`, and confirm that the authenticated account can push to the target repository.
4. Query GitHub before requesting or accepting the target version:
   - Run `gh release list --limit 100 --json tagName,name,isDraft,isPrerelease,isLatest,publishedAt` to record the complete visible release state, including drafts and prereleases.
   - Run `gh release list --exclude-drafts --exclude-pre-releases --limit 1 --json tagName,publishedAt,isLatest` to resolve the latest published stable release.
   - Run `gh release list --exclude-drafts --limit 1 --json tagName,isPrerelease,publishedAt` to resolve the most recent published release of any type.
   - If a release exists, inspect it with `gh release view <tag> --json tagName,name,targetCommitish,isDraft,isPrerelease,publishedAt,url,assets` and record its tag, version, target, publication state, and asset names.
   - If GitHub has no published release, record that explicitly instead of treating a local project version as the published baseline.
5. Show the discovered GitHub baseline to the user. Then require an approved target semantic version and ask whether it is stable or prerelease when unclear. For a normal stable release, require the target to be newer than the latest published stable version.
6. Require an existing `notarytool` Keychain profile, supplied by the user or through `DOCKMAGIC_NOTARY_PROFILE`. Never ask the user to paste notarization credentials.
7. Fetch `origin`, record the current `origin/main` commit, and inspect remote tags. Require a named current branch that is not `main`, no unresolved conflicts, and no in-progress merge or rebase.
8. Record all committed, staged, unstaged, and untracked changes. Treat the entire intended source snapshot as release scope, but stage only files the user has approved.
9. Treat `.derivedData*`, `build`, `dist`, archives, exported apps, DMGs, notarization logs, and temporary plists as generated artifacts. Never add them to a release commit. If generated artifacts are already tracked on the current branch, report them and obtain approval for a separate cleanup rather than silently removing them.
10. Reject the target version when its local tag, remote tag, or GitHub Release already exists. Do not infer the GitHub version solely from `MARKETING_VERSION`, local tags, or the branch name.

## 2. Capture changes against main

Use `origin/main` as the comparison base after fetching. Inspect at least:

- `git log --no-merges origin/main..HEAD`
- `git diff --stat origin/main...HEAD`
- `git diff --name-status origin/main...HEAD`
- staged, unstaged, and untracked work reported by `git status`

Read the meaningful code and documentation changes rather than deriving notes only from commit subjects. Separate user-visible additions, behavior changes, fixes, and internal work. Exclude generated files, build output, secrets, and claims that cannot be verified.

Create or update `CHANGELOG.md` in a Keep a Changelog-style structure. Add a dated section for the target version with only applicable `Added`, `Changed`, `Fixed`, and `Security` subsections. Preserve previous entries. Also prepare a temporary GitHub release-notes file containing:

- a concise summary and highlights
- user-visible additions, changes, and fixes
- compatibility or migration notes when applicable
- verification performed
- DMG installation guidance
- a full-changelog comparison link when available

## 3. Update version metadata, pass test gates, and commit release preparation

1. Update the DockMagic app target's Debug and Release `MARKETING_VERSION` values in `DockMagic/DockMagic.xcodeproj/project.pbxproj` to the approved semantic version.
2. Increment `CURRENT_PROJECT_VERSION` monotonically. Keep test-target values consistent when they already follow the app version convention.
3. Confirm that `DockMagic/DockMagic/Info.plist` still resolves `CFBundleShortVersionString` and `CFBundleVersion` from those build settings.
4. Run `git diff --check` and stop on any whitespace error.
5. Create a unique Derived Data directory outside the repository and run the complete documented unsigned unit-test lane with `CODE_SIGNING_ALLOWED=NO` and `-only-testing:DockMagicTests`. Do not reuse a result produced before the current release-scope changes.
6. Inspect the resulting XCResult summary. Require a nonzero discovered test count, command exit status zero, zero failed tests, and zero skipped tests. Record the exact command, Xcode version, macOS version, total count, passed count, failed count, skipped count, and XCResult path.
7. Run relevant focused tests as additional evidence when a changed subsystem needs them. A focused pass never substitutes for the complete unit-test lane in step 5.
8. Run the complete signed `DockMagicUITests` lane when the release changes user flows and a valid Apple Development identity is available. Use a separate Derived Data directory, inspect its XCResult summary, and stop on any failure. If the lane cannot run, report the exact reason and obtain approval before treating it as skipped.
9. Stage only the approved source, tests, documentation, version metadata, changelog, and repository-local skill changes. Show `git diff --cached --stat`, `git diff --cached --name-status`, the GitHub version baseline, and the drafted changelog entry at the first checkpoint.
10. After approval, commit with `chore(release): prepare v<version>`. Require a clean worktree before packaging. Do not push yet.

If tests or packaging later fail, leave the local preparation commit intact and report it; do not rewrite or discard it automatically.

## 4. Build and verify the distributable DMG

Create a unique release workspace with `mktemp -d` under the system temporary directory. Do not build into `.derivedData` or `.derivedData-release` inside the repository.

Immediately before archiving, query the latest GitHub releases again and repeat the target tag/release collision checks. Confirm that the GitHub version baseline has not changed, the worktree is clean, `HEAD` is the approved release commit, and no release-scope file changed after the required unit-test pass. If any source, test, build setting, entitlement, or packaging input changed, rerun the complete unit-test gate before continuing.

1. Archive `DockMagic/DockMagic.xcodeproj`, scheme `DockMagic`, configuration `Release`, for `generic/platform=macOS` with `xcodebuild archive` and a temporary `.xcarchive` path.
2. Export the archive with a temporary `ExportOptions.plist` using the `developer-id` method and the repository's configured development team. Keep this plist outside the repository.
3. Locate the exported `DockMagic.app` and verify:
   - its short version and build number equal the release metadata
   - its executable architectures match the project configuration
   - its designated requirement, Team ID, timestamp, Hardened Runtime, nested signatures, and entitlements are valid
   - `codesign --verify --deep --strict` succeeds
4. Stage the app in a temporary DMG source directory with an `Applications` symlink. Create a compressed read-only DMG with `hdiutil`, then sign the DMG with the resolved Developer ID Application identity and a secure timestamp.
5. Submit the DMG with `xcrun notarytool submit --keychain-profile <profile> --wait`. Require an accepted result and retain the submission ID in the release report.
6. Staple and validate the ticket with `xcrun stapler`. Run Gatekeeper assessment on the DMG and on the app mounted from the DMG.
7. Apply a quarantine attribute to a copied artifact and perform a local launch smoke test without bypassing Gatekeeper. Do not treat this as a replacement for the repository-required clean-Mac smoke test.
8. Compute a SHA-256 checksum and create `DockMagic-<version>.dmg.sha256` beside the DMG. Verify the checksum before upload.
9. Locate the resolved Sparkle `generate_appcast` executable under the release Derived Data directory. In an otherwise empty staging directory containing the validated `DockMagic-<version>.dmg` and optional matching Markdown release notes, run `script/generate_update_appcast.sh <version> <staging-directory> <generate-appcast-path>`. Require `appcast.xml` to reference the immutable `releases/download/v<version>/DockMagic-<version>.dmg` URL and contain a `sparkle:edSignature`. The private EdDSA key must remain in the Keychain account `DockMagic` or an ephemeral CI secret and must never enter the repository.

Do not continue when signing, notarization, stapling, Gatekeeper, version, architecture, test, or launch verification fails.

## 5. Create and verify a draft GitHub Release

At the second checkpoint, obtain approval for the complete remote plan. Then:

1. Push the current release branch without force and verify that the remote branch points to the local release commit.
2. Create an annotated `v<version>` tag on that exact commit and push only that tag. Abort on any collision.
3. Create a draft GitHub Release with `gh release create --verify-tag`, targeting the tagged commit. Upload the DMG, its SHA-256 file, and `appcast.xml`; use `DockMagic <version>` as the title and pass the prepared notes with `--notes-file`. Add `--prerelease` only when approved. The stable updater feed uses GitHub's `/releases/latest/` redirect, so a prerelease must not replace or reuse the stable feed without a separately approved channel design.
4. Inspect the draft with `gh release view`. Verify the tag, target commit, draft status, asset names, and asset sizes. Download the uploaded assets to a separate temporary directory, verify their SHA-256 checksum, and verify that the downloaded appcast references the immutable tag-specific DMG URL with an EdDSA signature.
5. Keep the release as a draft until the user confirms that the downloaded DMG passed a Gatekeeper installation and launch smoke test on a clean compatible Mac. If that confirmation is unavailable, report the draft URL and stop.

## 6. Publish, merge into main, and verify

Immediately before publishing, fetch `origin` again and check whether `origin/main` changed from the recorded base. If it changed, keep the release as a draft and stop for an explicit reconciliation decision; do not move the tag or replace the asset automatically.

After the clean-Mac confirmation and the unchanged-main check:

1. Publish the draft with `gh release edit v<version> --draft=false` and verify that the release is no longer a draft.
2. Switch to local `main`, update it from `origin/main` with `--ff-only`, and fast-forward it to the tagged release commit. If a fast-forward is impossible, stop rather than create an unreviewed merge commit.
3. Push `main` to `origin` without force.
4. Verify that `origin/main` contains the release tag commit and that the published GitHub Release still exposes the expected DMG, checksum, and `appcast.xml` assets. Fetch `https://github.com/thanhdongnguyen/DockMagic/releases/latest/download/appcast.xml` and require it to resolve to the published stable release.
5. From an installed previous updater-enabled version, run `Check for Updates…`, confirm the Settings footer reports the new version, and complete a signed update smoke test. The first Sparkle-enabled release still requires a manual install because v1.0.1 has no updater.
5. Do not delete the source branch unless the user separately requests it.

## Final report

Report the version, build number, tag, release URL, release commit SHA, source branch, final `origin/main` SHA, DMG filename and SHA-256, appcast asset and immutable enclosure URL, architectures, signing identity summary, notarization submission ID, tests and update smoke tests performed, and any skipped optional validation. Never include secret values.
