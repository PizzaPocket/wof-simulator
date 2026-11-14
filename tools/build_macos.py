#!/usr/bin/env python3
"""Local/CI macOS pipeline. Credentials stay in the macOS keychain, outside Git.

Preview: python3 tools/build_macos.py
Shareable: MACOS_SIGN_IDENTITY=... MACOS_BUNDLE_ID=... NOTARY_PROFILE=... \
    python3 tools/build_macos.py --release --version 0.1.0 --build 1
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import plistlib
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "game"


def run(*args, capture=False):
    print("+", " ".join(map(str, args)), flush=True)
    return subprocess.run(list(map(str, args)), check=True, text=True,
                          stdout=subprocess.PIPE if capture else None).stdout


def required_assets():
    # A distributable build must not silently ship the development placeholders.
    paths = ["assets/clay.glb", "assets/clay_rig.json", "assets/branding/clay-icon.png",
             "assets/branding/wings-of-fire.svg", "assets/scavengers/umber_pouch.glb"]
    for child in ("kai", "camille", "corinne"):
        paths += [f"assets/scavengers/{child}.glb", f"assets/scavengers/{child}_skin.png",
                  f"assets/scavengers/{child}_cloth.json"]
    missing = [path for path in paths if not (PROJECT / path).is_file()
               or not (PROJECT / path).stat().st_size]
    if missing:
        raise SystemExit("Build the local game assets first (game/README.md):\n" + "\n".join(missing))


def sign(app, identity):
    # Sign nested Mach-O binaries from the inside out; do not use --deep to sign.
    with (app / "Contents" / "Info.plist").open("rb") as stream:
        executable = app / "Contents" / "MacOS" / plistlib.load(stream)["CFBundleExecutable"]
    magics = {b"\xfe\xed\xfa\xce", b"\xce\xfa\xed\xfe", b"\xfe\xed\xfa\xcf",
              b"\xcf\xfa\xed\xfe", b"\xca\xfe\xba\xbe", b"\xbe\xba\xfe\xca",
              b"\xca\xfe\xba\xbf", b"\xbf\xba\xfe\xca"}
    for path in sorted(app.rglob("*"), key=lambda p: len(p.parts), reverse=True):
        # Signing the bundle signs its main executable too; avoid requesting
        # Keychain authorization twice for the same executable.
        if path != executable and path.is_file() and not path.is_symlink():
            with path.open("rb") as stream:
                magic = stream.read(4)
            if magic in magics:
                run("codesign", "--force", "--options", "runtime", "--timestamp", "--sign", identity, path)
    run("codesign", "--force", "--options", "runtime", "--timestamp", "--sign", identity, app)
    run("codesign", "--verify", "--deep", "--strict", "--verbose=2", app)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--release", action="store_true", help="Developer ID sign, notarize, staple and verify")
    parser.add_argument("--version", default="0.1.0")
    parser.add_argument("--build", default="1", help="Increment for each shared build")
    args = parser.parse_args()
    if platform.system() != "Darwin":
        parser.error("Run on a Mac with Godot export templates and Xcode command line tools.")
    if not re.fullmatch(r"\d+\.\d+\.\d+", args.version) or not re.fullmatch(r"[1-9]\d*", args.build):
        parser.error("Use a numeric version such as 0.1.0 and positive integer build number.")
    godot = os.environ.get("GODOT_BIN") or shutil.which("godot") or "/Applications/Godot.app/Contents/MacOS/Godot"
    identity = os.environ.get("MACOS_SIGN_IDENTITY", "")
    bundle_id = os.environ.get("MACOS_BUNDLE_ID", "org.wingsoffire.fanplaytest")
    profile = os.environ.get("NOTARY_PROFILE", "wings-of-fire")
    if not re.fullmatch(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+", bundle_id):
        parser.error("MACOS_BUNDLE_ID must be a reverse-DNS identifier.")
    if args.release:
        if not identity.startswith("Developer ID Application: "):
            parser.error("Set MACOS_SIGN_IDENTITY to your full Developer ID Application identity. See docs/macos-build.md.")
        if bundle_id == "org.wingsoffire.fanplaytest":
            parser.error("Set MACOS_BUNDLE_ID to a unique identifier you control before sharing.")
        identities = run("security", "find-identity", "-v", "-p", "codesigning", capture=True)
        if f'"{identity}"' not in identities:
            parser.error("The selected Developer ID Application certificate/private key is not available in this keychain.")
        run("xcrun", "--find", "notarytool")
        # Fail before exporting if the stored credentials cannot authenticate.
        run("xcrun", "notarytool", "history", "--keychain-profile", profile, capture=True)
    required_assets()
    destination = PROJECT / "exports" / "macos" / ("release" if args.release else "preview")
    destination.mkdir(parents=True, exist_ok=True)
    archive_name = f"WOF-Simulator-{args.version}-{args.build}.zip"
    with tempfile.TemporaryDirectory(prefix=".build-", dir=destination) as work:
        work = Path(work)
        app = work / "WOF Simulator.app"
        run(godot, "--headless", "--path", PROJECT, "--editor", "--import", "--quit")
        run(godot, "--headless", "--path", PROJECT, "--export-release", "macOS", app)
        plist_path = app / "Contents" / "Info.plist"
        with plist_path.open("rb") as stream:
            plist = plistlib.load(stream)
        plist.update(CFBundleIdentifier=bundle_id, CFBundleName="WOF Simulator",
                     CFBundleDisplayName="WOF Simulator",
                     CFBundleShortVersionString=args.version, CFBundleVersion=args.build)
        with plist_path.open("wb") as stream:
            plistlib.dump(plist, stream)
        archive = work / archive_name
        if args.release:
            sign(app, identity)
            submission = work / "notary-upload.zip"
            run("ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", app, submission)
            result = json.loads(run("xcrun", "notarytool", "submit", submission,
                                    "--keychain-profile", profile, "--wait", "--output-format", "json", capture=True))
            # Keep the submission ID/status even if Apple rejects this build.
            (destination / "notarization.json").write_text(json.dumps(result, indent=2) + "\n")
            if result.get("status") != "Accepted":
                raise SystemExit(f"Notarization was not accepted: {result}. Use notarytool log with the submission ID.")
            run("xcrun", "stapler", "staple", app)
            run("xcrun", "stapler", "validate", app)
            run("codesign", "--verify", "--deep", "--strict", "--verbose=2", app)
            run("spctl", "--assess", "--type", "execute", "--verbose=2", app)
        else:
            # Re-sign after editing Info.plist, for local Apple Silicon execution.
            run("codesign", "--force", "--deep", "--sign", "-", app)
            run("codesign", "--verify", "--deep", "--strict", app)
        # Repackage AFTER stapling so the distributed app carries its ticket.
        run("ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", app, archive)
        old_app = destination / app.name
        if old_app.exists():
            shutil.rmtree(old_app)
        shutil.move(str(app), old_app)
        shutil.move(str(archive), destination / archive_name)
    final = destination / archive_name
    with final.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest() if hasattr(hashlib, "file_digest") else hashlib.sha256(stream.read()).hexdigest()
    final.with_suffix(".zip.sha256").write_text(f"{digest}  {final.name}\n")
    print(f"\n{'Signed and notarized release' if args.release else 'Local preview (not notarized; do not share this as a release)'}: {final}")


if __name__ == "__main__":
    try:
        main()
    except (subprocess.CalledProcessError, OSError, ValueError) as error:
        raise SystemExit(f"macOS build failed: {error}") from error
