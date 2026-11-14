# World atlas and destinations

F5 opens the world atlas on Pyrrhia. Tabs also open Pantala, the Forgotten Isles
and NightWing Island, each with a playable bare-terrain destination. Select
**Explore Pyrrhia** in the desert for the first continent's terrain. See
[bare terrain](bare-terrain.md) for scales, generation and controls.

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

The atlas is drawn entirely from native vector geometry by
`game/scripts/vector_atlas.gd`: extracted coastline polygons, clipped terrain
color fields, mountain symbols, river strokes and a lake. Kingdom labels are
real Godot text. There is no raster map or imported SVG texture in the runtime.
Pyrrhia geometry and hotspot positions use **2165 × 1606** cropped pixel coordinates.
Other tabs use their own source-map dimensions from `game/data/terrain/*.json`;
all fit uniformly without changing aspect ratio. Terrain colors and geographic
rules are shared with the playable heightfields.

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

Add a location to `game/data/overworld_locations.json` with a unique `id`, display
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

`game/tests/overworld_smoke.gd` checks atlas focus and bounds, the real loading
path into the wetlands, the return button, the shared keyboard/controller action
and kingdom labels. In a graphical run it also saves desktop,
small-window, hovered-marker and village captures to `cache/overworld-review/`.
