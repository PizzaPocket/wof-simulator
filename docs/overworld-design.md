---
name: Wings of Fire overworld
description: Design record of the implemented native Godot atlas, bare terrain and destination flow.
colors:
  marsh: "#172c28"
  gold: "#edce91"
  parchment: "#e8e4cf"
  warm-highlight: "#f3e5c4"
  atlas-water: "#254a51"
  terrain-water: "#347f92"
typography:
  title:
    fontFamily: "Godot default theme font"
    fontSize: "32px"
  body:
    fontFamily: "Godot default theme font"
    fontSize: "16px"
rounded:
  tooltip: "4px"
---

## Overview

The overworld preserves the existing marsh green, gold and parchment identity. The atlas and playable landscape lead; native Godot controls provide the surrounding navigation. This is the established design record for these surfaces, not a replacement project identity.

The atlas has five tabs: **Pyrrhia**, **Pantala**, **Forgotten Isles**, **NightWing Island** and **World**. Each landmass has a playable bare terrain destination. Pyrrhia also retains the separate detailed MudWing village destination. World presents all four terrain destinations together.

The terrain extension is deliberately a foundation: colored ground, mountains, hills, shores and water with collision. New vegetation, buildings, settlement scenery and NPCs are outside this pass. The existing village remains available. Geographic and implementation details, provisional sizes and verification commands are in [Bare playable world terrain](bare-terrain.md).

## Colors

### Primary

Gold identifies the atlas heading, destination pins, tooltip outline and loading progress. Warm highlight marks hover/focus rings and labels that need light ink over darker map fields.

### Neutral

Marsh fills the atlas canvas, pin backing and tooltip. Parchment carries ordinary copy. Dark ink or light ink is chosen for map labels against the local terrain color; Pantala and island region labels use the region color's luminance to choose black or white where configured.

### Geographic fields

Muted biome fields distinguish land regions; blue-green water separates coastlines. Atlas water is a flat cartographic field, while terrain water is a native 3D surface. Procedural biome colors belong to geographic definitions rather than a new interface accent system.

**The Inherited Palette Rule.** Extend the existing atlas and HUD identity without introducing a new decorative palette for terrain navigation.

## Typography

The atlas uses Godot's default theme font. Its title uses the title token; subtitle, region labels, tooltip and footer use the body token. Native tab buttons, terrain starting-point selector and existing Help/map controls retain their theme typography. Startup retains its existing title (25 px), status (16 px) and supporting copy (14 px).

No custom typeface, new display style or project-wide type scale is established by this extension. The native font is an incumbent implementation choice, not a newly selected brand face.

## Layout

The atlas heading begins at (28, 16), subtitle at (29, 59), and navigation row at (28, 90). Tabs use native toggle buttons with a minimum height (36 px) and row separation (8 px).

The map begins at y=140 and fits proportionally within the available window area (width minus 56 px, height minus 200 px). It is centered horizontally and preserves the complete selected map's aspect ratio. Each landmass uses its own source coordinate space; Pyrrhia retains the cropped source proportions (2165 × 1606). World uses a common metre scale and authored offsets before the same aspect-fit layout.

Desktop (1280 × 800) and small-window (800 × 500) are review sizes, not responsive breakpoints. Resize recomputes map geometry, labels and marker positions from the same transform. Text and hit targets retain their sizes as the map scales. The current navigation row remains horizontal at both review sizes.

Destination targets have a minimum size (48 × 48 px) centered on the geographic point. The tooltip appears beside its marker, switches sides near the right edge and is clamped to a screen inset (16 px). It renders above map labels through an explicit canvas layer order (`z_index = 10`).

Terrain retains the existing Help and World map controls. Its native starting-point selector sits in a horizontal row at (24, 66), with a minimum size (210 × 36 px). The location label begins at (24, 110). Expanding Help hides this row and label to keep the overlays readable.

## Elevation & Depth

The atlas uses flat color fields and thin outlines without interface shadows. A dark pin backing separates gold markers from land and waterways; the tooltip's explicit draw order keeps its text clear of map labels. Terrain depth comes from actual 3D ground relief, water, lighting and atmospheric distance. The terrain location label has a small marsh text shadow for legibility over the landscape; this is not a general panel-shadow system.

## Shapes

The tooltip has gently rounded corners, a thin gold border (1 px) and padding (16 px horizontal, 12 px vertical). Marker buttons have no visible text or style boxes. A circular pin combines a dark backing (12 px radius), gold ring (10 px radius) and gold center (4 px radius). Hover or keyboard/controller focus adds a warm outer ring (19 px radius). A thin border marks the map extent.

Cartographic coastlines and native polygon fields retain the geographic silhouettes. Mountain triangles and river strokes are map symbols; the playable scenes express their corresponding terrain through heightfields. Native Godot buttons and selector shapes remain inherited rather than restyled.

## Components

### Atlas navigation and map

Tabs select a map and replace its labels and destination targets. Pyrrhia has **MudWing village** plus **Explore Pyrrhia**, whose terrain entry is in the desert. Pantala, Forgotten Isles and NightWing Island each have one exploration marker. World has four transformed terrain markers; it does not add a second village marker.

The atlas draws native Godot polygons and strokes through `vector_atlas.gd`. Generated definitions in `game/data/terrain/` provide shared coastline and terrain rules for the atlas and playable ground. The editable source is `data/terrain/world_regions.json`; Pyrrhia's extracted coastline remains in `game/data/pyrrhia_coast.json`. Illustrated reference artwork stays in ignored cache files and is not a runtime texture.

### Destinations and tooltip

Destination names, scenes and preload assets come from `game/data/overworld_locations.json`; generated World data transforms the terrain destinations into its shared coordinate space. The village position (1480, 1080) is authored, not a canonical settlement.

The initial atlas has no focused destination or visible tooltip. Hover or keyboard/controller focus reveals the name, location context and “Click / Enter / A to explore”. Tab or D-pad selects; click, Enter or controller A enters. An initial up/down/accept action can establish marker focus. A missing scene produces a footer error. Hover and focus share the same visible marker treatment.

### Playable terrain and travel

Each landmass loads a separate native 3D scene with simple biome colors, mountains, foothills, hills, coast and water. Runtime ground uses original native mesh geometry, generated height samples and procedural color PNGs. The surface remains intentionally undecorated.

The starting-point selector travels within the current scene and prepares nearby collision before movement resumes. Pyrrhia offers seven starting points, Pantala six, and each island four. The Pyrrhia village entrance button becomes available within 600 m of the village near the Mud Kingdom start. Deep-water recovery returns the player to the selected starting point; swimming is not implemented by this pass.

### Loading and return

Destinations use the existing measured loader, preserving its startup composition and destination-specific progress copy. Recovery exposes Retry loading and Back to world map. The shared **M / controller Start** action and clickable **World map** button return from a playable scene to the atlas and release the mouse. Returning unloads the scene; entering again rebuilds it.

## Do's and Don'ts

- **Do** keep the atlas or terrain dominant and surrounding controls minimal.
- **Do** preserve whole-map aspect fit, native controls and visible keyboard/controller focus.
- **Do** keep atlas silhouettes and terrain geography derived from the shared data pipeline.
- **Do** preserve the atlas → loader → terrain/village → atlas roundtrip.
- **Do** keep provisional physical scale and illustrative world spacing explicit; separate book maps do not establish measured intercontinental distances.
- **Don't** add scenery, buildings or NPCs to this bare terrain pass.
- **Don't** imply the World overview is a seamless playable ocean or canonical distance chart.
- **Don't** replace the inherited color and typography system as part of this extension.

Implementation sources: `game/scripts/overworld.gd`, `game/scripts/vector_atlas.gd`, `game/scripts/continent_terrain.gd`, `game/scripts/startup.gd`, `game/scripts/playground.gd`, `data/terrain/world_regions.json` and the generated `game/data/terrain/` definitions. Final primary-renderer review captures are under `.impeccable/review/terrain/forward/`; detailed operational and verification notes remain in [bare-terrain.md](bare-terrain.md) and [overworld-map.md](overworld-map.md).

## Expanded world streaming

Pyrrhia now spans 320 × 237.38 km, preserving source proportions while increasing
travel distances tenfold. Mountain heights remain around 2.5 km, with broader
approaches. The atlas draws from the same updated geographic definition; World
reflects the expanded Pyrrhia and illustrative offsets. Pantala and the islands now also use tenfold expanded physical sizes and
the same bounded streaming system. Their relative proportions remain gameplay
approximations. The visual identity and control layout are unchanged.

Near and medium terrain tiles load from independent disk pages through background
CPU jobs, and unload outside the player's interest region. A coarse landscape
remains visible at distance. Terrain memory and commit measurements, source-detail
limits, safety behavior and current four-map coverage are recorded in
[bare-terrain.md](bare-terrain.md#terrain-disk-streaming).
