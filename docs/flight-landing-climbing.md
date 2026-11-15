# Flight turns, high-speed landings and climbing

## Flight turns

**Problem.** Flight used to slide the velocity straight toward the new direction while the body
spun to face it, so a reversal passed through zero speed and the dragon flew backwards or sideways.

**What animals do** (summarised from the research below, not copied):

- Birds bank. A pigeon's level 90 degree turn is made by rotating the whole body to redirect the
  aerodynamic force, not by beating one wing harder, and raptors twist the tail to cancel adverse
  yaw ([Ros et al., PNAS 2011](https://sites.bu.edu/pierson/files/2021/05/ros2011pnas.pdf);
  [tail twist, bioRxiv preprint](https://www.biorxiv.org/content/10.1101/2023.12.29.573672.full.pdf)).
  Once banked, symmetric wing and tail morphing tightens the turn by raising lift.
- Bats bank and yaw together. In a 180 degree U-turn a bat dropped its speed from about 2 m/s to
  0.5 m/s to cut the force needed, widened the inside wing's flap relative to the outside wing, and
  used roughly 40% more power than straight flight
  ([U-turn study](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7608926/)). Another study found the
  inside wing's downstroke faster during an L-turn, the reverse of expectation, so the evidence on
  wing asymmetry is mixed.

**What the game does** (`player.gd` `_fly`, `flight_motion.gd`, `data/locomotion.json` `flight`):

- The body turns at a limited yaw rate, and the rate is capped by a lateral-acceleration budget
  (`lateral_accel_m_s2 / speed`), so a fast dragon turns in a wide arc.
- A turn tighter than the speed allows is flown by shedding speed with flared wings
  (`turn_brake_m_s2`), as a bat does, down to `min_turn_speed_m_s`, then accelerating back.
- Velocity is pulled onto the heading within a fraction of a second (`align_rate`), so there is no
  sideslip and no backwards flight.
- The body rolls into the turn (up to about 55 degrees). The wings react: beat frequency up to about
  2.1x, stroke up to 1.4x, and the inside wing about 45% wider than the outside one. Hard flapping
  also applies while braking. Wing asymmetry follows the bat evidence; the bird evidence says the
  bank does most of the work, which is why the bank is large.
- The smoke test (`tests/flight_turn_landing_smoke.gd`) reverses a cruising dragon and checks that
  velocity stays within the heading's forward half-space (alignment above 0.55), speed drops but
  stays above 8 m/s and below half of cruise, wing effort peaks above 0.7, the turn finishes in under
  300 frames and cruise speed recovers.

## High-speed landings

Large birds that arrive fast land ballistically: they flare (pitch up to stall), use their legs as
brakes and shock absorbers, and sometimes skid
([JEB, wing to leg forces during landing](https://cob.silverchair.com/jeb/article/217/15/2659/12207/Transition-from-wing-to-leg-forces-during-landing);
general accounts of flaring and leg braking). Dragons are far heavier, so they bound.

Above `bound_speed_m_s` (20) a landing braces on the legs (the existing landing pose, at 1.6x depth),
loses 40% of its speed on impact (`bound_keep`), hops with a vertical speed proportional to the speed
left (`bound_hop_ratio`), and repeats until slower than `bound_run_limit_m_s` (17), then runs out and
stops normally. The test lands from 48 m/s and checks for at least two impacts of decreasing speed, then a stop.
**Rough pass:** the animation reuses the landing and airborne poses, so the bracing is not yet a
dedicated pose (forelegs forward, wings flared during the hop).

## Climbing

Any solid surface can be climbed (characters excluded; a body can opt out with the `unclimbable`
group), including smooth walls and the mountain slopes, not only the mud huts. Each step now carries
body travel between pulls, so the climb is steadier and somewhat faster. Walking hands over to
climbing just above 45 degrees, and a climber lets go below 38.7 degrees, so the two never flicker.
**Not done:** a fully continuous slope posture (leaning into the slope as it steepens before the grip
starts), a long-arm reach that matches walking speed (faster settings broke the paw-reach and
drop-facing checks), and wall-walking with gravity re-aligned.

## HUD glass

HUD cards over 3D scenes are frosted glass: the scene behind is blurred and washed with a white tint
(`shaders/frosted_ui.gdshader`, `UiStyle.frost_*`). The map and splash keep solid white cards.
