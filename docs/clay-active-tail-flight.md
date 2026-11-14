# Active tail posture and powered flight

This runtime pass is independent of the head/mouth sculpt. It changes no model
builders, exported meshes, shaders, mouth poses or fire effects. The authored
wing storage fold is also unchanged; its larger articulation revision remains
separate work.

The tail retains distance-sampled follow-through and conservative contact
capsules. Following user review, the tip-led idle sweeps were removed: they read
as an unsettling worm-like wiggle. There is no separate idle oscillator now.
When Clay stops, the tail retains its settled shape, including broad curves to
either side, rather than seeking a perfectly straight line behind the body.
Stationary pelvis settling carries the trail rather than creating false travel.

Untangling is reserved for severe chord compression, excessive accumulated
curvature (over 240 degrees), or repeated solver rejection. Recovery favors a
broad 125-degree curve on the same side. The recovered shape becomes the new
resting pose, and movement resumes from that shape instead of an old coiled
trail. Quiet does not mean rigid: movement, turning, gravity and contacts still
produce follow-through.

The contact solver tries shorter steps from the last admissible shape before
falling back. Crucially, its final exact-length projection also respects the bend
limit. Previously that projection could reintroduce a bend violation after the
constraint iterations and reject a useful recovery step.

Cat muscle anatomy supports active posture control rather than a purely dragged
tail: [Wada et al., 1994](https://doi.org/10.1292/jvms.56.1107). The recovery
thresholds and preferred recovery curve are animation choices, not measured feline reflexes.

Flight cruise is 24 m/s and boost is 34 m/s, up from 12 and 17. Acceleration is
14 m/s² horizontally, with the vector increment capped consistently at all
headings. Vertical acceleration, climb/descent limits and turn response increase
alongside traversal speed. The existing 0.8 Hz steady flap cadence remains.

Flight entry requests powered strokes even at a level camera angle. For the
first 1.7 seconds, launch effort increases stroke amplitude by up to 35% and
frequency by up to 12%, easing into level glide or sustained climbing. Wings
deploy in 0.45 seconds. Elbow, wrist and finger recovery overlap with slight
phase delays instead of replaying a uniform fraction of the storage fold.
Small joint rotations derive from the rig's authored articulation, with caps
of 14 degrees for arm/wrist and 5 degrees for fingers. Their attachment points
and segment lengths stay fixed. This is an animation controller, not an
aerodynamic force simulation.

Research informs these choices without specifying a dragon's exact timing:
[bat upstroke flexion](https://pmc.ncbi.nlm.nih.gov/articles/PMC3385481/) and
[wingbeat amplitude versus frequency across flight demands](https://pmc.ncbi.nlm.nih.gov/articles/PMC9403799/).

Checks:

```sh
Godot --headless --fixed-fps 60 --path game --script res://tests/active_tail_flight_smoke.gd
Godot --headless --fixed-fps 60 --path game --script res://tests/tail_flight_limbs_smoke.gd
Godot --headless --fixed-fps 60 --path game --script res://tests/gaze_flight_smoke.gd
Godot --rendering-method gl_compatibility --fixed-fps 60 --path game --script res://tests/render_active_motion_review.gd
```

The review script writes ignored PNGs to `cache/active-motion-review/`.

Verification on the current local asset passed all three smoke scripts. The
2,358-frame tail stress run retained a 16-degree maximum bend and less than
0.01 mm segment-length error, with no contact penetration or safe-shape carries.
The revised active-posture check recovers from a 2.79 m cramped chord to a
5.21 m broad curved rest, and holds comfortable left and right curves for ten
seconds each with no measurable tip drift. The 2,358-frame contact stress check
and movement integration check pass without penetration, segment stretching or
safe-shape carries. Cruise remains 24 m/s. `render_tail_rest_review.gd` captures
the two comfortable resting curves and matching views five seconds later in
`cache/tail-rest-review/`. The separate wing fold work is recorded in
[the wing motion sheet](clay-wing-fold.md).
