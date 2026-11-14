# MudWing homeland: first playable region

Status: lightweight first blockout implemented in `game/scenes/mudwing_wetlands.tscn`.
The remaining passes below are proposals. The first pass uses generated terrain,
opaque shallow water, sparse batched trees/reeds and three low trunk obstacles.
Spawn contact, channel-bed collision and boundary recovery passed a runtime check;
an aerial capture was reviewed. Vegetation remains decorative, and habitation,
audio, detailed art and world loading are deferred.

Community blockout added: three hollow shared mud sleep houses with top openings
and ground entrances, a visible dry path, and two broad shallow mud wallows. House
walls have static collision, interiors remain open, and the original arena remains
available. Runtime checks cover all three doorways/interiors/back walls, both wallow
beds, spawn and boundary recovery. Ground and aerial views were rendered and reviewed.
The additions use primitive geometry and solid materials; no external runtime
assets or NPC systems were added.

Wallow correction: beds now descend to -1.7 m beneath a 0.3 m mud surface, with
sloping banks for walking out. The surface has no collision, allowing Clay's lower
body to submerge while his paws stay supported on the bed. This remains a visual
immersion effect rather than swimming or deformable mud. The blue fill light now
affects scene lighting only, removing its unintended second glow in the sky.

Path correction: replaced the flat ribbon and coarse vertex-color stripe with
Eleblorb's Ohio-style ground paint. One terrain-only decal combines the main route,
house-door approaches, small entrance patches and paths to the wallow banks. Paint
fades near the mud line and does not affect houses, river water, mud surfaces or
Clay. The generated texture is 110 × 374 pixels at 2 pixels/m; generation happens
once when the region loads. Ground/aerial captures and terrain-layer/spawn checks
passed. Eleblorb's source project was only read.

Official reference filenames were resolved through the wiki API:
`Mudwings-homes.png`, `DSD_GN.png`, and
`Mudwing_kingdom_(a_guide_to_the_dragon_world,_wings_of_fire).png`.
Image downloads returned HTTP 403, so their pixels have **not** been inspected.
House silhouettes are provisional interpretations of the verified textual
description, and the Diamond Spray label in the HUD describes the proposed
regional setting. No precise canon village coordinate or continent offset is set.

## Source-led correction: community first

This section supersedes the generic home-clearing concept below. The first
blockout did not establish a MudWing community and should be treated as a terrain
exercise. The next small pass should center on a delta village inspired by the
documented settlement, with its exact site and layout explicitly provisional.

- **Housing and social unit:** sibling troops share large mud bunkhouses with
  an opening at the top. Build a few shared sleep houses rather than individual
  cottages. The wiki identifies an illustration of these by Mike Holmes in
  *The Dragonet Prophecy* graphic novel. [MudWings](https://wingsoffire.fandom.com/wiki/MudWings)
- **Village layout:** the wiki describes a dry path with sleep houses and large
  mud puddles beside it. Reorganize the spawn area around this arrangement; add
  broad accessible mud wallows, distinct from river channels. The kingdom gallery
  lists graphic-novel art and Mike Schley's regional map from *A Guide to the
  Dragon World*. These are reference targets, not images inspected in this pass.
  [Mud Kingdom](https://wingsoffire.fandom.com/wiki/Mud_Kingdom)
- **Location:** the Diamond Spray Delta is associated with Clay's siblings and
  the village he visits. Use it as the proposed regional anchor, without naming
  a newly invented building as their exact house.
  [Diamond Spray Delta](https://wingsoffire.fandom.com/wiki/Diamond_Spray_Delta)

### Map evidence and precision

`data/pyrrhia/map_annotations.json` already records the Diamond Spray Delta label
as `[1200, 795, 1470, 890]` and a hand-interpreted hidden coastline. These are
pixels in the border-cropped `PyrrhiaColored.png`, not world coordinates or a
village footprint. The Mud Kingdom label is `[1345, 920, 1690, 1040]`.

Before assigning a world offset, inspect both source maps, establish the actual
delta land/water features, choose a plausible settlement site, and record the
pixel-to-world transform. Label centers must not become settlement coordinates.
No exact village coordinate has been verified. The source maps are not currently
present in `cache/maps/` in this workspace.

### Keep the correction inexpensive

Replace the decorative home-tree focus with a short dry village path, roughly
three simple hollow mud sleep-house shells and two shallow wallows. Those counts
are game-design choices. Reuse earth materials and static collision; keep existing
movement and defer NPCs and deformable mud. Inspect the listed official art before
settling house silhouettes, openings and proportions.

Research note: the wiki's indexed text was available, but direct page fetches
failed. Descriptions and gallery attributions above were checked in those text
results; the actual reference images still need visual inspection.

The user confirmed Pyrrhia, following the existing [world plan](world-plan.md).
The current playground should become the starting point for one locality within
the MudWing homeland. It is the first piece of the larger world, rather than a
miniature version of the entire kingdom.

## Experience

Clay starts on a broad, dry bank overlooking warm wetlands. There is room to
walk, gallop, open his wings and take off immediately. Beyond the bank, shallow
channels wind between reed beds, low islands and scattered trees. A conspicuous
old tree marks the way home from the air. A small inhabited area gives the
landscape a sense of belonging to dragons.

This is proposed game geography and environmental design, not a claim about a
specific location in the books. Exact placement, settlement details and named
canon landmarks can be checked when connecting it to the traced continent map.

## Size and layout

Start with a **500 × 500 m playable blockout**, matching the current floor's
footprint. Add distant scenery to suggest wetlands continuing beyond it. Keep
its eventual world-map position configurable; do not scale the character or
movement to fit the continent.

The current flight speeds are 24 m/s cruising and 34 m/s boosted. Crossing 500 m
takes about 21 or 15 seconds at steady speed, so this is a local playground,
not a substantial cross-country journey. Expand toward roughly 1 km square only
after the first layout feels useful and has an acceptable frame-time cost.

| Area | Proposed form | Purpose |
| --- | --- | --- |
| Home bank | Dry clearing, broad approaches, old landmark tree | Spawn, reset, inspect Clay, take off and land |
| Mud flats | Open ground with gentle undulations and sparse reeds | Gallop, turn, judge speed and see feet clearly |
| Shallow channels | Firm visible bottoms, islands and sloping banks | Cross water, jump gaps and practice landings |
| Raised ground | Low ridges, exposed roots, broad fallen trunks | Try slopes, steps and camera clearance |
| Home gathering place | A few dragon-sized resting spaces and worn paths | Establish habitation without a large NPC system |
| Flight circuit | Open channel route around tree and ridge landmarks | Climb, glide, bank and return home |

Arrange a short walking loop around the home bank, a longer ground loop through
the flats and channels, and an aerial loop linking the major landmarks. Start
with an approximately 80–120 m dry inspection area; validate its size against
Clay's actual wingspan and turning radius before dressing it.

Keep tree cover clustered. Open stretches should let the camera pull back and
show the whole dragon; dense vegetation can frame the edges and side paths.
Use elevation, shorelines and tree silhouettes to make destinations readable
from both ground and air. Avoid making every route look like the same marsh.

## First playable scope

1. Sculpt the banks, islands and raised ground with simple terrain geometry.
2. Add shallow water with explicit wading/contact behavior and reliable ground
   collision. Set depth relative to Clay's actual feet and body clearance.
3. Add a small original material palette: dry earth, wet mud, grass/reeds, bark
   and water. Mud initially changes appearance; avoid a locomotion penalty until
   walking and galloping feel good on the new ground.
4. Dress the region with a few reusable tree, reed, rock and fallen-trunk assets.
5. Add restrained water, wind and wildlife ambience, plus subtle atmosphere that
   preserves visibility of the flight route.
6. Give the inhabited area a few environmental details: resting hollows, worn
   routes and shared open space. NPCs can follow once this feels like a place.

Swimming, diving, deep-water traversal, mud deformation, dynamic weather,
destructible scenery, quests and a full palace are later additions. Fire remains
the current visual effect until environmental reactions are designed separately.

## Scene structure and world connection

Preserve the existing obstacle arena as a selectable development scene, because
movement tests depend on its predictable ground and obstacles. Build the wetland
as a new region scene using the same player, controls and creature motion.

Proposed ownership:

- A world root owns the player, active camera, shared lighting, HUD and loading.
- A MudWing region scene owns terrain, water, vegetation, local sounds,
  landmarks and spawn markers. It does not create a second player or global sky.
- Region data records a stable ID, bounds, world placement and connections to
  neighboring regions. Start with `mudwing_wetlands_01`; its continent offset
  remains provisional until map placement is established.
- Keep collision separate from decorative meshes, and use shared resources for
  repeated vegetation. Measure the benefit before adding more complex loading.

Use one local region first. The existing world plan's 1 km content cells are a
future loading unit, not a requirement that every authored region be 1 km wide.
Reserve a clear outward river corridor and an overland continuation for future
neighbors. The standalone prototype needs an explicit recoverable boundary and
out-of-bounds reset; distant scenery and fog alone cannot contain a flying player.

Before integrating this region at its full continent coordinates, complete the
world plan's precision experiment and settle how coordinates shift or use double
precision. Continent-scale terrain generation and streaming remain separate
milestones; the wetland blockout can proceed around a local origin now.

## Build order and review gates

| Pass | Deliverable | Ready when |
| --- | --- | --- |
| 1. Terrain blockout | Dry bank, flats, channels, ridge, landmark placeholders and loops | Walking, galloping, flight and reset work; routes read from ground and air |
| 2. Water and contact | Shallow water, bank collision, safe crossings and boundary recovery | No falling through banks, water/ground flicker or unexpected underwater camera; inspect paw contact and record rig limits |
| 3. Habitat | Materials, vegetation, inhabited clearing and ambience | Feels like a warm wetland home; Clay stays readable and the camera works among props |
| 4. World readiness | Region metadata, neighbor connection markers and reusable world root | Region loads independently and can sit beside a simple test neighbor without duplicate player/environment ownership or a collision seam |

Review each pass in the running game with ground-level, aerial and landing views.
Re-run the existing movement/animation checks in the preserved arena when shared
code changes. In the wetland, manually check slopes, narrow banks, shallow-water
crossings, camera obstruction, landing approaches and out-of-bounds recovery.
Record frame times on the target machine with Clay visible, especially looking
across water through reeds; choose vegetation density from those measurements.

The current rig has no per-digit terrain contact or full-body collision. The
first blockout should use forgiving slopes and wide passages; record visible
foot-placement limitations rather than treating scenery as proof of a rig fix.

## Choices still open

- Art direction: suggested starting point is softly stylized, with natural
  colors and clear silhouettes that suit Clay's existing materials.
- Habitation: suggested starting point is a small communal home clearing;
  decide later whether it is Clay's specific home or another MudWing locality.
- Target machine/frame-rate budget: set before committing to vegetation density,
  water effects or expansion beyond the first 500 m blockout.

Recommended next action: build pass 1 and review its routes and scale in-game
before committing to detailed environment art.
