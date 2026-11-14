# macOS playtest builds

This pipeline exports a universal app for Apple Silicon and Intel Macs (macOS 12+
as bundle minimum; the selected renderer also needs compatible graphics hardware).
The default build is a local preview. `--release` signs with Developer ID,
submits to Apple for notarization, staples the accepted ticket, verifies Gatekeeper,
and creates the ZIP to send to friends. It never publishes or uploads a release
anywhere except Apple's notarization service.

## One-time setup

1. Install Godot **4.7.1** and the matching export templates through **Editor →
   Manage Export Templates**. Set `GODOT_BIN` if Godot is not in `/Applications` or
   on your PATH. This project uses the standard GDScript build, not .NET.
2. Install Xcode, open it once, accept its license and select its command line
   tools. `xcrun --find notarytool` must work.
3. Enroll in the paid [Apple Developer Program](https://developer.apple.com/programs/).
   In Xcode → Settings → Accounts, add your Apple account, select your team, then
   Manage Certificates → **Developer ID Application**. If that option is unavailable,
   have your team's Account Holder create the certificate. It must include its
   private key in this Mac's keychain. **Apple Development**, **Mac Distribution**
   and **Developer ID Installer** are different certificates.
4. Find the exact signing identity:

   ```sh
   security find-identity -v -p codesigning
   ```

5. Store notarization credentials in Keychain. Run this interactive command and
   enter your Apple ID, ten-character Team ID, and an app-specific password made
   at [Apple Account](https://account.apple.com/). Do not put the password in the
   repository, a script, or chat:

   ```sh
   xcrun notarytool store-credentials "wings-of-fire"
   ```

6. Choose a unique bundle ID under your own namespace, such as
   `com.yourname.wingsoffire.playtest`. Keep it stable for subsequent builds.
   No App Store listing or provisioning profile is needed for this pipeline.

## Build locally

From the repository root, with the generated Clay and villager assets present:

```sh
python3 tools/build_macos.py
```

Output: `game/exports/macos/preview/WOF Simulator.app` and a ZIP plus SHA-256 file.
This app is ad-hoc signed for local testing. It is **not** the version to share
as a notarized release. The builder checks that generated models are present;
fresh clones must follow `game/README.md` to build/copy those ignored assets.

## Build the version to share

This project's current release bundle ID is `com.leonardreese.wofsimulator`,
signed by team `G22BC8W3D6`, with notarization profile `wings-of-fire`.
Keep that bundle ID stable when updating this app.

Replace the identity and namespace with your own. Increment `--build` for each
shared build; use `--version` for the human-readable version.

```sh
export MACOS_SIGN_IDENTITY='Developer ID Application: Your Name (ABCDE12345)'
export MACOS_BUNDLE_ID='com.yourname.wingsoffire.playtest'
export NOTARY_PROFILE='wings-of-fire'
python3 tools/build_macos.py --release --version 0.1.0 --build 1
```

Send `game/exports/macos/release/WOF-Simulator-0.1.0-1.zip` only after the command
succeeds. The ZIP is created **after** stapling. A failed signing, notarization,
stapling or Gatekeeper check stops the pipeline. An older successful ZIP may
remain in the output folder; verify the command succeeded for the build you send.

Friends unzip it, drag **WOF Simulator.app** to Applications, then open it normally.
macOS may show its normal first-download confirmation identifying you as developer;
it should not require bypassing Gatekeeper or removing quarantine. Test the ZIP
after downloading it on another Mac, ideally with a different Apple account.
Apple's notarization service can take time, especially on the first submission.

## Troubleshooting

- **No identity:** install the Developer ID Application certificate and its private
  key in the logged-in user's keychain. Unlock the keychain and allow codesign access.
- **Credentials fail:** rerun `notarytool store-credentials` and confirm Team ID,
  app-specific password, and current Developer Program agreements.
- **Rejected by Apple:** see the submission ID in
  `game/exports/macos/release/notarization.json`, then run:

  ```sh
  xcrun notarytool log SUBMISSION-ID --keychain-profile wings-of-fire
  ```

- **Interrupted while waiting:** inspect `xcrun notarytool history
  --keychain-profile wings-of-fire`. Rerun the pipeline to produce a fully checked
  artifact. Do not distribute the temporary upload archive.
- **Missing templates:** install templates for the exact output of `godot --version`.
- **Build needs regenerated icon:** run the following with the current model built:

  ```sh
  /Applications/Godot.app/Contents/MacOS/Godot --path game --script res://tools/render_app_icon.gd
  ```

The pipeline also runs in a macOS CI runner with Godot/templates, generated assets,
an unlocked keychain containing the signing certificate/private key, and a stored
notary profile. No hosted workflow is enabled: the large generated game assets
are intentionally excluded from this public repository. Do not commit `.p12`,
`.p8`, credentials, or private-key material to make CI work.

## Splash and progress

`scenes/startup.tscn` is the application entry point. It loads Clay, the children,
Umber's satchel, and the village scene through Godot's threaded resource loader,
retaining resources through scene construction. The first 45% reports per-resource
progress; the rest reports completed world-building stages. Terrain reports actual
completed rows, yielding so the bar and label can draw. Percentages are weighted
completion, not estimates of remaining seconds. Heavy synchronous mesh uploads,
character setup and first-use shader compilation may pause within a stage.

Direct F6 runs of the wetland scene and existing gameplay tests still initialize
immediately. Loading failures show the filename and a keyboard-accessible Retry
button. The splash adds no artificial delay.

The copy deliberately says **Private playtest**, not “not for distribution”, since
the intended workflow shares builds with friends. Developer ID signing identifies
the app's developer; it does not make this an official Wings of Fire adaptation
or imply endorsement from its creators. Asset sources are in
`game/assets/branding/CREDITS.md`.

The game starts in native full screen on desktop displays. Its expanding canvas
preserves proportions and fills the available display area at different aspect
ratios and Retina resolutions; 1280 × 800 is the UI reference size, not a fixed
render resolution. macOS manages its usual full-screen Space and display safe area.
Browsers require a user gesture to enter full screen; the native desktop setting
does not bypass that browser restriction.

References: [Godot macOS export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_macos.html),
[Apple Developer ID](https://developer.apple.com/developer-id/),
[Apple notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).
