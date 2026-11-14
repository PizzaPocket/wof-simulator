# WOF Simulator

For a universal Mac app, run `python3 tools/build_macos.py` from the repository
root. See [macOS build and signing](../docs/macos-build.md) for Developer ID,
notarization, and the one-command shareable release. F5 opens the world map;
villages use the logo splash and measured loader. F6 runs a scene directly.

Open `game/project.godot` in **Godot 4.5 or newer** and press **F5**. Tested locally
with Godot 4.7.1. No plugins are needed. F5 opens the world atlas. Its tabs offer bare playable
terrain for Pyrrhia, Pantala, the Forgotten Isles and NightWing Island, with simple
biome colors, mountains, hills and water. Pyrrhia is now 320 × 237 km, with nearby
terrain loaded from disk and distant land kept at coarse detail. Pantala is
320 × 250 km, the Forgotten Isles map 120 × 125 km, and NightWing Island
100 × 64 km; all four stream terrain on demand. Choose an exploration marker, then use
the starting-point selector to visit different regions. See
[bare terrain](../docs/bare-terrain.md) for scales, generation and limitations.
Select **MudWing village** to enter the first wetland
village: an irregular region with a deep winding river, tributaries, pools,
broad reed beds, branching wetland trees and twelve clustered mud nests.
Raised causeways vary in width, curve toward the nests and taper at their ends.
Move into a hut wall to grip it, climb with the movement controls and continue
forward over the sill to enter. Jump pushes away from the wall; Ctrl / B lets go.
Climbing also works on the inner wall to exit. Flight requires room to deploy
the wings; deployment carries ballistic momentum until the wings open. Soft mud gradually lets bodies sink and resists
movement. Children prefer the dry causeway and return to it if displaced into
marsh. Swimming and deformable terrain are not implemented. An invisible collision
wall follows the irregular region edge, with tall side walls and an open sky. Flying into a side
stops movement at the boundary rather than teleporting home.
See [marsh and motion notes](../docs/marsh-and-motion.md).
The environment uses generated geometry and batched vegetation, with no new
downloaded assets or plugins. The existing Clay model still loads normally.
Village paths adapt Eleblorb's Ohio ground-paint system: one small generated
texture projected onto the terrain, with soft irregular edges, mottled earth and
branches to house entrances and wallow banks. They add no collision geometry.
The river uses an opaque, texture-free shader with continuously animated ripples,
sun highlights and a grazing-angle sky tint. It adds no reflection/refraction pass
or water simulation; mud wallows retain their separate still surface.

Press **M / controller Start** or click **World map** beside Help to return to
the atlas. Revisiting a scene starts it fresh; collected characters stay unlocked.
See [overworld map and adding scenes](../docs/overworld-map.md).

The original movement arena remains at `scenes/playground.tscn` (open it and
press F6). Existing movement checks continue to use that arena. See the
[region plan](../docs/mudwing-playground-plan.md) for the intended expansion.

## Village friends

Clay starts in your collection. Walk up to Umber, Moon, Blue or Wren and press **X** (Xbox **X** /
PlayStation **Square**) to take control of him and unlock him. Press **Tab** or
**D-pad left** to switch between collected characters from anywhere. The camera
follows the character you choose, and the collection is saved between visits.
Wren is the only collectible human; Kai, Camille and Corinne remain villagers.
Darkstalker is a deferred model and does not spawn in the village or collection.

Press **F8 / Y (Triangle)** for the 3D review room. Choose a character, drag to
orbit, scroll to zoom, compare faces and wing poses, and click **Play as** to test
actual walking, running, jumping and dragon flight. Darkstalker has inspection only.
Local book references can be shown alongside the model; reference artwork is kept
in the ignored cache and is not included in exports. See [model sources, builds
and current limitations](../docs/character-models.md).

Umber, Kai, Camille and Corinne now wander beside the village path. Approach one
and press **J / D-pad right** to talk and choose a reply; **Esc / B (Circle)** leaves.
Clay’s replies are selectable buttons, also usable with the mouse or **Enter / A**.
Dialogue uses a bounded reading width and resolution-independent UI sizing for
windowed, full-screen and Retina displays.
There are 54 original conversations with Clay, shuffled separately for each
character before repeating. The children also have their own lines when you play
as Umber. He uses the shared base MudWing rig with a smaller copper-brown appearance, a leather
pouch and a healed mark across his nose bridge, where Clay sees the mud dressing
in [chapter 32 of *The Dragonet Prophecy*](https://wingsoffire.wiki/index.php?section=1&title=Umber#References).
The children use fitted human skeletons and continuous anatomical meshes,
age-specific measured body proportions, authored textured hairstyles, clothing, walking, gaze, blinking and idle activities. Corinne is six in this demo.
The [body review and reference checks](../docs/village-npcs.md#measured-child-proportions) cover exported skin dimensions and standing/walking rigs.
See [cast, dialogue and verification notes](../docs/village-npcs.md).

Build the children's local assets with `python3 game/tools/fetch_human_source.py`,
`python3 game/tools/fetch_hair_source.py`, then the Blender command in the
[village asset build notes](../docs/village-npcs.md#anatomical-asset-build).
Hair [credits and licenses](assets/scavengers/CREDITS.md) are retained in the
source, generated models and in-game help.

## Controls

Pair your Bluetooth controller in the operating system first. Godot accepts any
connected controller, including one connected while the game is running.
Button labels below use Xbox / PlayStation names.

| Action | Keyboard / mouse | Controller |
| --- | --- | --- |
| Talk / continue (village) | J | D-pad right |
| Leave conversation | Esc / Goodbye button | B / Circle |
| Move relative to camera | WASD or arrow keys | Left stick |
| Orbit camera | Click, then move mouse; Q / E turn | Right stick |
| Sprint / extended gallop | Hold Shift | Hold LB / L1 |
| Breathe fire | Hold V | Hold RB / R1 (right bumper) |
| Jump | Space | A / Cross |
| Enter flight | Press jump again in the air | Press jump again in the air |
| Aim flight / climb / descend | Mouse camera pitch | Right-stick camera pitch |
| End flight and fall toward landing | Ctrl | B / Circle |
| Spread / fold wings | F | Use the triggers |
| Adjust wing fold continuously | Hold `[` / `]` | Left / right triggers |
| Tail demonstration: follow → left curl → right curl | T | D-pad down |
| Arm inspection: reach → palm → support (stationary) | G | D-pad up |
| Recenter behind Clay / level flight | C | Click right stick |
| Take over a nearby protagonist (village) | X | X / Square |
| Switch between collected dragons (village) | Tab | D-pad left |
| Release mouse | Escape | Start / Options |
| Camera zoom | Mouse wheel | — |
| Open / close help (collapsed by default) | H or click `(H)elp` | Back / Share |

Light stick input uses the four-beat walk. Above 3.5 m/s it transitions into an
easy gallop, reaching 5.8 m/s at full stick. Holding Shift or LB/L1 transitions
into a separate 18 m/s sprint: the hands catch the chest, the hindquarters drive,
then the body travels through a longer forward bound. Paw placement narrows with
speed. Acceleration and braking happen during support; suspension carries
momentum and allows limited steering. Ground movement follows the turning body,
with wider turning arcs at speed. Walking recovery steps stay staggered through
corners, and airborne paws finish recovering when a run returns to a walk.
See [gait coordination](../docs/clay-gait-coordination.md) for mechanics and checks.

Jump preparation and push take 120 ms combined. The forequarters rise first,
then the hind paws finish the push. The stronger impulse gives about 3.9 m of rise
above takeoff on level ground. Moving jumps keep takeoff momentum
and gain a modest forward impulse; releasing the stick in the air preserves
that momentum. Directional input provides limited air steering.

Stick tilt controls walking speed, with a circular 20% deadzone. Keyboard and stick
diagonals are capped to the same maximum speed. Movement uses acceleration,
braking, gravity, floor snapping and collision. Camera distance shortens against
obstacles. Click in the game to capture the mouse again after releasing it.

Clay blinks continuously at random intervals, with a quick close, slower reopening,
slightly varied blink speeds and occasional paired blinks. This runs automatically
while idle, moving or flying. Timing lives in `data/locomotion.json` under `blink`.

## Load the actual Clay model

Generated `.glb` files remain git-ignored under the existing repository policy.
A fresh clone therefore displays a simple labelled placeholder until you build or
copy a model to **`game/assets/clay.glb`**. Godot imports it automatically; stop and
restart the game after rebuilding. The local workspace already has a generated
asset if the build below has been run successfully.

### Build with the installed Blender on macOS

Install the model dependencies into an ignored local directory (once):

```sh
/Applications/Blender.app/Contents/Resources/5.0/python/bin/python3.11 -m pip install \
  --target cache/clay-python scipy scikit-image pillow
```

Then, from the repository root:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --threads 4 --python-exit-code 1 \
  --python game/tools/build_clay_asset.py
```

Adjust the Blender/Python paths for your installation. Alternatively, use the
prototype's Python environment with `bpy`, numpy, scipy and scikit-image installed:

```sh
python game/tools/build_clay_asset.py
```

This calls the **current** `prototypes/clay/body/build_body.py`, preserving the
sculpting sources. A local compatibility adapter handles the prototype's legacy
animation API on Blender 5. It then bakes a simplified version of the viewer's base palette
into standard glTF vertex colours and exports a material Godot can render. Fine
procedural scale lines from the web viewer are not yet reproduced. The skeleton,
blend shapes and wing-fold clip are retained. The builder also writes the ignored
`game/assets/clay_rig.json`: source joint measurements, muscle attachments, tail
segment lengths and the original glTF wing animation keys.

After pulling new model commits, run the same build command again. A GLB exported
with materials from a later pipeline can be copied to the same path instead;
regenerate the rig sidecar from its matching model source before using locomotion.
The older prototype GLB without materials will load but appear uncoloured.

If the current GLB is already built, export just the runtime rig data with:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 \
  --python game/tools/build_clay_asset.py -- --rig-only
```

Use this only with the matching model source; rebuild the full asset after model
changes. Wing keys come from the GLB itself. Without the anatomy sidecar, Clay
still loads and the overlay asks for a rebuild, but tail and gait motion are off.

## Wings, tail and the first walk

Wings smoothly toggle between spread and folded. Brackets/triggers let you stop at
any intermediate pose. Runtime sampling preserves the original GLB keys because
Godot's animation key reduction changed some intermediate joint poses. Both the
bones and the eight `wingFold` corrective shapes now follow the web viewer's
sampling rule. This restores the authored membrane pleats and skin corrections;
it is not a cloth/self-collision simulation. See [motion notes](../docs/clay-locomotion.md).

The game asset now builds the tail in an extended bind with **36 skinning bones,
one per measured vertebra**, and overlapping smooth weights. The original curled
modeling pose stays in the source files. This avoids retaining small bends from
the old 12-bone curled bind when extended. A full asset rebuild is required when
upgrading an older locally generated GLB.

The tail follows a distance-sampled hip trail with damping, a small idle wave and
ground clearance. Length, bend, self-contact and torso constraints operate on the
whole chain. Collision radii include actual exported tail skin and armor bounds.
If a difficult target cannot be solved in one tick, the last admissible shape is
carried with the character rather than publishing an intersecting pose. Jumping
blends toward an airborne carriage instead of pulling the tip toward the floor.
T/D-pad down demonstrates left/right wrapping; reset returns to normal follow.

## Head and neck examination

Stand still and orbit with the mouse/right stick. From the rear hemisphere, Clay
follows camera direction up to **90° left/right** and **20° up/down**. The normal
ground camera pitch is the neutral framing; pitch tracking measures your look
above/below that framing. Motion is distributed along the four measured neck
sections and the head, with smoothing and an angular speed cap.

When the camera passes around a side into the **front-stage** area, tracking
disengages and the neck/head ease back to the authored rest pose. A small angular
hysteresis avoids flickering at the side boundary. Looking back from behind
re-engages tracking smoothly. Help starts collapsed to a small `(H)elp`
button; press H or click it to show gameplay controls. Development diagnostics
and pose demonstrations are omitted from help. Asset attribution is available
on a separate Credits page.

## Fire breath

Hold V or R1/right bumper to open Clay’s mouth and sustain a flame jet.
Ignition waits for the gape; release stops emission and closes the jaw.
The jet follows his head through gaze, movement and flight. The analog triggers
retain wing-fold adjustment. This is a visual effect; scenery does not burn.
See [mouth and fire notes](../docs/clay-mouth-fire.md) for the resculpt and checks.

## Jumping and flight

A single jump compresses over the paws, lifts the forequarters around the hips,
then pushes off the hind paws. Running takeoffs gather the paws under the moving
torso before planting for the final push. Forelimbs tuck first, hindlimbs follow,
and the body pitches from nose-up ascent through a level apex to nose-down
descent. Forepaws reach toward landing before the hind paws; landing compression
then returns to the ground gait. Press jump again while airborne to enable flight.
Fast double taps are buffered during preparation and activate only after liftoff;
holding the button never counts as a second press.

Flight deploys the wings and cruises forward automatically. Use the camera to aim
and WASD/left stick to steer relative to it. **Actual camera elevation above the
horizon means climbing**, with a slow 0.8 Hz wingbeat. **Level or downward aim
means gliding**, with extended wings. C/right-stick click recenters and levels the
flight view, making level glide easy to examine. Cruise builds to 60 m/s. Holding Shift/LB gradually accelerates toward 180 m/s
(648 km/h); releasing it eases back toward cruise rather than snapping. Aim up
to climb, with up to 45 m/s upward travel normally or 110 m/s with Shift/LB.
Flight look controls allow a steeper 65-degree upward aim for clearing peaks.
There is no overhead altitude cap in the terrain or village scenes.
Ctrl/B ends flight; steering down onto the ground also lands naturally. R resets.

The power stroke and recovery coordinate the shoulder helpers and the existing
fold controls; transitions blend instead of snapping. A distinct reference-led
limb carriage uses moderate held elbow/knee bends, controlled wrist/hock angles,
deliberately different left/right recovery, and a small slow drift. Partial gravity
alignment preserves an engaged pose as the torso pitches. It blends toward reach before landing.
The tail follows the aerial trail instead of hanging
toward the floor. The outer flat ground is enlarged to 500 × 500 m for these demos.
See [gaze, jump and flight notes](../docs/clay-gaze-jump-flight.md) for conventions,
research and limits. This is a controllable flight demo rather than an aerodynamic
simulation; level glide deliberately holds altitude.

## Walking

The first walk uses a four-beat schedule with planted world-space paws, lifted
recovery steps and two-link IK for shoulder/elbow and hip/knee. Separate distal
motion supplies wrist/hock flexion and toe-off. Ground probes choose contact
heights, and reach-triggered steps handle starting and turning. Body bob and roll
are small and the paw solve counters them. Stopping finishes existing steps.
Sharper turns slow down to preserve support. Sprint transitions into the separate
gallop described above.

Each main digit now has a continuous metacarpal/metatarsal ray and three
phalangeal controls; the front thumb has two. Claws follow the terminal phalanx.
Supported toes extend against foot roll, while recovery/jump/flight curl is
distributed across joints. See [the foot anatomy notes](../docs/clay-feet-anatomy.md)
for source references, construction and close-up review.

The [full-leg sculpting pass](../docs/clay-full-legs.md) adds explicit muscle-belly
and tendon profiles, revised shoulder/axillary attachments, elbow/wrist and
knee/calf/hock structure, joint-plane posing, and distributed forearm rotation.
G/D-pad up while stationary demonstrates reaching and palm rotation with the
same foreleg used for support. Moving returns it to the walking pose.

This is a kinematic first pass, not simulated muscle contraction. The existing
muscle/skin weights deform with the rig. It has no independent scapular slide,
toe-pressure or tendon simulation, friction/dynamics model or full-body collision;
per-digit terrain contact and foot orientation on steep/uneven ground need work.

## Files to extend

- `scenes/player.tscn`: physics capsule, visual and spring-arm camera.
- `scripts/player.gd`: movement and camera tuning, exported in the Inspector.
- `scripts/clay_visual.gd`: model path, scale, height offset and forward-axis
  correction. Defaults assume the current builder's +Z forward and Y up.
- `scripts/controls.gd`: keyboard/gamepad action defaults. Add an action with the
  same name in Project Settings → Input Map to override a default.
- `scenes/playground.tscn` / `scripts/playground.gd`: disposable test level.
- `tools/build_clay_asset.py`: local model build and portable base-colour export.
- `scripts/creature_motion.gd`: pose ordering, exact wing keys and corrective shapes.
- `scripts/quadruped_gait.gd` / `scripts/tail_motion.gd`: procedural locomotion.
- `scripts/neck_gaze.gd`: connected cervical/head tracking and front-stage return.
- `scripts/jump_motion.gd` / `scripts/flight_motion.gd`: contact-aware jump poses and flap/glide layering.
- `scripts/flight_limbs.gd` / `data/flight_limbs.json`: indexed-reference flight carriage.
- `scripts/tail_contacts.gd`: conservative self/torso contacts and curvature protection.
- `tools/game_tail_bind.py` / `tools/tail_envelopes.py`: game-only extended bind and measured collision envelopes.
- `data/locomotion.json`: gait timings, clearance, response and source references.

The collision capsule is intentionally simple and independent of the dense dragon
mesh. Wings and tail are visual only. Terrain, full-body collision and a run/trot
can be added separately.

## Verification

```sh
godot --headless --path game --editor --import --quit
godot --headless --path game --script res://tests/movement_smoke.gd
godot --headless --path game --script res://tests/climbing_smoke.gd
godot --headless --path game --script res://tests/protagonist_smoke.gd
godot --headless --path game --script res://tests/motion_smoke.gd
godot --headless --path game --script res://tests/gaze_flight_smoke.gd
godot --headless --path game --script res://tests/jump_arc_smoke.gd
godot --headless --path game --script res://tests/tail_flight_limbs_smoke.gd
godot --headless --path game --script res://tests/feet_smoke.gd
godot --headless --path game --script res://tests/limbs_smoke.gd
godot --headless --path game --script res://tests/wing_pose_dump.gd
python game/tests/verify_wing_sampling.py
python game/tests/compare_tail_bind.py
python game/tests/verify_foot_skin.py
python game/tests/verify_leg_skin.py
```

On this Mac, replace `godot` with
`/Applications/Godot.app/Contents/MacOS/Godot` if it is not on your PATH.
The smoke test drives real physics ticks and checks walk/sprint/analog speed,
diagonal normalization, camera-relative movement, jumping/landing, wall collision,
respawn and model import (or the placeholder when no GLB is present). Physical
Bluetooth pairing, controller mappings and stick feel still need a hardware check.
The motion test requires the generated model and rig sidecar. It checks corrective
weights through wing scrubbing, toggle/fine controls, tail extension/idle/lengths,
reset, ground contacts, support count and limb stretch during walking and turning.
The independent wing comparison needs numpy/scipy (use the Clay build Python).
To render review PNGs into the ignored `cache/motion-review/` folder:

```sh
godot --path game --script res://tests/render_motion_review.gd
godot --path game --script res://tests/render_gaze_flight_review.gd
godot --path game --script res://tests/render_tail_limbs_review.gd
godot --path game --script res://tests/render_feet_review.gd -- after
godot --path game --script res://tests/render_legs_review.gd -- after
```


## Original procedural materials

Clay now uses the scale, palette, roughness and membrane rules from
`prototypes/clay/head/head-viewer.js`, ported to `shaders/clay.gdshader`.
Forward+ (Metal on macOS) supplies linear HDR lighting and ACES tone mapping.
Full model builds regenerate the shader and pack the source design/rest
coordinates into glTF UV channels for Godot. Geometry and animation are unchanged.

For an existing generated model, run `tools/pack_clay_material.py` with Blender's
Python to add the material channels without rebuilding the sculpt. Assets lacking
these channels retain the portable color fallback. The plain-clay review toggle
remains available.
