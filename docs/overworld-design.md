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

The world map is one continuous chart of **Pyrrhia**, **Pantala**, the **Forgotten Isles** and **NightWing Island**, placed together at one metre scale. The player drags and zooms it like an online map; there are no tabs or separate maps. Every starting point is a pin, and Pyrrhia also keeps the separate detailed MudWing village pin. The terrain scenes remain separate playable destinations, so the shared map is illustrative spacing, not a seamless ocean.

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

The map uses Godot's default theme font. Its title uses the title token (28 px); hint, region labels, pin names, tooltip and controls use the body token (14-16 px). Native buttons, the Jump to a place menu, terrain starting-point selector and existing Help/map controls retain their theme typography. Startup retains its existing title (25 px), status (16 px) and supporting copy (14 px).

No custom typeface, new display style or project-wide type scale is established by this extension. The native font is an incumbent implementation choice, not a newly selected brand face.

## Layout

The map fills the window. A translucent marsh card at (20, 16) holds the title, a one-line hint and the **Jump to a place** menu; zoom in, zoom out and show-whole-world buttons (44 px) sit at the bottom right. The view opens on the whole world and is clamped between that and 80 m per pixel; resizing keeps the same camera and recomputes labels and pins from it.

Pins keep a 26 px minimum separation and yield to higher-priority neighbours (the village, then the first start of each landmass), so zooming in reveals more pins. Names appear beside a pin only when they would not overlap another name or marker, and flip left near the right edge. Continent names fade out and kingdom/region names fade in as a landmass grows past about 700 px on screen.

Desktop (1280 × 800) and small-window (800 × 500) are review sizes, not responsive breakpoints. Text, pins and hit targets keep their pixel sizes as the map scales.

Pin targets have a minimum size (40 × 40 px) centered on the geographic point. The tooltip appears beside its pin, switches sides near the right edge and is clamped to a screen inset (16 px). It renders above map labels through an explicit canvas layer order (`z_index = 10`).

Terrain retains the existing Help and World map controls. Its native starting-point selector sits in a horizontal row at (24, 66), with a minimum size (210 × 36 px). The location label begins at (24, 110). Expanding Help hides this row and label to keep the overlays readable.

## Elevation & Depth

The atlas uses flat color fields and thin outlines without interface shadows. A dark pin backing separates gold markers from land and waterways; the tooltip's explicit draw order keeps its text clear of map labels. Terrain depth comes from actual 3D ground relief, water, lighting and atmospheric distance. The terrain location label has a small marsh text shadow for legibility over the landscape; this is not a general panel-shadow system.

## Shapes

The tooltip has gently rounded corners, a thin gold border (1 px) and padding (16 px horizontal, 12 px vertical). Marker buttons have no visible text or style boxes. A circular pin combines a dark backing (12 px radius), gold ring (10 px radius) and gold center (4 px radius). Hover or keyboard/controller focus adds a warm outer ring (19 px radius). A thin border marks the map extent.

Cartographic coastlines and native polygon fields retain the geographic silhouettes. Mountain triangles and river strokes are map symbols; the playable scenes express their corresponding terrain through heightfields. Native Godot buttons and selector shapes remain inherited rather than restyled.

## Components

### Atlas navigation and map

The map shows a pin for every `entries` item in each terrain definition (Pyrrhia ten, Pantala seven, Forgotten Isles seven, NightWing Island six) plus the detailed **MudWing village**, drawn as a solid gold pin. Tab and Jump to a place reach pins that zooming has not revealed yet.

The map draws native Godot polygons and strokes through `world_map.gd`: coastlines, a soft shallow-water shelf, clipped region fields, rivers, lakes and mountain symbols that fade in with zoom. Generated definitions in `game/data/terrain/` provide shared coastline and terrain rules for the map and playable ground. The editable source is `data/terrain/world_regions.json`; Pyrrhia's extracted coastline remains in `game/data/pyrrhia_coast.json`. Illustrated reference artwork stays in ignored cache files and is not a runtime texture.

### Era timeline

A native bottom-center card holds an **Era** caption and one toggle button per era (Legends, Arc 1 to Arc 4; 72 × 34 px, hover text gives the arc's title). Selecting an era keeps the map in place and dims pins that are closed in it (40% gold). A closed pin's tooltip reads "Opens in Arc N (see the timeline)", and activating it leaves the player on the map with a footer message. The Jump to a place menu appends the era to closed entries. The chosen era is held for the session and restored on return.

### Destinations and tooltip

Terrain pin names and positions come from each landmass's `entries`; scenes and preload assets come from the template locations in `game/data/overworld_locations.json`, which also holds the detailed village. The village position (1480, 1080) is authored, not a canonical settlement.

The initial map has no focused destination or visible tooltip. Hover or keyboard/controller focus reveals the name, location context and “Click / Enter / A to travel”. Tab or D-pad selects (the map pans to keep the pin in view); click, Enter or controller A travels. A missing scene produces a footer error. Hover and focus share the same visible pin treatment. Returning from a scene restores the view the player left.

### Playable terrain and travel

Each landmass loads a separate native 3D scene with simple biome colors, mountains, foothills, hills, coast and water. Runtime ground uses original native mesh geometry, generated height samples and procedural color PNGs. The surface remains intentionally undecorated.

The starting-point selector travels within the current scene and prepares nearby collision before movement resumes. Pyrrhia offers ten starting points, Pantala seven, the Forgotten Isles seven and NightWing Island six. The Pyrrhia village entrance button becomes available within 600 m of the village near the Mud Kingdom start. Deep-water recovery returns the player to the selected starting point; swimming is not implemented by this pass.

### Loading and return

Destinations use the existing measured loader, preserving its startup composition and destination-specific progress copy. Recovery exposes Retry loading and Back to world map. The shared **M / controller Start** action and clickable **World map** button return from a playable scene to the atlas and release the mouse. Returning unloads the scene; entering again rebuilds it.

## Do's and Don'ts

- **Do** keep the atlas or terrain dominant and surrounding controls minimal.
- **Do** keep one continuous, draggable and zoomable map with native controls and visible keyboard/controller focus.
- **Do** keep atlas silhouettes and terrain geography derived from the shared data pipeline.
- **Do** preserve the atlas → loader → terrain/village → atlas roundtrip.
- **Do** keep provisional physical scale and illustrative world spacing explicit; separate book maps do not establish measured intercontinental distances.
- **Don't** add scenery, buildings or NPCs to this bare terrain pass.
- **Don't** imply the World overview is a seamless playable ocean or canonical distance chart.
- **Don't** replace the inherited color and typography system as part of this extension.

Implementation sources: `game/scripts/overworld.gd`, `game/scripts/world_map.gd`, `game/scripts/continent_terrain.gd`, `game/scripts/startup.gd`, `game/scripts/playground.gd`, `data/terrain/world_regions.json` and the generated `game/data/terrain/` definitions. Final primary-renderer review captures are under `.impeccable/review/terrain/forward/`; detailed operational and verification notes remain in [bare-terrain.md](bare-terrain.md) and [overworld-map.md](overworld-map.md).

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
