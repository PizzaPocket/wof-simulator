# Coordinated walking and speed-driven running

The slow four-beat walk keeps its existing clearance and wrist/hock curves.
Recovery steps normally follow hind-left, front-left, hind-right, front-right.
An urgent planted paw can take priority, but an airborne foreleg prevents the
other foreleg lifting, and likewise for the hindlegs. Minimum step separation
prevents simultaneous starts. Support pacing slows movement and rotation while
feet reposition. A pivot can pause completely while a stretched planted foot
waits for its partner to land. Recovery remains available at zero travel speed
for a strained stance, so that pause cannot lock the feet in place.

Landing prediction includes angular motion around the body. Outer and inner
feet therefore take different arcs. A landing ray that hits an unreachable wall
top retracts the proposed step onto nearby ground. Ground travel follows the turning body's
heading, with a lower maximum angular speed when running fast. Acceleration and
braking operate on the horizontal velocity vector, avoiding extra diagonal
acceleration. Planted paws remain anchored in world space.

Running starts above 3.5 m/s and returns to walking below 2.9 m/s. Full normal
stick travel remains 5.8 m/s, now in an easy transverse gallop rather than a
sped-up walk. Holding Shift or LB/L1 still accelerates to 18 m/s. Between 6 and
16 m/s it blends into a separately authored sprint in `sprint_bound.gd`, with
its own contact schedule, body key poses and limb recovery curves. The easy
run's curves remain unchanged at normal full-stick speed.

The sprint uses an 8.6 m nominal stride. Hands contact at phases 0.00/0.11,
hind feet at 0.32/0.44; forelimb support occupies up to 0.24 of a cycle and hind
support up to 0.17. The body catches low over the hands, passes over the planted
forearms, compresses at the hindquarters and drives into an extended suspension.
Separate pelvis, spine and chest poses show the load transfer. The chest drops
slightly during the hand catch. The arms open earlier during flight, extend well
ahead of the shoulders, and hold that reach briefly before landing. These are
authored dragon poses, not measured gorilla kinematics. Trunk poses are cleared
before jump/flight updates and never accumulate.

During acceleration or a pose transition, a limb may unload early if its
predicted reach would exceed the available length. Its recovery then continues
to the next scheduled touchdown. Airborne recovery follows both translation and
rotation of the torso; planted contacts remain fixed.

Leading and trailing contacts are staggered and have different sprint reach and
recovery curves. Forelimb and hindlimb recovery also have different timing.
Landing targets converge inward by 8% in the easy run and 25% in the sprint;
these are art-directed starting values for Clay's anatomy, not measurements of
an animal. Convergence applies to future contacts, leaving planted paws fixed.
Run-to-walk transitions finish existing airborne recoveries instead of instantly
planting airborne feet. An already tucked paw settles without a second lift.

The reference mix follows Clay's proportions. Horse and dog gallop studies
inform support, propulsion and suspension. Ape forelimb research informs neutral
hand/wrist support and forearm loading; it does not establish this sprint's
contact timing or imply that Clay knuckle-walks. The heavy hand catch and forward
bounds are an art adaptation to his long forearms, broad clawed hands and tail.

References:

- [Bertram and Gutmann: horse and cheetah gallop mechanics](https://pmc.ncbi.nlm.nih.gov/articles/PMC2696142/).
- [Kivell and Schmitt: gorilla and chimpanzee hand/wrist support](https://pmc.ncbi.nlm.nih.gov/articles/PMC2732797/).
- [Gorilla knuckle-walking mechanics](https://pmc.ncbi.nlm.nih.gov/articles/PMC12575676/): walking evidence, not a sprint template.
- [Walter and Carrier: different limb roles in galloping dogs](https://pubmed.ncbi.nlm.nih.gov/17210958/).
- [Predictive horse locomotion and gait transitions](https://academic.oup.com/icb/article/64/3/694/7713463).
- [Siberian Husky Club illustrated gait standard](https://www.shca.org/gait): an example of speed-related foot convergence, specifically discussed in the context of trotting.

Validation uses the actual exported rig and controller. `gait_coordination_smoke.gd`
checks both directions of walking turns, light-stick recovery, easy-run selection,
sprint convergence, running corners and stopping. Existing movement, motion,
run/jump and limb checks cover input, anchored contacts, bone lengths and airborne
transitions. `render_gait_review.gd` renders side sequences plus front, rear and
overhead poses, and a walking corner into `cache/gait-review/`.

Validation runs at fixed 60 Hz. In addition to contact and transition checks,
`run_jump_smoke.gd` measures forward suspension distance, whole-body vertical
travel, wrist reach ahead of the shoulder, and elbow articulation during actual
planted forelimb support.

The rendered review contains 327 frames. Side clips are sampled every two
physics ticks; `export_gait_review.py` uses the tick manifest to preserve timing
and exports a labeled comparison, individual clips and viewpoint sheets. Pass an
output directory after `--` to the renderer and as the first argument to the
exporter; the hand-supported sprint review uses `cache/hand-sprint-review/`.

The final fixed-60-Hz run/jump check measures 18 m/s top speed, forward suspension
covering up to 4.2 m, 0.39 m of visual body-height travel, and wrists reaching
1.28 m ahead of the shoulders during support. Supported elbow angles range from
about 71 to 118 degrees. Run/jump, gait-coordination, motion and feet integration
checks pass, including wall braking and reversals. All easy-run settings remain
unchanged; the new profile applies above normal full-stick speed.
