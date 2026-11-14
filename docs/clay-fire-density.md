# Fire density pass — unified plume reviewed

The user wants a connected roaring jet instead of a sparse cloud of identifiable
particles. The first draft added a world-space sampled mesh core under particles;
rendered review and user feedback found two distinct effects. That draft is
removed from the active game and preserved only in ignored
`cache/fire-density-review/` for diagnosis.

The active effect is again one GPUParticles3D plume. It uses 800 particles,
a narrower 4.5-degree spread, less timing randomness and velocity variation,
shorter overlapping cards, reduced per-particle opacity and a tapered lifetime
scale. Aim, mouth opening and the posterior-mouth source are unchanged.
These runtime changes are shared by the default wetlands QA scene; no model
export is needed. Restart an already running QA session to load the scripts.

The headless fire behavior smoke test passes ignition timing, held/released
emission, world-space motion, gaze tracking, jaw hinge continuity and reset.
The single-plume appearance was rendered and inspected in the default wetlands
scene on October 31 after rendering access became available. The connected hot
center and billowing end now come from one particle system, with no mesh beam.
Current reviewed frames are `cache/fire-density-review/unified-motion-*.png`;
`unified-motion-040.png` shows the sustained plume. The older `after-*.png`
files still show the rejected two-layer draft and are not the current effect.

The review harness now maintains the held input across physics frames, so
window focus changes cannot silently stop emission during a capture.
