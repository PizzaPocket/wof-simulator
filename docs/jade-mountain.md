# Jade Mountain Academy

A first playable slice of Jade Mountain and its academy, reached from the world map. It opens in
**Arc 2** and is dimmed on the timeline in other eras. Its pin sits on the traced Jade Mountain
peak in the Kingdom of Sand / Sky Kingdom border country.

This is an **authored blockout**, not a faithful reconstruction. The books and wiki describe the
academy but give no floor plan, and this pass had no access to wiki text (Fandom blocked fetches
and the search results were thin). The layout therefore follows what is described in outline and
invents the rest. Every chamber in `game/data/jade_mountain_design.json` carries a `source` field
saying which it is.

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
| Central cavern with tunnels branching off | wiki: a central cave with tunnels branching from it |
| Library | *A Guide to the Dragon World*: scrolls in the academy library |
| Study room, battle arena, guardians' cave | wiki snippets naming each (not verified against the books) |
| Entrance hall, feeding cave, eight winglet caves, the passage layout | authored |

Winglet caves are eight identical rooms. Whether and how they map to tribes is not decided.

## Known limits

- No NPCs, dialogue, doors, furniture or tribe-specific cave interiors yet.
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
