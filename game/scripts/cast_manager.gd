extends RefCounted
## Places the point-of-view characters where their story puts them (data/cast.json, by scene and
## era) and makes sure every scene can switch characters: walk up to one and press X to unlock
## and play them, Tab to cycle the saved collection. Safe on a scene that already has a roster.
const CAST_PATH := "res://data/cast.json"
const SPREAD := 10.0


static func base_id(id: String) -> String:
	return id.trim_suffix("_blind")


static func current_era() -> String:
	return str(Engine.get_meta("map_era")) if Engine.has_meta("map_era") else "arc1"


## The profile id a character uses in an era (Starflight is blind from Arc 2).
static func variant_for(id: String, era: String) -> String:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CAST_PATH))
	var variants: Dictionary = data.era_variants.get(id, {})
	return str(variants.get(era, id))


## Where the collection is saved: shared by every scene. Tests point this at a temporary file.
static func save_path() -> String:
	return str(Engine.get_meta("roster_save_path")) if Engine.has_meta("roster_save_path") else "user://protagonists.cfg"


## Returns the scene's roster, creating it (with the player registered) when there is none yet.
static func ensure_roster(world: Node3D) -> Node:
	var roster = world.get_node_or_null("Protagonists")
	if roster != null:
		return roster
	roster = preload("res://scripts/protagonist_roster.gd").new()
	roster.name = "Protagonists"
	roster.save_path = save_path()
	roster.player = world.player
	roster.register(world.player)
	world.add_child(roster)
	# Keep the scene's own `player` reference on whoever is being played.
	roster.switched.connect(func(_previous, current): world.player = current)
	return roster


## Installs the roster and this scene's characters for the current era. Options:
##   scene_id   key into data/cast.json "presence"
##   origin     Vector3 arrival point (default: the player's position)
##   offset     Vector3 from the origin to the middle of the waiting group (default 16 m ahead)
##   ground     Callable(Vector3) -> float, the standing height at a point (default: origin y)
##   chambers   Dictionary of chamber id -> Vector3 for characters placed in a named room
## Returns the actors it created.
static func install(world: Node3D, options: Dictionary = {}) -> Array[CharacterBody3D]:
	var era := current_era()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CAST_PATH))
	var player: CharacterBody3D = world.player
	var roster = ensure_roster(world)
	var entries: Array = data.presence.get(str(options.get("scene_id", "")), {}).get(era, [])
	var present := {}
	for id in roster.protagonists:
		present[base_id(str(id))] = true
	var waiting: Array[Dictionary] = []
	for entry in entries:
		if not present.has(str(entry.id)):
			waiting.append(entry)
	var origin: Vector3 = options.get("origin", player.position)
	var offset: Vector3 = options.get("offset", Vector3(0, 0, -16))
	var chambers: Dictionary = options.get("chambers", {})
	var ground: Callable = options.get("ground", Callable())
	var group := 0
	for entry in waiting:
		if not entry.has("chamber"):
			group += 1
	var created: Array[CharacterBody3D] = []
	var slot := 0
	var in_room := {}
	for entry in waiting:
		var at: Vector3
		if entry.has("chamber") and chambers.has(entry.chamber):
			var room: String = entry.chamber
			at = chambers[room] + Vector3(6.0 + 5.0 * int(in_room.get(room, 0)), 0, 0)
			in_room[room] = int(in_room.get(room, 0)) + 1
		else:
			at = origin + offset + Vector3((slot - (group - 1) * 0.5) * SPREAD, 0, 0)
			slot += 1
			at.y = float(ground.call(at)) if ground.is_valid() else origin.y + 0.1
		var actor := make_actor(world, variant_for(str(entry.id), era), at, roster)
		created.append(actor)
	return created


## A playable character standing at `at`, registered with the roster.
static func make_actor(world: Node3D, id: String, at: Vector3, roster: Node) -> CharacterBody3D:
	var actor := preload("res://scripts/protagonist_factory.gd").make_actor(id)
	actor.playable = true # variants such as the blind Starflight are playable too
	actor.listener = world.player
	actor.activity = "waiting"
	actor.position = at
	world.add_child(actor)
	roster.register(actor)
	var conversations = world.get_node_or_null("Conversations")
	if conversations:
		conversations.villagers.append(actor)
	return actor
