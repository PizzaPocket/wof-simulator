# Jade Mountain Academy

A first playable slice of Jade Mountain and its academy, reached from the world map. It opens in
**Arc 2** and is dimmed on the timeline in other eras. Its pin sits on the traced Jade Mountain
peak in the Kingdom of Sand / Sky Kingdom border country.

This is an **authored blockout**, not a faithful reconstruction. The wiki describes the academy's
rooms and mood but gives no floor plan or dimensions, so the layout follows the named places and
invents the plan and sizes. Sources are the Wings of Fire wiki mirror
(`mirror.wingsoffire.wiki`, an older revision of the *Jade Mountain Academy*, *Jade Mountain* and
*Starflight* pages); Fandom itself blocks automated fetches. Every chamber in
`game/data/jade_mountain_design.json` carries a `source` field saying which it is.

## What is in the scene

- **The mountain.** One rock mass built from a tall cone, five satellite cones from the design file
  and seeded foothills and summit spires (`jade_mountain.gd`). A snow line and strata come from
  `shaders/jade_rock.gdshader`, a procedural world-space shader with no textures.
- **The ledge and cave mouth.** A buttress of rock holds an arrival ledge at 500 m, facing +Z. The
  player spawns there looking into the mountain. Foothills below are solid, so a fall lands on the
  slope.
- **Caves.** 15 chambers (flat floors, domed roofs) joined by 17 arched passages, all carved from the
  rock with CSG subtraction, with collision. Lanterns light them and a floating label names each
  chamber. Ambient light is low so the sun does not leak into the caves.
- **Scale.** Passages are 14 to 26 m wide, chambers 28 to 124 m across, sized for Clay's 15 m
  wingspan to walk and the larger rooms to fly in. Flying at cruise speed inside is cramped.

| Chamber | Source |
| --- | --- |
| Great Hall | wiki: the unofficial entrance, sunlit, bronze gong, school map, four tunnel openings (about 400 dragons). Here a plain round hall |
| Central cavern with tunnels branching off | wiki snippet: a central cave with tunnels branching from it |
| Library | wiki: scroll-filled, a circular LIBRARIAN desk, skylights, leaf-covered windows. Starflight stands here |
| Study room, battle arena, guardians' cave | wiki snippets naming each (not verified against the books) |
| Prey center | wiki: Clay's prey center, open to the sky on one side with a river. Here an ordinary cave |
| Eight sleeping caves | wiki: sleeping caves off the halls left of the Great Hall. Count and positions authored |

**Named in the wiki but not built:** art cave, music cave, healing center, mourning cave, history
cave, museum, Sunny's office, Stonemover's cave (a second entrance), weapons cave, and the
underground lakes (the largest has a hole to the sky). The wiki also describes the main entrance as
a mountaintop ledge with trees, glass globes hung in the tunnels, plants and small streams, and
the mountain itself as having twin fang-shaped peaks and as the tallest in the Claws of the Clouds.
None of that is modelled yet.

Starflight is the head librarian in this era, and Tsunami, Sunny and Moon stand in stand-in rooms (see [character models](character-models.md#playing-the-cast)); walk up to any of them and press X to play them.

## Known limits

- A few story characters stand in rooms, but there is no dialogue, doors, furniture or tribe-specific cave interiors yet.
- The mountain exterior is simple (cones and spires) and the foothills are a flat disc. Nothing
  beyond the ledge is detailed, and there is no weather or cloud layer.
- CSG is fine at this size (about 2 s to build) but is not a long-term answer for web builds.
- Replace entries in the design file as sourced detail arrives, then adjust the test expectations.

## Loading and collision

CSG collision appears some frames after the mesh, and for a moment the shape is solid rock before
the caves are subtracted. The scene therefore holds the player (`set_physics_process(false)`) until
the ledge **and** the floor inside the entrance tunnel both register in the physics world
(`collision_ready`). The loader and direct runs both rely on this.

## Test

```sh
godot --path game --script res://tests/jade_mountain_smoke.gd
```

Checks the ledge, every chamber floor and headroom, and every passage's floor and 5 m clearance,
then saves captures to `cache/jade-review/`. The map test also loads the academy through the real
loader (`overworld_smoke.gd`).
