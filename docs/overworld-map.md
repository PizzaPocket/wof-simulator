# World atlas and destinations

F5 opens one world map showing Pyrrhia, Pantala, the Forgotten Isles and NightWing
Island at a shared metre scale. There are no separate maps or tabs.

- **Move:** drag, two-finger scroll on a trackpad, controller right stick, or Tab
  to a pin (the map pans to it).
- **Zoom:** mouse wheel, pinch, **+** / **−** keys, the on-screen buttons,
  double-click, or controller triggers. **⌂** returns to the whole world.
- **Pins:** every starting point of every landmass, plus the MudWing village.
  Pins thin out at low zoom so labels never collide, and zooming in reveals the
  rest. **Jump to a place** lists all of them, flies there and focuses the pin.
- **Travel:** click a pin, or press Enter / controller A while it is focused.
  Returning from a scene restores the map view you left.

- **Era:** the timeline strip along the bottom (Legends, Arc 1 to Arc 4) sets the era, saved
  for the session and restored when you return from a scene. The land never changes between
  eras; an era decides which destinations are open. Pins with an `eras` list in
  `game/data/overworld_locations.json` are dimmed outside those eras, say when they open, and
  refuse to travel. Pins without a list are open in every era. Eras live in
  `game/data/eras.json`; the arc names follow the books and their dating is not established.

See [bare terrain](bare-terrain.md) for scales, generation and controls. Detailed destinations:
the MudWing village, [Jade Mountain Academy](jade-mountain.md) (Arc 2) and six rough blockouts
(the [Sky Kingdom palace, Scorpion Den, SandWing stronghold, IceWing palace, Summer Palace and
NightWing fortress](sites.md)). Each map visit stores the chosen era
so a destination can show its era's version.

Select **MudWing village** in the Mud Kingdom to
load the existing wetlands through the measured loading screen. Hover over the village marker to reveal its name and entry tip, then click it.
Tab or the D-pad focuses the marker and reveals the same tip; Enter / controller A
activates it. The tip is hidden when the map first opens and when hover/focus leaves. In a playable scene, **M / controller
Start** returns to the map. Alternatively press Esc to release the mouse and
click **World map** beside Help.

Returning unloads the scene. Visiting again rebuilds it at its starting position;
character collection unlocks remain saved by the existing roster system.

## Existing world data

- `docs/world-plan.md`: original 32 × 24 km world and terrain pipeline plan.
- `data/pyrrhia/map_annotations.json`: source-map crop, kingdom/landmark label
  boxes, decorations and reconstructed coastline behind labels.
- `tools/map/fetch_sources.py`: source images, downloaded to ignored `cache/maps/`.
- `tools/map/extract_landmask.py`: regenerates the land mask and review overlay
  in ignored `cache/stage1/`.

The downloaded images and generated mask were absent from this checkout. They
were restored and stage 1 rerun: 41.8% land, 38 connected land pieces. This is
still a coastline extraction, not a complete terrain/world dataset: rivers,
lakes, biome rules and elevation remain future work in the original plan.

## Map assets

The map is drawn entirely from native vector geometry by
`game/scripts/world_map.gd`: extracted coastline polygons, clipped terrain
color fields, a soft shallow-water shelf, mountain symbols, river strokes and
lakes. Labels are real Godot text; continent names fade out and kingdom/region
names fade in as you zoom. There is no raster map or imported SVG texture in the runtime.
Each landmass keeps its own source-map pixel space (Pyrrhia is **2165 × 1606**);
`world_map.gd` places all four in one 1200 × 700 km metre space using the same
offsets as `game/data/terrain/world.json`. The camera is a centre and a zoom
(pixels per metre) clamped between the whole world and 80 m per pixel. Terrain
colors and geographic rules are shared with the playable heightfields.

`game/data/pyrrhia_coast.json` is the versioned coastline geometry produced from
the extracted land mask. Terrain colors, mountain symbols and waterways come from the generated terrain
definitions and remain simplified authored cartography, rather than surveyed
kingdom borders. The SVG remains a source
preview, not the displayed game map. Downloaded book artwork remains ignored,
available only for reference, and excluded from game exports.

To regenerate (install dependencies in a venv or local target first):

```sh
pip install -r tools/map/requirements.txt
python3 tools/map/fetch_sources.py
python3 tools/map/extract_landmask.py
python3 tools/map/prepare_overworld.py
```

`fetch_sources.py` falls back to the wiki's legacy image endpoint if the revision
CDN returns 403. Pillow reads either PNG or WebP responses.

## Adding a scene

Starting points on an existing landmass need no code: add an `entries` item
(`name`, `position` in that landmass's source-map pixels) in
`data/terrain/world_regions.json`, run `tools/map/build_terrain.py`, and a pin
appears (the bake fails if the point is not on dry ground). The entry lists in
`overworld_locations.json` are templates (scene and preload assets) that every
terrain pin of that landmass reuses.

For a new detailed destination, add a location to `game/data/overworld_locations.json` with a unique `id`, display
`name`, `kingdom`, cropped-map pixel `position`, destination `scene` path and an
`assets` array of `[resource_path, loading_description]` pairs. The loader adds
the destination scene as its final job. Use the annotation boxes and the source
map to place it geographically; do not mix full-image and cropped coordinates.
The MudWing village is an authored position in the kingdom, not a canonical
settlement identified in the book.

A destination may implement async `initialize_world(progress_callback)`, reporting
fractions 0–1. Its `_ready` should skip initialization when `startup_loader` metadata
is set (see `mudwing_wetlands.gd`). Ordinary scenes can initialize in `_ready`.
Scenes deriving from `playground.gd` inherit the map button and shortcut; other
scene bases should expose equivalent return navigation.

## Verification

`game/tests/overworld_smoke.gd` checks that every start is pinned, the era timeline and gating, wheel/drag/pinch
camera behaviour and zoom limits, that every pin is reachable and unclipped at the
closest zoom, hover/focus details, the Jump menu, the real loading path into an
island and the wetlands (landing on the chosen start), view restore, the return
button and the shared keyboard/controller action. In a graphical run it also saves
captures to `cache/overworld-review/`. Run it with `-- --atlas-only` to skip the
slow scene loads.
