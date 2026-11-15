extends SceneTree
var failures: Array[String] = []
var respawns := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); printerr("FAIL: ", message)
func ticks(count: int) -> void:
	for i in count: await physics_frame
func tap(action: StringName) -> void:
	Input.action_press(action); await ticks(2); Input.action_release(action); await ticks(2)

func run() -> void:
	var world = load("res://scenes/mudwing_wetlands.tscn").instantiate()
	world.roster_save_path = ""
	world.install_cast = false # these tests cover the older meet-to-unlock behaviour
	root.add_child(world)
	await ticks(10)
	var clay = world.get_node("Clay")
	var roster = world.get_node("Protagonists")
	check(roster.protagonists.size() == 5, "Clay, Umber, Moon, Blue and Wren are collectible")
	check(world.has_node("Darkstalker") and not roster.protagonists.has("darkstalker"), "Darkstalker is visible in the village and remains outside the collectible roster")
	check(not roster.protagonists.has("kai") and not roster.protagonists.has("leaf") and not roster.protagonists.has("ivy"),
		"Only the requested POV human is collectible")
	check(world.has_node("RegionBoundary"), "The region has an invisible collision wall")
	clay.respawned.connect(func(): respawns += 1)
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	for i in 20:
		var angle := TAU * i / 20
		var out := Vector3(cos(angle), 0, sin(angle))
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0, 40, 0), Vector3(0, 40, 0) + out * 320, 1, [clay.get_rid()]))
		check(not hit.is_empty() and hit.collider.name == "RegionBoundary", "Boundary ring is closed at angle %d" % i)
	var radius: float = world._region_radius(0) - 5
	clay.position = Vector3(radius - 5, 45, 0)
	clay.velocity = Vector3(100, 0, 0)
	clay._set_state(&"airborne")
	await ticks(12)
	var actual_radius: float = world._region_radius(atan2(clay.position.z, clay.position.x)) - 5.0
	check(clay.position.x > radius - 8 and Vector2(clay.position.x, clay.position.z).length() < actual_radius + 0.05 and respawns == 0,
		"Flying into the boundary stops Clay without teleporting (position %s)" % clay.position)
	clay.position = Vector3(0, 177.5, 0)
	clay.velocity = Vector3(0, 45, 0)
	clay._set_state(&"airborne")
	await ticks(12)
	check(clay.position.y < 179 and clay.velocity.y <= 0 and respawns == 0, "The altitude ceiling blocks ascent without resetting")
	var wren = world.get_node("Wren")
	clay.position = wren.position + Vector3(0, 0.1, 3)
	clay.velocity = Vector3.ZERO
	clay._set_state(&"grounded")
	await ticks(10)
	await tap(&"possess_protagonist")
	check(world.player == wren and wren.human.model_loaded, "X possesses Wren's actual human body")
	check(wren.is_human and not wren.can_fly and not wren.can_climb and not wren.can_breathe_fire, "Wren has human capabilities")
	check(roster.camera.get_parent() == wren.arm and wren.arm.spring_length < 6, "Wren gets a human-scale follow camera")
	wren.visual.rotation.y = 0; wren.pivot.rotation.y = 0
	var start: Vector3 = wren.position
	Input.action_press("move_forward")
	await ticks(30)
	Input.action_release("move_forward")
	check(wren.position.z < start.z - 0.5 and wren.human.walk_blend > 0.8, "Wren walks with an animated biped gait")
	await tap(&"jump")
	await ticks(18)
	check(wren.locomotion_state == &"airborne" and wren.velocity.y > 0, "Wren can jump")
	await tap(&"jump")
	check(wren.locomotion_state != &"flying", "A second jump cannot make Wren fly")
	for id in ["moon", "blue"]:
		var actor = roster.protagonists[id]
		roster._switch(actor)
		actor.position = Vector3(0 if id == "moon" else 30, 25, 0)
		actor.velocity = Vector3.ZERO
		actor._set_state(&"airborne")
		await ticks(2)
		await tap(&"jump")
		check(world.player == actor and actor.locomotion_state == &"flying", id + " is playable and can fly (state %s, clear %s)" % [actor.locomotion_state, actor._wings_clear()])
		check(actor.visual.get_script() == preload("res://scripts/tribe_dragon_visual.gd"), id + " loads an independent tribe model")
		if id == "blue":
			check(actor.visual.motion.skeleton.find_bone("wing_hind.L") >= 0 and actor.visual.motion.skeleton.find_bone("wing_hind.R") >= 0, "Blue has four independently constructed wings")
		else:
			check(actor.visual.motion.skeleton.find_children("SilverTearScale*", "MeshInstance3D", true, false).size() == 2,
				id + " has two silver tear scales")
	world.queue_free()
	await process_frame
	var review = load("res://scenes/character_review.tscn").instantiate()
	root.add_child(review)
	for id in review.IDS:
		review.select_character(id)
		await ticks(2)
		check(review.player.character_id == id and review.inspecting, "Review room selects " + id)
	review.inspecting = false
	review._set_mode()
	check(review.player.is_physics_processing() and not review.player.conversation_locked, "Review Play mode enables real movement")
	print("New cast and boundary smoke: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
