# Bare playable world terrain

F5 opens the world map. Drag and zoom to any landmass, then hover/focus a pin and
click or press Enter/A. Every starting point below is a pin, and Pyrrhia keeps the
separate MudWing village pin beside its Mud Kingdom start.

The terrain scenes contain ground, basic biome colors, connected mountain ranges,
foothills, broad hills, shores, ocean, major authored rivers/lakes and collision.
They do not build vegetation, buildings, villagers, settlement scenery or quests.
Flight gradually builds to 60 m/s cruise or 180 m/s while holding Shift / LB.
Releasing boost coasts back to cruise. Steep upward aim supports climbing up to
45 m/s normally or 110 m/s boosted, with no overhead altitude cap.

Only the player model is requested by these terrain destinations, not the village
cast. The existing detailed village remains a separate destination.

The starting-point selector moves within the current continent and prepares its
nearby ground before movement resumes. Pyrrhia offers ten starting points
(including the Sea Kingdom islands, the northern cape and the southern islets),
Pantala seven, the Forgotten Isles seven (with three outlying islands) and
NightWing Island six. Starts are the `entries` in `data/terrain/world_regions.json`;
the map pins and the in-game selector both read them, so adding an entry there and
rebaking adds a pin. Near the Mud Kingdom starting point,
**Enter MudWing village** loads the existing village through the measured loader.
**M / controller Start** or **World map** returns to the atlas. Ocean swimming is
not part of this pass: falling into deep water returns to the selected start.

## Geographic choices and limits

`data/terrain/world_regions.json` is the editable source of geographic rules.
`game/data/pyrrhia_coast.json` supplies Pyrrhia's existing extracted coastline;
the other coasts were authored from the reference maps, preserving horizontal
aspect ratio. The atlas and terrain consume the same generated geometry rules.
These are simplified interpretations, not surveyed geography or a claim to trace
every rock in the illustration. Elevations, small hills, mountain profiles,
biome transitions and river depths are authored.

| Terrain scene | Map footprint, including sea | Scale basis |
| --- | --- | --- |
| Pyrrhia | 320.00 × 237.38 km | Streaming milestone: 10× former travel distances, exact 2165:1606 proportions |
| Pantala | 320.00 × 249.82 km | Tenfold gameplay expansion; exact 1792:1399 reference proportions |
| Forgotten Isles | 120.00 × 125.29 km | Main island inset and nearby small islands; provisional physical scale |
| NightWing Island | 100.00 × 64.08 km | Island map window; provisional physical scale |

Pyrrhia was the first expanded streaming test; all four maps now use the same
disk streaming system. Its mountains retain their
roughly 2.5 km maximum height, with fourfold broader widths and approaches. At
full 180 m/s boost, the full map width takes about 30 minutes; at 60 m/s cruise,
about 89 minutes. Individual journeys are shorter than the full map width.
Pantala and both island maps have also been expanded tenfold in width, retaining
their previous relative horizontal proportions. Mountain widths and volcanic
approaches broaden fourfold while elevations are retained.

Separate book illustrations do not establish a shared measured scale. Pantala's
relative size and the islands' widths remain explicit gameplay choices. They
can be changed with `width_m` and rebaked. The world map shows all four
landmasses together using one uniform metre scale and illustrative spacing. The Forgotten Isles scene represents
the enlarged main island (Dungeon Isle) and nearby inset islands; it does not
invent land for every tiny dot across the outer ocean overview.

`world_offset_m` records illustrative placement relative to Pyrrhia, including
Pantala to the west, the Forgotten Isles to the south and NightWing Island to the
northeast of the Sky Kingdom tip as requested. These are **separate playable
scenes**, accessed through the atlas; the offsets do not create a seamless shared
ocean or establish canonical intercontinental distances.

## References

Downloaded artwork stays in ignored `cache/maps/` and is not shipped or committed.
The runtime uses original geometry, generated height samples and simple biome
colors, never the illustrated source maps.

- [Pyrrhia colored map](https://wingsoffire.fandom.com/wiki/File:PyrrhiaColored.png),
  cross-checked against the guide map already cached in this project.
- [Pantala colored map](https://wingsoffire.fandom.com/wiki/File:PantalaColored.jpg),
  cross-checked against the *A Guide to the Dragon World* map.
- [Forgotten Isles map](https://wingsoffire.fandom.com/wiki/File:Forgotten_Isles_Map.jpg)
  from *The Hybrid Prince*, especially the enlarged island inset.
- [Volcanic NightWing island map](https://wingsoffire.fandom.com/wiki/File:NightWing_island_(a_guide_to_the_dragon_world_BN_preview,_wings_of_fire).jpg)
  from *A Guide to the Dragon World*.

## Terrain pipeline

```sh
PYTHONPATH=cache/map-python python3 tools/map/build_terrain.py
```

Or install `tools/map/requirements.txt` into a virtual environment and run the
script with that environment's Python. Reference downloads can be restored with
`tools/map/fetch_sources.py`; baking does not require artwork because the authored
rules and coastlines are versioned.

`--only pyrrhia` rebuilds one map. `--resolution 1024` produces smaller grids;
default is 2048 intervals across continent maps and 1024 across island maps.
Macro height grids have endpoint-aligned samples: about 156 m on expanded
Pyrrhia and Pantala, 58.6 m on the Forgotten Isles and 48.8 m on NightWing Island.
Nearby meshes sample at 32 m, interpolating the macro terrain
with continuous small relief and analytic lake/river channels. These samples do
not claim 32 m geographic source detail. Generation checks finite samples and
dry starting points.

Small outputs (definitions and color/ocean masks) are committed under
`game/data/terrain/` and `game/assets/terrain/`. The large `.height` files,
`.rgb` overviews and `*_pages/` directories (about 150 MB) are git-ignored and
rebuilt by this script:

- JSON definitions include map dimensions, metre extents, starts and terrain rules.
- `.height` files are row-major little-endian float32 heights in metres, north to
  south. Export presets explicitly include this custom file type.
- Color PNGs store original procedural biome ground colors. Ocean mask PNGs
  derive from the same heightfield and prevent distant water from drawing over
  low land. PNG metadata records their procedural provenance.
- Ignored `cache/terrain-review/` holds relief overviews and Godot captures.

## Terrain disk streaming

`tools/map/prepare_streaming.py` runs automatically after each map bake. It
splits the source grids into independent `.page` files (192 pages / about 21.3 MiB
on disk for Pyrrhia), each containing 129 × 129 float32 heights followed by RGB bytes.
Shared endpoint samples ensure continuous page borders. The full `.height` and
color PNG remain build sources; the streamed runtime does not open them.
Export presets include `.page`, `.rgb`, `.height` and definition files.

Only a small overview stays resident across each entire map: **257 × 191** for
Pyrrhia (about 336 KiB of height/color payload). Other maps preserve their own
aspect ratios at the same overview width. A reader caches at most four pages; each
background job owns its own reader/cache, avoiding shared mutable resources.
Finished jobs release their pages. A coarse, always-visible mesh represents
distant land; a small coverage texture hides it exactly where streamed tiles
have been installed, preventing overlapping representations.

The nearby terrain uses **2048 m tiles**. Near tiles have 64 × 64 grid cells
(32 m spacing) and `HeightMapShape3D` collision. Medium tiles have 16 × 16 cells
(128 m spacing) and no collision. Heightfield collision uses uniform scaling
and correspondingly prescaled heights, compatible with GodotPhysics and Jolt.
Collision registration occurs on a separate frame from mesh installation.

Interest combines a 3 × 3 landing neighborhood, a 7 × 7 medium neighborhood,
and an **eight-second velocity lookahead**. At most two worker jobs read pages
and generate CPU vertex/index/color/height arrays. GPU uploads, scene changes
and physics installation occur on the main thread, at most one such operation
per frame. A 3 ms soft commit budget stops further scheduling that frame;
individual native operations cannot be preempted, so overruns are counted.

Tiles outside the interest region are removed, releasing their geometry and
collision. Stale jobs after turns/teleports are drained and discarded. Shutdown
joins active jobs before freeing the scene. Teleports pause until the new 3 × 3
collision neighborhood is registered. An unexpectedly missing landing tile
pauses player physics instead of allowing a fall through the world. Page failures
are detected; another starting-point selection retries preparation, and the
World map route remains available.

The limits are **96 resident streamed tiles, four pages per reader, two active
jobs, and a 64 MiB estimated terrain working budget**. Accounting includes native
mesh/collider copies, background geometry, transient jobs, and a conservative
16 MiB allowance for water/coverage resources. This is terrain accounting, not
whole-game RSS or a guarantee about GPU-driver allocations. Clay's existing
model, animation, render targets and other engine resources are separate costs.
The world can grow without retaining a proportionally larger detailed terrain
working set; its fixed distant overview would need its own LOD adjustment.

All four generated maps use this streaming path. The legacy loading path is
retained for definitions without streaming metadata, rather than requiring it
for any current destination.

Skirts seal gaps between detail levels. Height sampling and normals use global
geographic coordinates so adjacent sections agree. A floating origin shifts
horizontal local coordinates in 1024 m increments beyond a 2048 m threshold;
map coordinates and spawn locations retain their geographic positions. Existing
rig history is reset at a shift to avoid dragging contact trails across it.

## Verification

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game \
  --log-file /tmp/wof-terrain-check.log --script res://tests/terrain_smoke.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game \
  --log-file /tmp/wof-atlas-check.log --script res://tests/overworld_smoke.gd
/Applications/Godot.app/Contents/MacOS/Godot --path game \
  --log-file /tmp/wof-terrain-render.log --rendering-method gl_compatibility \
  --script res://tests/render_terrain_review.gd
```

The terrain test exercises all four real scenes: proportions, height loading,
dry starts, complete coverage, raycast ground collision, start-point travel,
bounded nearby detail, floating-origin coordinate preservation, ocean recovery
and atlas destination/tooltips at 800 × 500. The existing overworld check retains
the real atlas → loader → village → atlas regression route.

Graphical review captures desktop/small atlas states and an aerial, low aerial
and actual player-camera view of each terrain. A small functional render check
must also use Forward+ on the primary Mac target; Compatibility review covers
the fallback renderer, not web export or physical controller hardware.

## Streaming verification

`game/tests/streaming_smoke.gd` exercises disk page eviction, shared page borders,
full-speed flight across tiles, sudden reversal, dive/landing, repeated distant
teleports, stale work, bounded payload accounting, missing-page detection and
worker cleanup. It writes `cache/streaming-review/metrics.json`.

On the development Mac, the tested route peaked at 56 resident tiles and about
46.6 MiB of estimated terrain payload, with zero landing waits. Headless native
mesh/collision commits peaked around 0.27 ms after using heightfield collision,
compared with approximately 8.3 ms for the earlier triangle collision approach.
These are local measurements, not device-independent frame-rate guarantees.

Forward+ captures and per-map `*_graphics_metrics.json` are generated with:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path game \
  --log-file /tmp/wof-stream-render.log --rendering-method forward_plus \
  --script res://tests/render_terrain_review.gd -- --streaming-review
```

The graphical initialization capture measured a maximum streaming commit near
0.36 ms. Whole-engine video-memory counters also include player assets and
render targets and must not be presented as terrain-only usage. Desktop captures
cover the expanded atlas, shared World placement, an aerial terrain inspection,
a mountain approach and the actual player camera. The full-continent inspection
camera temporarily disables fog to review geography; gameplay retains fog.

The final four-map smoke test settled each scene to 49 resident tiles after
repeated travel. Peak estimated terrain payload was about 44.2 MiB on either
continent, 31.6 MiB on the Forgotten Isles and 29.8 MiB on NightWing Island.
Forward+ initialization commits peaked between 0.20 and 0.28 ms across the four
maps. One concurrently executed headless/regression run recorded a 3.24 ms commit,
exceeding the 3 ms soft target once; the metric records that overrun rather than
claiming an absolute per-frame deadline. Native operations cannot be preempted.

`game/tests/streaming_failure_smoke.gd` additionally checks failed-page recovery
while stale failed jobs finish, plus collision safety for a simulated steep dive
when its landing tile is unavailable. It verifies physics resumes after recovery.
