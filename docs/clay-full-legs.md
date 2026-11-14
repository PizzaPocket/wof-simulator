# Full leg form, arm use and flight carriage

The user requested a sculpting/design pass through the complete limb, including
musculature and ankle/wrist transitions. They explicitly corrected the flight
brief to **asymmetrical**, resting but visibly engaged limbs. A fully limp
gravity-led hang was rejected in review. A pose adjustment alone would
not satisfy this request.

## Evidence and interpretation

The side-sheet front-leg crop is x380–700, y450–840 at working width1400. It
shows a rounded anterior upper-arm plane, posterior elbow point, fuller proximal
forearm and a narrower wrist. Existing side-sheet mapping remains
z=(700−px)/343, y=(830−py)/343. How to Draw (crop x330–1020, y830–1440 at width1400)
shows the broad connected shoulder, haunch, knee direction and long hind-foot
segment from an oblique angle. Its foreshortening is not converted into invented
orthographic bone lengths. The limited-edition render and SE poster supply
arm-like elbow/wrist carriage and differing bends/heights in airborne limbs.

Real anatomical references used for the underlying arrangement:

- [Felid forelimb musculature and scaling](https://pmc.ncbi.nlm.nih.gov/articles/PMC5341599/):
  weight support and other forelimb functions; proximal muscle/tendon architecture.
- [Cat forelimb morphology and locomotor function](https://pmc.ncbi.nlm.nih.gov/articles/PMC11737544/):
  proximal concentration of muscle, coordinated reaching, and forearm rotation.
- [Feline antebrachiocarpal rotation study](https://pubmed.ncbi.nlm.nih.gov/33225430/):
  supports treating supination/pronation as forearm motion rather than twisting
  the wrist alone. The model uses a coupled skin control, not independent radius
  crossing over ulna.
- [Komodo thoracic-limb anatomy](https://pmc.ncbi.nlm.nih.gov/articles/PMC10525242/):
  biceps/brachialis, triceps insertion at the olecranon, and forearm compartments.
- [Komodo pelvic-limb anatomy](https://pmc.ncbi.nlm.nih.gov/articles/PMC11718905/):
  thigh retractors, lower-leg compartments and ankle plantarflexor architecture.
- [Quadrupedal intersegment coordination](https://pmc.ncbi.nlm.nih.gov/articles/PMC4517757/):
  distinct fore/hind limb organization and coordinated multijoint motion.
- [University of Veterinary Medicine Budapest forelimb joints and muscles](https://univet.hu/wp-content/uploads/2019/11/Forelimb-joints-and-muscles_Diana-Hazai.pdf):
  shoulder/elbow/radioulnar structure and the trapezius, rhomboid, serratus,
  pectoral and latissimus attachments used to design the girdle.

These references guide mechanics and mass distribution. Clay retains his art-led
proportions, feet and armor intent. Socket locations are revised at the user's
request; the foreleg socket is raised and the wing root moves forward/high, then
back slightly after review. Muscle outlines hidden beneath
skin and armor are adaptations; the station radii are not claimed as measured
dragon dissections or exact reconstructions of hidden artwork.

## Form from the skeleton outward

| Region | Source design change |
| --- | --- |
| Shoulder | Broad cap retained; a shoulder attachment helper follows half of upper-arm rotation to reduce flattening at the socket. |
| Girdle | Foreleg socket raised to y1.12; wing root placed at [0.36,1.30,0.59], including a 0.06 rearward correction after the initial forward placement. Trapezius/rhomboid and serratus forms connect the scapular region to the back and ribs; a separate shallow pectoral attachment supports the fictional dorsal wing socket. |
| Upper arm | Anterior biceps belly and medial brachialis/triceps envelope have explicit belly/tendon stations; posterior triceps tapers toward its olecranon insertion. |
| Elbow | Olecranon belongs to the ulna/forearm instead of being split uniformly between upper and lower arm. Tendon attachment weights hand over near the joint. |
| Axilla | Pectoral and latissimus insertions are moved toward the proximal humerus; the oversized medial fill is narrowed. The old chest-to-elbow construction became an excessive skin sail during arm use. |
| Forearm | Radius and ulna have distinct underlying fields. Extensor/flexor bellies peak proximally and taper toward tendons; the carpus remains a broad, smaller joint entering the palm. |
| Hip/thigh | The broad gluteal and quadriceps/hamstring envelopes remain coherent under the skin, with proximal belly concentration and a taper toward the stifle. Hip attachment uses a half-rotation helper. |
| Knee | Small anterior patellar/tibial-crest support establishes direction without adding a ball-shaped exposed knee. Hamstring attachments hand over toward the upper shin. |
| Calf/hock | Gastrocnemius has a proximal belly narrowing into a calcaneal tendon region; tibialis tapers anteriorly. Tibia/fibula and calcaneal point remain legible beneath this surface. |
| Metapodium/toes | The prior connected-ray/phalange pass remains intact. The raised hock leads into a long, comparatively lean metatarsal segment. |

Muscle profiles are positive cross-section scales along each existing origin-to-
insertion path, stored in body_design.json. Shape-preserving cubic interpolation
avoids rings at station boundaries. Ends are rounded and embedded in neighboring
fields. Attachment-weight paths follow the same coordinate, with smooth handovers
among torso, helpers, upper/lower limb and foot. They replace uniform whole-belly
weight mixtures where those mixtures dragged tissue across a bending joint.

This is skinned sculpted musculature. It does not simulate individual contracting
muscle fibers, tendon forces or changing muscle volume under load.

## Limb mechanics and arm inspection

Link lengths are measured from the revised source and stay fixed within poses.
The raised foreleg socket changes the source humerus length; wing root/elbow/wrist
move together, preserving wing-arm link lengths. Upper and lower links share a bend-plane
frame instead of receiving independent shortest-arc rotations, reducing elbow/knee
corkscrew. Reach limits prevent complete lockout or extreme folding; their values
are conservative game tuning rather than measured species-specific ranges.

Each forearm has a twist control between the elbow and hand. Distal skin weights
gradually adopt that rotation. The hand follows the forearm while retaining wrist
flexion. The hind shanks do not get this arm-like roll control.

Free-hand orientation is constructed in the forearm's frame, with a modest
wrist bend. The earlier body-frame hand aim counter-rotated against a raised
forearm and made the carpus collapse. Wrist targets and hand orientation now have
separate roles; the planted gait still uses a ground-oriented hand.

Two intermediate carpal skin controls distribute the forearm-to-hand rotation
around the same wrist center. Their attachment-weight paths preserve the rounded
carpus in palm inspection, rather than collapsing a large wrist bend through one
linear blend. These are deformation controls, not extra anatomical joints. Radius
and ulna have distinct, offset source fields; the skin-twist approximation remains
simpler than a complete radioulnar joint simulation.

G / D-pad up cycles left-arm **reach → palm inspection → support** while stationary.
The other three paw anchors remain planted. The same forelimb skeleton is used in
walking and reaching. Moving cancels the inspection and blends toward support;
jump/flight use their own pose transitions. This is an examination aid and a basis
for future arm interaction, not a pickup/grasp physics system or a dynamic balance
simulation.

Arm inspection uses a deliberate down/back elbow pole. Reusing the walking
rest pole for a forward/upward hand target sent the elbow far outward and above
the shoulder, amplifying the axillary deformation. The corrected pole is checked
for elbow height/lateral excursion, not only for a hand reaching its target.

## Resting but engaged asymmetrical flight

The rejected pose folded both hind knees strongly, directed shanks rearward, then
rotated the long foot by118°. That produced a forced zigzag. A subsequent
near-straight gravity-led hang was also rejected as limp. The current profile
holds elbows and knees in moderate active flexion, with controlled wrist/hock
angles and gently curled digits rather than either extreme.

Left/right offsets deliberately differ: one hind leg recovers slightly higher,
the other hangs longer; forelimb bends and finger curl differ more subtly. A small
slow drift adds motion without using random asymmetry as a substitute for a good
rest shape. A partial gravity alignment (40%) keeps the held pose related to the
torso's attitude while avoiding a rigidly carried or fully dangling limb. Landing reach blends in
near the ground. All pose numbers are explicit in flight_limbs.json.

## Review and limits

The source check verifies positive smooth profiles, attachment weights and solid
skin support along the skeletal chains. Exported weights, runtime chain lengths,
arm/support transitions, forearm rotation, airborne relaxation/asymmetry and
existing gait/jump/flight/tail behavior are checked separately. Native Godot
captures use identical before/after cameras, painted and plain clay, and show
walking, reach/return, palm rotation and flight motion alongside the indexed art.

Remaining limits include close-range voxel faceting, no independent scapular
slide, no muscle-volume simulation, and no per-digit terrain contact/pressure.
Full-body/wing/limb collisions remain outside the capsule-based playground physics.

Final validation passes: 32 mirrored muscle profiles and their attachment paths,
17 wing-fold chain samples, body-supported sockets/anchors, exported skin and
claw influences, 990 frames of arm/support/flight transitions with stable sockets
and a forearm-relative wrist pose, 973 frames of digit articulation, the gait and
gaze/jump/flight suites, and the 2,358-frame tail stress suite. Source wing-key
sampling agrees with Godot within approximately 1.2e-6 per matrix element.
