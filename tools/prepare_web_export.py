"""Stage an isolated Godot web project, then compress its deployable binaries."""
import gzip
import hashlib
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "game"
STAGE = ROOT / "cache/web-build/game"
OUTPUT = SOURCE / "exports/web"


def prepare():
    sys.path.insert(0, str(SOURCE / "tools"))
    from optimize_web_model import optimize

    STAGE.mkdir(parents=True, exist_ok=True)
    for name in ("scripts", "scenes", "shaders", "data"):
        shutil.copytree(SOURCE / name, STAGE / name, dirs_exist_ok=True)
    for name in ("project.godot", "export_presets.cfg"):
        shutil.copy2(SOURCE / name, STAGE / name)
    (STAGE / "assets").mkdir(exist_ok=True)
    shutil.copy2(SOURCE / "assets/clay_rig.json", STAGE / "assets/clay_rig.json")
    digest = hashlib.sha256()
    for path in (SOURCE / "assets/clay.glb", SOURCE / "tools/optimize_web_model.py"):
        with path.open("rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(chunk)
    fingerprint = digest.hexdigest()
    stamp = STAGE.parent / "model.sha256"
    model = STAGE / "assets/clay.glb"
    if not model.exists() or not stamp.exists() or stamp.read_text() != fingerprint:
        optimize(SOURCE / "assets/clay.glb", model)
        stamp.write_text(fingerprint)
    # Web-only import choices. Desktop imports and source files stay untouched.
    settings = (SOURCE / "assets/clay.glb.import").read_text()
    settings = settings.replace("meshes/generate_lods=true", "meshes/generate_lods=false")
    settings = settings.replace("meshes/create_shadow_meshes=true", "meshes/create_shadow_meshes=false")
    imported = STAGE / "assets/clay.glb.import"
    if not imported.exists() or imported.read_text() != settings:
        imported.write_text(settings)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    (SOURCE / "exports/.gdignore").touch()


def finalize():
    for name in ("index.wasm", "index.pck"):
        path = OUTPUT / name
        temporary = path.with_suffix(path.suffix + ".tmp")
        with path.open("rb") as source, temporary.open("wb") as target:
            with gzip.GzipFile(filename="", mode="wb", fileobj=target, compresslevel=6, mtime=0) as compressed:
                shutil.copyfileobj(source, compressed)
        temporary.replace(path)
    shutil.copy2(SOURCE / "web/vercel.json", OUTPUT / "vercel.json")
    files = [p for p in OUTPUT.rglob("*") if p.is_file() and ".vercel" not in p.relative_to(OUTPUT).parts]
    size = sum(p.stat().st_size for p in files)
    print(f"Deployable web build: {size / 1_000_000:.1f} MB ({size / 1024**2:.1f} MiB)")
    if size > 100_000_000:
        raise SystemExit("Web export exceeds Vercel Hobby's 100 MB upload limit; deployment stopped.")


if __name__ == "__main__":
    {"prepare": prepare, "finalize": finalize}[sys.argv[1]]()
