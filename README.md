# Wings of Fire game

A personal 3D Wings of Fire project in Godot. World planning and an early playable
Clay movement prototype.

- [World plan: Pyrrhia](docs/world-plan.md)
- [Overworld map and scene destinations](docs/overworld-map.md)
- [Playable bare terrain: both continents and islands](docs/bare-terrain.md)
- [Clay prototype (work in progress)](prototypes/clay/README.md)
- [Godot movement playground: setup, model build and controls](game/README.md)
- [Jade Mountain Academy (Arc 2)](docs/jade-mountain.md)
- [Sky Kingdom palace and Scorpion Den (rough blockouts)](docs/sites.md)
- [Web export and Vercel deployment](docs/web-deployment.md)

Open `game/project.godot` in Godot 4.5+ and press **F5**. Move with WASD or a
controller's left stick; orbit with the mouse or right stick. Build Clay locally
using the game setup instructions, or try the controls with the placeholder.

F5 opens one world map showing Pyrrhia, Pantala, the Forgotten Isles and NightWing
Island together. Drag to move, scroll or pinch to zoom, and click a pin to travel
there: every kingdom, island and shore start is pinned, and **Jump to a place**
lists them all. Terrain is bare, with colored biomes, mountains, hills and water.
Pyrrhia spans 320 × 237 km, with all four maps expanded tenfold and terrain
streamed around the player.
Pick an era on the timeline along the bottom: **Jade Mountain Academy** opens in Arc 2, while the
**Sky Kingdom palace** and **Scorpion Den** change between Arc 1 and Arc 2.
Select **MudWing village** on Pyrrhia to enter the detailed wetlands;
press **M / controller Start** or click **World map** to return to the map.

In the village, approach Umber and press **X** (Xbox **X** / PlayStation **Square**)
to play as him. Once he joins your collection, **Tab** or **D-pad left** switches
between the dragons you’ve unlocked.

Orbit to examine camera-guided head/neck tracking and its front-stage neutral
return. Jump with Space/A, then press again in the air to fly. Aim upward for
climbing flaps or level/downward for glide; C/right-stick click levels flight.

Hold **V** or **R1 / right bumper** to open his mouth and breathe a sustained jet of fire.
