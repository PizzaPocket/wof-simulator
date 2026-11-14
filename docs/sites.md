# Rough locations: Sky Kingdom palace and Scorpion Den

Two more destinations on the world map, built as quick blockouts to widen coverage rather than to
reach the fidelity of the MudWing village. Both are authored from short wiki descriptions
(the *Sky Kingdom* and *Scorpion Den* pages on `mirror.wingsoffire.wiki`); neither gives dimensions
or plans, so every size and position is authored. Each design file starts with a `note` listing what
was and was not described.

| Place | Pin | Open in | Scene |
| --- | --- | --- | --- |
| Sky Kingdom palace and arena | Queen Scarlet's Palace label | Arc 1, Arc 2 | `scenes/sky_palace.tscn` |
| Scorpion Den | Scorpion Den label | Arc 1, Arc 2 | `scenes/scorpion_den.tscn` |

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

## Shared pieces

`rock_site.gd` carves chambers and tunnels from a design file with CSG, lights them, labels the
chambers, and holds the player until the carved collision is registered (the shape is solid rock for
a few frames before the caves are subtracted). Jade Mountain and the palace are small subclasses.
The Scorpion Den is a plain box-built scene.

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

Checks that both sites build in both eras, the era changes (gold veins, ruler in the label, Vulture's
compound), floors, headroom and the arena depth, and that the Den's gate road is open. The map test
(`overworld_smoke.gd`) also loads both through the loader.
