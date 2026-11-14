# Wings of Fire game

A personal 3D Wings of Fire project in Godot. World planning and an early playable
Clay movement prototype.

- [World plan: Pyrrhia](docs/world-plan.md)
- [Overworld map and scene destinations](docs/overworld-map.md)
- [Playable bare terrain: both continents and islands](docs/bare-terrain.md)
- [Clay prototype (work in progress)](prototypes/clay/README.md)
- [Godot movement playground: setup, model build and controls](game/README.md)
- [Web export and Vercel deployment](docs/web-deployment.md)

Open `game/project.godot` in Godot 4.5+ and press **F5**. Move with WASD or a
controller's left stick; orbit with the mouse or right stick. Build Clay locally
using the game setup instructions, or try the controls with the placeholder.

F5 opens the world atlas. Choose a continent/island tab and its exploration marker
to walk or fly across bare terrain, with colored biomes, mountains, hills and water.
Pyrrhia now spans 320 × 237 km, with all four maps expanded tenfold and terrain
streamed around the player.
The terrain selector offers starting points across each map.
Select **MudWing village** on Pyrrhia to enter the detailed wetlands;
press **M / controller Start** or click **World map** to return to the atlas.

In the village, approach Umber and press **X** (Xbox **X** / PlayStation **Square**)
to play as him. Once he joins your collection, **Tab** or **D-pad left** switches
between the dragons you’ve unlocked.

Orbit to examine camera-guided head/neck tracking and its front-stage neutral
return. Jump with Space/A, then press again in the air to fly. Aim upward for
climbing flaps or level/downward for glide; C/right-stick click levels flight.

Hold **V** or **R1 / right bumper** to open his mouth and breathe a sustained jet of fire.
