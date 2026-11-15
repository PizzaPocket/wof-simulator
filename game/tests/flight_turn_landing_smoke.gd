extends SceneTree
## A fast dragon cannot turn instantly or travel backwards or sideways: a reversal is flown by
## shedding speed and banking while the wings work harder, and a very fast landing braces, hops and
## sheds speed in stages before it runs out.
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)

func ticks(count: int) -> void:
	for i in count:
		await physics_frame

func _run() -> void:
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8000, 2, 8000)
	shape.shape = box
	ground.add_child(shape)
	ground.position.y = -1
	root.add_child(ground)
	var player: CharacterBody3D = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	player.position = Vector3(0, 150, 0)
	await ticks(5)
	var flight: Dictionary = player.flight_settings
	var cruise: float = float(flight.speed_m_s)

	# --- A reversal at cruise speed ---
	player.pivot.rotation = Vector3.ZERO # level flight: no pitch
	player.visual.rotation.y = 0.0
	player.velocity = Vector3(0, 0, -cruise)
	player._set_state(&"flying")
	Input.action_press("move_forward")
	await ticks(40)
	var effort_peak := 0.0
	var wing_peak := 0.0
	var min_alignment := 1.0
	var min_speed := INF
	player.pivot.rotation = Vector3(0, PI, 0) # the player now wants to fly the other way
	var turned_at := -1
	for i in 420:
		await physics_frame
		var v := Vector2(player.velocity.x, player.velocity.z)
		var forward := Vector2(-sin(player.visual.rotation.y), -cos(player.visual.rotation.y))
		if i > 6 and v.length() > 3.0:
			min_alignment = minf(min_alignment, v.normalized().dot(forward))
		min_speed = minf(min_speed, v.length())
		effort_peak = maxf(effort_peak, player.flight_turn_effort)
		if player.visual.motion and player.visual.motion.get("flight") != null:
			wing_peak = maxf(wing_peak, player.visual.motion.flight.turn_effort)
		if turned_at < 0 and absf(wrapf(player.visual.rotation.y - PI, -PI, PI)) < 0.15:
			turned_at = i
	check(min_alignment > 0.55, "Velocity must follow the heading, never backwards or sideways (worst alignment %.2f)" % min_alignment)
	check(min_speed < cruise * 0.5, "A reversal must shed speed (slowest %.1f of %.0f m/s)" % [min_speed, cruise])
	check(min_speed > 8.0, "A reversal is a turn, not a stop (slowest %.1f m/s)" % min_speed)
	check(effort_peak > 0.7, "A hard turn must call for hard flapping (peak effort %.2f)" % effort_peak)
	check(player.flight_bank != 0.0 or turned_at > 0, "The body should have banked into the turn")
	check(turned_at > 0 and turned_at < 300, "The turn should complete in a few seconds (frame %d)" % turned_at)
	await ticks(200)
	var recovered := Vector2(player.velocity.x, player.velocity.z).length()
	check(recovered > cruise * 0.85, "Cruise speed returns after the turn (%.1f m/s)" % recovered)
	print("turn: worst alignment %.2f, slowest %.1f m/s, effort %.2f, wing effort %.2f, complete at frame %d" % [min_alignment, min_speed, effort_peak, wing_peak, turned_at])
	Input.action_release("move_forward")

	# --- A very fast landing ---
	player.position = Vector3(0, 10, 0)
	player.pivot.rotation.y = 0.0
	player.visual.rotation.y = 0.0
	player.velocity = Vector3(0, -4, -48)
	player._set_state(&"airborne")
	player.bounding = false
	player.bound_count = 0
	var landings := 0
	var previous: StringName = player.locomotion_state
	var start_z := player.position.z
	var lowest := 0.0
	var impact_speeds: Array[float] = []
	for i in 900:
		await physics_frame
		lowest = minf(lowest, player.position.y)
		if player.locomotion_state == &"landing" and previous != &"landing":
			landings += 1
			impact_speeds.append(Vector2(player.velocity.x, player.velocity.z).length())
		previous = player.locomotion_state
	var final_speed := Vector2(player.velocity.x, player.velocity.z).length()
	check(landings >= 2, "A very fast landing must brace and hop more than once (%d impacts)" % landings)
	var decreasing := true
	for i in range(1, impact_speeds.size()):
		decreasing = decreasing and impact_speeds[i] < impact_speeds[i - 1]
	check(decreasing, "Each impact must be slower than the last (%s)" % str(impact_speeds))
	check(final_speed < 1.0 and player.locomotion_state == &"grounded", "The dragon runs out to a stop (%s, %.1f m/s)" % [str(player.locomotion_state), final_speed])
	check(absf(player.position.z - start_z) > 20.0, "The landing carries it forward")
	check(lowest > -1.0, "It never sinks through the ground")
	print("landing: %d impacts at %s m/s, stopped %.0f m on" % [landings, str(impact_speeds), absf(player.position.z - start_z)])
	if failures.is_empty():
		print("PASS: sharp turns shed speed and bank with harder flapping; fast landings brace, hop and slow to a run")
	quit(0 if failures.is_empty() else 1)
