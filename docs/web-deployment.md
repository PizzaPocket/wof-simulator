# Deploying the Godot game to Vercel

The web version is a static Godot WebAssembly export, using WebGL 2 / the
Compatibility renderer. Desktop keeps Forward+. The Web preset disables threads,
so cross-origin isolation headers are not required.

## Export locally

Use the same Godot version as your installed export templates (currently 4.7.1).
The generated `game/assets/clay.glb` and `clay_rig.json` must already exist; see
[the model build instructions](../game/README.md). They are deliberately ignored
by Git, so a fresh GitHub checkout does not have them.

From the repository root:

```sh
bash tools/export_web.sh
python3 -m http.server 8000 --directory game/exports/web
```

Open http://localhost:8000 in a WebGL 2 browser. Click the game to capture the
mouse; Esc releases it. Help starts collapsed; H, controller Back/Share, or the
`(H)elp` button opens the controls and diagnostics. This prototype is designed
for keyboard/mouse or a controller; it has no touch movement controls.

If Godot is installed elsewhere, use `GODOT_BIN=/path/to/godot bash tools/export_web.sh`.
Install matching templates through Godot's **Editor → Manage Export Templates**
if the export reports that they are missing.

## Link and deploy

The current export is about **478 MiB** (440 MiB PCK plus 38 MiB WASM). This
exceeds Vercel Hobby's **100 MB** CLI upload limit; Pro allows **1 GB**.
See [Vercel's upload limits](https://vercel.com/docs/limits#static-file-uploads).
For Hobby, reduce the runtime model or host the large asset pack separately before
deploying. These commands do not bypass the plan limit.

Create the Vercel project with the **Other** framework preset. Deploy the
exported folder, which includes its own `vercel.json` and needs no build command:

```sh
cd game/exports/web
npx vercel link
npx vercel
```

Select your existing Vercel project during linking. The second command creates a
preview deployment. After reviewing it, publish with:

```sh
npx vercel --prod
```

For subsequent changes, rerun `bash tools/export_web.sh` from the repository root,
then deploy from `game/exports/web`. The export keeps that folder's `.vercel`
project link. Never commit `.vercel` or credentials.

## GitHub-linked projects

Connecting GitHub alone cannot build this game yet: Vercel does not have Godot,
its matching export templates, or the ignored generated Clay assets. The local
export above lets you deploy the current model immediately.

For automatic deployments, first provide the generated assets to CI (for
example through an artifact store), install the pinned Godot binary and web
templates in CI, then export and deploy the static output to the linked Vercel
project. Do not point a Git build at `game/exports/web`: it is ignored and does
not exist in a fresh checkout. Do not add the 223 MB source GLB to regular Git.

The initial download and browser memory use are substantial with the current
detailed model. Verify the export in your target browser before sharing it;
web performance and lighting can differ from Forward+ on the desktop.
