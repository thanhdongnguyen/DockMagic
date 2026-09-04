# DockMagic software updates

DockMagic uses Sparkle 2 for direct-distribution updates. The app is not tied
to the Mac App Store. Update archives still pass the normal DockMagic release
gates: Developer ID signing, Hardened Runtime, notarization, stapling, and
Gatekeeper validation.

## Runtime behavior

- The stable feed URL is
  `https://github.com/thanhdongnguyen/DockMagic/releases/latest/download/appcast.xml`.
- DockMagic checks the feed once per day by default. Users can turn automatic
  checks and background downloads on or off in General settings.
- A normal scheduled update appears as a gentle `Update available` row at the
  bottom-left of Settings. Selecting the row opens Sparkle's signed update UI.
- A critical update may be brought to the foreground by Sparkle.
- `Check for Updates…` is also available in the application menu.

The updater compares `CFBundleVersion`, not only the marketing version. Every
release therefore needs a monotonically increasing `CURRENT_PROJECT_VERSION`.

## Signing key

The public EdDSA key is committed in `DockMagic/DockMagic/Info.plist`. The
matching private key is stored in the macOS login Keychain under the Sparkle
account `DockMagic`; it must never be committed to the repository or printed in
release logs. Back it up through Sparkle's `generate_keys -x` flow and store the
backup in the team's secret manager.

For CI, import the private key only into an ephemeral Keychain or pass it to
Sparkle through `--ed-key-file -`. Never write the decoded private key into the
checkout.

## Preparing the appcast

After creating and fully validating `DockMagic-<version>.dmg`, place that DMG
and optional matching Markdown release notes in an otherwise empty staging
directory. Resolve Sparkle through Xcode, then run:

```bash
script/generate_update_appcast.sh \
  <version> \
  <staging-directory> \
  <derived-data>/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast
```

The script uses the `DockMagic` Keychain account, signs the archive entry, and
requires the appcast enclosure URL to point to the immutable tag-specific GitHub
asset. Upload all three release assets:

- `DockMagic-<version>.dmg`
- `DockMagic-<version>.dmg.sha256`
- `appcast.xml`

The published release must be stable for GitHub's `/releases/latest/` redirect
to resolve it. Prereleases need a separate channel/feed design and must not
replace the stable feed by accident.

## Release verification

Before publishing, verify the draft assets, download them into a fresh temporary
directory, and check that:

1. the DMG checksum matches;
2. the DMG and mounted app pass stapling and Gatekeeper checks;
3. `appcast.xml` contains the expected tag-specific DMG URL and an
   `sparkle:edSignature`;
4. the feed URL returns the uploaded appcast after publication;
5. an installed previous updater-enabled build discovers, downloads, and opens
   the new signed build through Sparkle.

Version 1.0.1 does not contain Sparkle, so the first updater-enabled release
must still be installed manually. Automatic updates become available from that
release onward.
