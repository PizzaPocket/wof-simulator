# Rough locations

Destinations built as quick blockouts to widen coverage rather than to reach the fidelity of the
MudWing village. All are authored from short descriptions on the Wings of Fire wiki mirror
(`mirror.wingsoffire.wiki`); none of those pages gives dimensions or plans, so every size and
position is authored. Each design file starts with a `note` listing what was and was not described.

| Place | Pin | Open in | Scene | Built on |
| --- | --- | --- | --- | --- |
| Sky Kingdom palace and arena | Queen Scarlet's Palace label | Arc 1, 2 | `sky_palace.tscn` | `rock_site.gd` |
| Scorpion Den | Scorpion Den label | Arc 1, 2 | `scorpion_den.tscn` | `box_site.gd` |
| SandWing stronghold | Burn's Stronghold label | Arc 1, 2 | `burn_stronghold.tscn` | `box_site.gd` |
| IceWing palace | Queen Glacier's Palace label | Arc 1, 2, 3 | `ice_palace.tscn` | `rock_site.gd` |
| Summer Palace | island in the Bay of a Thousand Scales (authored) | Arc 1, 2 | `summer_palace.tscn` | `box_site.gd` |
| NightWing fortress | south slope of the volcano (NightWing Island map) | Arc 1, 2 | `nightwing_volcano.tscn` | `rock_site.gd` |

## Sky Kingdom palace and arena

A flat-topped mountain with a bowl-shaped arena (a stepped pit with ten spires for prisoners on the
floor) and a rear peak whose throne hall, treasury and guard hall are carved into the rock, open to
the sky at the front. Plan: `data/sky_palace_design.json`; code: `scripts/sky_palace.gd` on the
shared base `scripts/rock_site.gd`.

- **Arc 1 (Scarlet).** Gold veins run through the carved stone (a shader parameter on the interior
  material). The wiki describes gold veins and talon-print floors in her reign.
- **Arc 2 (Ruby).** The gold is gone ("removed on Ruby's order"). The label notes the arena is now a
  hospital for veterans, but there is no hospital content yet.
- **Not modelled:** talon-print floors, wires between the spires, collapsed towers and scorch marks,
  the tunnels being blasted, the valleys and lakes around the palace.

## Scorpion Den

A walled desert town: a wall ring with five gates and gate towers, a central oasis with palms, a
market plaza ringed with stalls, and a few hundred sandstone blocks laid out on a jittered grid so the
gaps read as winding alleys, with a clear road from each gate to the plaza. Named buildings carry
signs. Plan: `data/scorpion_den_design.json`; code: `scripts/scorpion_den.gd`.

- **Arc 1.** The Outclaws' camp of tents stands by the oasis.
- **Arc 2.** Vulture's walled compound with an observatory tower stands at the north-east. Qibli's
  home appears. The wiki is unclear when the Outclaws' rule ended, so this split is a simplification.
- **Both.** The orphanage.
- **Not modelled:** interiors, the prison cell and oubliette, mines and traps, fortune-teller tents,
  sand buckets, and any people.

## SandWing stronghold

A squat walled fortress in open desert with corner and gate towers, a hollow keep with a throne dais
and walkable roof, a prison block and a sand-hidden tunnel hatch. **Arc 1 (Burn):** enemy heads on
spikes along the walls and the twisted weirdling tower. **Arc 2 (Thorn):** both removed. The wiki
describes none of the plan, so the shape is a generic defensive fortress. Plan:
`data/burn_stronghold_design.json`.

## IceWing palace

An ice mountain with a flight ledge and carved halls (a landing hall, great hall, a carving gallery,
the moon globe tree chamber, a throne room and a treasury), under three moons on a sheet of ice.
Ice colours come from the `rock` block of the design file. The era changes only the label (Queen
Glacier in Arcs 1 and 2, Queen Snowfall in Arc 3). The wiki best describes the southern palace
(ice walls and floor, cramped halls, mismatched carvings of a polar bear, wolf, scavengers and an
owl); the carvings, the Great Ice Cliff and the Circle Rankings are **not modelled**. Plan:
`data/ice_palace_design.json`.

## Summer Palace

A twelve-story tapering pavilion of blue-tinted stone on a small sand island in a shallow sea.
**Arc 1:** intact, hidden under a canopy of foliage, with the electric eel cell by the entrance.
**Arc 2:** only the lower stories stand, with broken walls and rubble, no canopy. Only the ground
floor is walkable. The underwater Deep Palace and the Island Palace are not modelled. Plan:
`data/summer_palace_design.json`.

## NightWing fortress

A jagged black volcano with a smashed crater and glowing lava, flows of lava down the slopes, dead
trees and sulfur vents on black sand under an ash sky, with the fortress carved into its side:
quarters, a council chamber with a lava lake, dining cave, library, laboratory, dungeon, a throne
room with a lava cauldron and a long dormitory with 24 stone beds (the wiki says at least 50).
**Arc 1:** before the eruption in *The Dark Secret*. **Arc 2:** after it, with rubble in every hall
(kept off the passages) and heavier ash. The wiki does not tie the smashed crater to the eruption,
so the crater appears in both. Plan: `data/nightwing_volcano_design.json`. Its pin is on the
NightWing Island map at the volcano's south slope.

## Shared pieces

`rock_site.gd` carves chambers and tunnels from a design file with CSG, lights them, labels the
chambers, and holds the player until the carved collision is registered (the shape is solid rock for
a few frames before the caves are subtracted). It also builds the cone mountains (`rock`, `lantern`
and `env` blocks in the design file set the stone colours, lamp colour and sky). Jade Mountain, the
palace, the ice palace and the volcano are small subclasses.

`box_site.gd` is the base for box-built outdoor scenes: era lookup, camera range, sky, ground and
boundary, labels and spawn. The Den, the stronghold and the Summer Palace implement `_build()`.

Each site reads the era the player chose on the map (`Engine` meta `map_era`, set whenever the map
opens, default Arc 1) through `current_era()`.

## View distance

The player camera's far plane defaults to 300 m, which makes anything farther away simply not draw.
On Jade Mountain this showed as the whole mountain appearing as you approached. Each site now sets
the camera's far plane from its design file (`view_distance`: 20 km for the mountains, 8 km for the
Den), pushes the ground disc out to the horizon haze, and extends sun shadows to 3.5 km. Any new site
that can be seen from afar needs the same.

## Test

```sh
godot --path game --script res://tests/sites_smoke.gd
```

Checks that every site builds in each of its eras, that the era changes things (gold veins, ruler in
the label, Vulture's compound, the weirdling tower, ruins, rubble), floors, headroom, the arena
depth, open gate roads and passages, and the camera far plane. It takes a few minutes. The map
test (`overworld_smoke.gd`) also loads the palace and the Den through the loader.
