# MudWing village friends

See [marsh and motion changes](marsh-and-motion.md) for the raised wetland village,
soft mud, high nest entrances, revised child movement and subtle complexion colors.

The main wetland scene now spawns Umber, Kai, Camille and Corinne beside the dry
village path. Walk toward the first group from Clay's starting point. Nearby
characters have a talk prompt that identifies them. Names appear in the dialogue
box during conversation, with no overhead labels. Press **J / D-pad right** to begin
and select a reply; **Esc / controller B (Circle)** or the Goodbye button ends the
conversation. Click a response, press **J / D-pad right**, or use **Enter / A**
on the focused button. Clay’s words appear as player response buttons in a separate stack to the right
of the other character’s speech box. Selecting a response advances directly to their answer;
Clay never appears as a separate speaker card. The existing exchanges each offer
one authored reply at a time.

The UI uses a 1280 × 800 logical canvas with `canvas_items` rendering, explicit
`expand` aspect handling and HiDPI enabled. The dialogue layout is capped at 960 logical units, centered with 56-unit bottom
clearance: a rounded speech box on the left, the speaker’s name inside above their words,
and a separate 300-unit-wide stack of response/Goodbye buttons on the right. Text is rendered
at the actual display resolution. Wider aspect ratios reveal more of the world
while retaining the dialogue’s text size and reading width.

Clay and the speaker stop walking during dialogue. The speaker turns toward
Clay, while the other villagers continue their activities. Flying and jumping
prevent new conversations. Walls block the talk prompt. Walking away by an
external reset also closes a conversation. Gameplay resumes when dialogue closes.

## Cast

- **Umber** reuses Clay's rig at 77.5% of Clay's scale. His quieter mahogany
  palette, pale amber irises and diagonal scar across the top of his snout are
  material variants. A brown leather satchel follows his shoulder through a bone
  attachment. His measured walk, tail, cervical gaze and random blinks use the
  existing dragon animation systems. He wanders between dry path stops, watches
  the surroundings and looks down toward his pouch.
- **Kai**, nine, has medium-short brown hair with closely fitted sides, a loose teal shirt and trousers. His nose has a small local width increase and reduced projection, preserving the other accepted facial features.
- **Camille**, nine, has full, long pale blonde hair with a slight wave,
  a loose green shirt and trousers. She is Corinne's older sister.
- **Corinne**, six for this demo, is shorter and has full, long curly strawberry blonde hair,
  a loose dusty rose shirt and trousers.

The children use a continuous anatomical mesh, child shape targets and a fitted
163-bone skeleton from MakeHuman, including fingers, toes and facial joints.
The body build interpolates the source's one- and ten-year anatomy at each child's
actual age. It uses a low-muscle, slim source shape with the accepted face and
hair held fixed. Authored measurement morphs fit external shoulder and arm
landmarks; cross sections of the skin fit chest dimensions and limb/torso girths.
The reference dimensions are recorded in `game/data/child_proportions.json` with
source tables and measurement definitions. The final silhouette follows the user's visual direction: gentler sloping
shoulders, reduced deltoid fullness, shorter arms and smaller hands. The numerical
reference pass is retained as a dimensional guide, rather than a requirement to
keep limb lengths the user found too lanky. Backpack geometry is removed.
The source breast-weighted regions are merged into their trunk parent before
fitting; the entire front/back torso is faired into a plain surface.
Shirts and trousers are made from separate front/back fabric patterns, sewn along
side, shoulder and inseam edges, with open collars, hems and cuffs. Blender cloth
is pinned at neckline/waistband and collision-draped over the child body.
Trousers are baked first and added to the shirt collider set so the shirt hem
hangs outside the waistband and hips. The
baked mesh gets thickness and rolled hems before skinning for game animation. Shoulder/elbow/wrist IK
lets the hands hang beside the body. Leg IK raises the pelvis by the geometric
amount required to stand over the feet, avoiding the source A-pose crouch.
Their idle behavior includes
looking around, blinking independently, watching nearby Clay. Props do not appear spontaneously in their hands. They walk short routes near each other on the dry village path. The demo
assumes they and the dragons can understand each other, as requested; this is
an original village visit rather than a reconstruction of a scene from a book.

## Dialogue

`game/data/village_dialogue.json` contains **54 original exchanges**: 18 for
Umber and 12 for each child. Clay replies within each exchange. Each character
has a shuffled conversation bag, which exhausts before repeating and avoids an
immediate repeat when it refills. History lasts for the current play session.

The dialogue was edited with the **No AI Slop** skill: specific small incidents,
spoken phrasing, varied exchange lengths, and distinct interests for each speaker.
Umber talks about Reed, Sora, family, food, school and adjusting to peace. Kai
explores and makes plans faster than he checks them; Camille draws maps and
looks after her sister; Corinne collects pebbles and builds a tiny bakery.
No dialogue is copied from the novels. The children and their relationship to
Clay and Umber follow the user's demo premise.

Umber's scale ratio, pouch design, routes, outfits and incidental anecdotes are
artistic choices. References for his appearance and family/personality:

- [Umber character reference, with book citations](https://mirror.wingsoffire.wiki/wiki/Umber)
- [Scholastic's official *The Hybrid Prince* excerpt](https://kids.scholastic.com/content/dam/scholastic/kids/pdf/Book%20Excerpts/WOFTheHybridPrince_excerpt.pdf)

## Implementation and checks

- `scripts/village_npc.gd` shares Clay's body/pose contract but overrides player
  movement and input with autonomous routes, stops and gaze targets.
- `scripts/scavenger_visual.gd` loads the fitted models and evaluates limb IK, gaze
  and absolute eyelid shapes. `tools/build_scavengers.py` creates the skinned assets
  and the sewn leather pouch.
- `scripts/village_conversations.gd` handles discovery, dialogue bags and UI.
- `tools/port_clay_shader.py` preserves the Umber variant when rebuilding Clay.

Run from the repository root (substitute your Godot executable):

```sh
godot --headless --path game --log-file /tmp/village-npc-smoke.log --script res://tests/village_npc_smoke.gd
godot --path game --log-file /tmp/village-review.log --script res://tests/render_village_review.gd
```

The smoke check covers all four actors, nonrepeating dialogue bags, wandering,
input isolation, conversation entry/advance/exit, respawn and airborne gating.
The graphical review saves images under `cache/village-review/`.

The current demo has text dialogue without voice audio, quests or persistent
conversation saves. NPCs follow local dry-ground routes rather than a navigation
mesh. The dragon still requires the existing locally generated Clay asset and
rig sidecar; no separate Umber model build or downloaded character assets are
needed.

Validation for this change: the village NPC smoke and existing movement smoke pass;
the character and conversation renders were inspected with Godot's Metal renderer.
The existing `motion_smoke.gd` reports 5.84 cm of resting tail travel against its
4 cm threshold. An isolated copy with the pre-conversation player/motion code
reproduces the same 5.84 cm result. This existing tail-idle failure is outside the
NPC change; the remaining motion checks pass.


## Anatomical asset build

The rejected primitive children and tube-strand hair have been replaced. The
runtime uses actual skin meshes, hands with five articulated digits, fitted shoes,
continuous trouser/pelvis topology, separate woven garments, closed shoes and
four eyelid shells. Blinking samples absolute lid shapes over fixed eyeballs;
it never changes eye transforms. The original eye bug overwrote each eye's small
vertical scale with a value up to 1.0 during blinking.

Hair now uses authored meshes, UVs and 2K strand textures: MakeHuman `short02` for
Kai, `elvs_hazel_hair` by Elvaerwyn for Camille, and
`punkduck_alpha7_curly2` by punkduck for Corinne.
Colors are adapted to the character descriptions. Long hair blends between head
and upper torso weights. This is game hair geometry without a separate opaque
scalp cap or procedural rope strands. Hair uses the existing skeleton. Clothing has a baked build-time cloth
drape; runtime movement uses skinning. See [asset credits and licenses](../game/assets/scavengers/CREDITS.md).
Credits also appear on the in-game Credits page and in the generated GLB metadata.

Fetch sources once, then build with the same Blender installation used for Clay:

```sh
python3 game/tools/fetch_human_source.py
python3 game/tools/fetch_hair_source.py
/Applications/Blender.app/Contents/MacOS/Blender --background --threads 4 --python-exit-code 1 --python game/tools/build_scavengers.py
godot --headless --path game --editor --import --quit
```

The builder uses the existing `cache/clay-python` numpy/scipy/Pillow dependencies.
It writes `game/assets/scavengers/{kai,camille,corinne,umber_pouch}.glb`. As with
Clay, generated GLB files are local ignored assets. A single child can be rebuilt
by appending `-- corinne` (or another character ID) to the Blender command.

The build also generates skin textures from the authored MPFB UV-space lip
boundary. Palette-only changes can be rebuilt with
`python3 game/tools/build_skin_tints.py` without rebuilding the skeleton or mesh.

`game/data/scavenger_design.json` records character colors, heights, hair asset
choices and the construction intent. Source anatomy is pinned to the MakeHuman
commit recorded there. Fetched asset manifests record file digests. Metrics beside
the generated assets record each model's vertex and bone counts.

## Measured child proportions

The earlier width warps were removed. Their tests preserved bone lengths but
could not establish that those lengths or body shapes were correct. The current
build uses age-specific benchmarks from [NCHS child body dimensions, Series 11
No. 143](https://stacks.cdc.gov/view/cdc/12665/cdc_12665_DS1.pdf), tables 10, 11,
13, 16, 17, 19–21, 24 and 25. Arm lengths use age medians; breadths and girths
use the 25th percentile to match the requested slim builds, scaled to each
character's chosen height. These historical population measurements are authoring
references, not a claim that all children share one body shape.

`tools/child_anatomy.py` applies the pinned source age and muscle/weight morphs,
then applies the user-directed shoulder/arm/hand silhouette and fits skin cross sections.
External acromion/olecranon/wrist landmarks are kept distinct from joint centers.
The authored limb targets are recorded separately from the population references.
Surface fitting uses skin weight domains and does not move the skeleton's joint
helper vertices. The accepted head assembly is blended only at the neck.

Each build writes a `*_proportions.json` report beside the generated GLB.
`tools/verify_child_proportions.py` reads the **exported GLB skin** and cuts it
again, catching unit, export and subdivision changes. Body girths and chest sections are checked within 4% of their height-scaled
references. External landmark lengths are checked within 3.5% of the final
art-directed build targets. This establishes specific dimensional checks; visual review
is still required for silhouette, cloth fit and pose.

```sh
/Applications/Blender.app/Contents/Resources/5.0/python/bin/python3.11 game/tools/verify_child_proportions.py
godot --path game --log-file /tmp/child-review.log --script res://tests/render_child_proportions.gd
/Applications/Blender.app/Contents/Resources/5.0/python/bin/python3.11 game/tools/make_child_review.py
```

The review includes unposed anatomy, front and side standing views, and skeleton
overlays. The contact sheet at `cache/child-proportions/review.png` shows the final standing
characters, shirt drape and footwear without a measurement table. Faces and hairstyles are preserved.

Additional regression check:

```sh
godot --headless --path game --log-file /tmp/scavenger-anatomy.log --script res://tests/scavenger_anatomy_smoke.gd
```

It simulates two minutes of blinking per child, verifies unchanged eye scales,
checks the finger/toe/spine joints, enforces fitted bone lengths through a walk,
and checks foot contact, standing leg alignment, sagittal knee extension and hand clearance. Run
`res://tests/render_scavenger_review.gd` with a graphical renderer for front,
three-quarter, rear, face, closed-lid and walking views plus the pouch close-up.


## Cloth and footwear construction

`game/tools/child_garments.py` creates independent fabric panels and assembles
their seams. The shirt has straight sides and an untucked hem; the trousers have
continuous hip/crotch panels and loose leg tubes. A 36-frame offline cloth solve,
followed by fold relaxation and collision projection, settles them over the body.
A 1.4 mm fabric wall and rolled edges make the openings readable. The resulting
folds are baked, not a runtime cloth simulation. `*_cloth.json` records the bake.

Shoes are sized from each actual foot's heel/toe bounds and transverse profiles.
They have flat, closed soles below the foot bottom, curved laces on the upper,
and stitched welts. Skin enclosed by the shoes is omitted from the visible mesh;
the full toe/ankle rig is retained. This prevents the foot surfaces from appearing
through the sole during a step. The review script includes close footwear and
walking views.

## Dialogue UI review

`game/tests/dialogue_ui_review.gd` checks all 54 exchanges for overflow, verifies
that selecting a reply consumes the player line, checks final-line exits and
keyboard/controller activation, and exercises window sizes from 800 × 500 through
3440 × 1440. Run without `--headless` to save screenshots in `cache/dialogue-ui-split/`;
headless mode performs the same layout and interaction checks without screenshots.
Scaling follows [Godot’s multiple-resolution guidance](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html).

The relaxed arm carriage is slightly narrower at the shoulders, with a closer
elbow pole and hands still clear of the shirts. Lip tint strength is 0.45 on
all three children. It is baked into skin albedo from the CC0 HM08 lip-boundary
texture, so it follows the vermilion edge in UV space instead of a face-space oval.
Eyebrows use densely overlapping short hairs projected onto the brow surface,
with lower placement and tapered width. Kai’s localized nose settings are recorded in his character
entry in `scavenger_design.json`; they apply after the preserved head is blended
onto the body. Outside the nose and its subdivision transition, the exported
skin positions are unchanged. Matching-angle portraits are captured by
`game/tests/render_kai_face.gd` into `cache/kai-nose-review/`.
