# Marsh village and character motion

The village now sits on raised, curved mud causeways above flooded marsh.
The main causeway varies in width and tapers down at its ends. Curving branches
join dry nest pads; low ground between them remains wet. The terrain and water
share an irregular outer boundary. A deeper, variable-width river connects to
tributaries and shallow pools. Broad reed beds and branching willow-, cypress-
and alder-inspired trees replace the earlier scattered grass and ball crowns.

Shallow flooded grass beds use opaque olive-green stagnant water, with irregular
algae and silt mottling, low ripple strength and subdued sky reflection. Depth
blends this surface into the existing open-water appearance between 0.45 and
1.3 m; deeper river channels and pools retain their original color. Palette and
depth thresholds live in `wetlands_world.json` under `marsh_water`.

The twelve mud nests have brown mineral colors related to the paths and wallow.
Their hollow shells have thick, rounded, elevated side entrances and closed
ground-level walls. Move into a nest wall to grip it; W/S or the vertical stick
climbs up/down, A/D traverses. Continue upward at a reachable entrance sill to
mantle inside. The same controller works on the inside wall to exit. Space / A
jumps away; Ctrl / B releases the grip. Climbing rejects supporting patches steeper
than the configurable overhang limit. It measures a claw-span patch so small mud
ridges do not count as whole-wall overhangs. The sill collision faces point toward
the opening, permitting real ledge contact.

The reach–grip–pull cycle keeps three paws planted while the fourth reaches.
The torso crouches closer to the wall, hangs downward during a reach and pulls
upward after contact, with a separate cervical pose to look above the next grip
and into the opening. Its muzzle is aimed near the world horizon while the
trunk is upright, rather than inheriting the trunk’s skyward heading. Movement is kinematic and collision-tested; it is not a
ragdoll or a simulated muscle system. `game/data/climbing.json` records speed,
grip angle, mantle duration and wing clearance.

The climbing pass uses a 3.1 m/s travel setting, a 2.4 m four-paw stride and
0.9 m forward grip search, replacing the earlier short, slow steps. Each reaching
paw commits to a fixed landing point. Initial grips are established in the settled
wall frame. Mantling first lifts above the sill, then transfers the hips across
while rotating the trunk and capsule upright. The limb pose blends into airborne
or ground motion at release. The airborne hip pivot uses the model's rest rotation
as its reference, preventing the roughly 0.9 m sideways pop at release. The
continuity test measures less than 0.11 m translation and 3 degrees of rotation
per physics frame through the mantle and release. An upward-facing inner rim starts a mantle rather
than ending the climb on the sill. Entrances are about 13% narrower and 15% shorter;
their dimensions now come from `wetlands_world.json` for both mesh and collision.
These sizes follow the user's feedback, not a measured graphic-novel panel.

The previous folded-wing entrance shortcut is removed. Flight keeps wings
spread, requires span clearance, and provides no artificial lift while the wings
are still deploying. Jump momentum continues ballistically during deployment.

Soft mud has a visible surface above a lower collision bed. A character's support
height settles gradually under load, with horizontal resistance. The stepping
solver treats the mud volume as support and places paws relative to its settled
surface instead of disabling the walk until they hit the hard bed. Jumping and
flight release the mud support. Clay sinks more deeply than the children.
The children reject wet route targets and seek the dry causeway if displaced
into marsh. Their normal routes stay on raised ground.

## Character changes

Child gait now uses a continuous planted-foot/swing curve, heel/toe roll, small
weight shifts and softened transitions. Arm IK has separate elbow directions for
walking and brief greetings. Forearm rotation contributes to palm
orientation; fingers curl and draw together into relaxed hands. Routine idle
activities are looking around and watching nearby Clay. Random waves and the
pebble-in-hand idle are removed: a prop should not appear without a pickup action. Heel contact progresses to flat support and
forefoot roll, with a longer stride period and a quieter torso.
`child_walk.json` adds support-linked pelvis rise and lateral transfer, opposing
chest rotation, and a larger arm pendulum with the elbow opening on the backward
swing and bending forward. Hand height follows actual arm-chain reach.
Shirt torso weights follow the spine, while sleeve weights follow the arms.
The suspended central shirt front is faired independently of the body, removing
small inward cloth-solver pinches while retaining broad drape and edge folds.
Garments retain a baked cloth drape and use skinning during gameplay; they do
not simulate cloth dynamically.
Skin fully enclosed by the shirt is omitted after cloth fitting, retaining overlap
inside the collar, hem and cuffs. This prevents the independently skinned armpits
from showing through the cloth without enlarging the sleeves. Camille's wavy hair
uses a muted sandy-blonde palette.

The accepted faces and hair are preserved. Runtime vertex colors add very slight
skin variation and lip tint without changing geometry. Lip tint uses an authored UV-space boundary texture aligned to the actual lip
contour, replacing the broad facial-coordinate mask. Camille and Corinne share
the same warm, light skin palette; Kai is more tan and has dark brown irises.
Umber's eye variant uses a gently upright oval pupil and a partly forward gaze.
Clay's eye material is unchanged.

## Files and visual checks

- `game/data/wetlands_world.json`: nest positions and sizes, grass fields.
- `game/scripts/mudwing_wetlands.gd`: terrain, causeways, water, vegetation and mud sampling.
- `game/scripts/wetland_forms.gd`: nest shells and branching vegetation meshes.
- `game/scripts/player.gd`, `game/scripts/surface_climb.gd`: mud support, climbing, mantle and flight clearance.
- `game/scripts/scavenger_visual.gd`: child gait, gestures and hand posing.
- `game/tools/child_garments.py`: cloth pattern build and garment skinning.
- `game/scripts/child_complexion.gd`, `game/data/child_complexion.json`: subtle complexion colors.

Run the Godot scripts in `game/tests/` with `--path game --script res://tests/NAME.gd`
and a writable `--log-file /tmp/NAME.log`. Functional checks are
`climbing_smoke.gd`, `wetlands_world_smoke.gd`, `soft_mud_smoke.gd`, `child_motion_smoke.gd`,
`scavenger_anatomy_smoke.gd`, `village_npc_smoke.gd` and `movement_smoke.gd`.
The native render scripts `render_marsh_review.gd`, `render_marsh_interaction.gd`
and `render_child_motion.gd` save actual engine images under `cache/`.
`game/tools/make_motion_evidence.py` assembles the child animation GIF and portraits.

The user's book-one description guides the village layout; the scenery is an
interpretation, not a reconstruction verified against the novel. Botanical
inspiration: [US Forest Service baldcypress](https://research.fs.usda.gov/silvics/baldcypress)
and [EPA bottomland hardwood wetlands](https://www.epa.gov/wetlands/bottomland-hardwoods).

The dragon’s posterior jaw/throat union uses a local fillet around the ascending
jaw, rather than relying on a narrow global blend that leaves an opening between
the jaw and face sections. Source settings live under `anatomy.head_weld` in the
body design. `check_throat_attachment.py` samples tissue across the junction; the
full assembly is reviewed from profile and three-quarter views with the jaw shut
and open.

Camille uses the CC-BY `elvs_hazel_hair` by Elvaerwyn, a long softly wavy
style. Corinne retains her separate curl asset with a lighter peach-gold
strawberry-blonde palette. Eyebrows sit closer to the brow ridge and use denser,
tapered, individually projected fibres rather than the earlier row of sparse
short marks.
