extends CharacterBody3D
signal respawned

@export var walk_speed: float = 5.8
@export var sprint_speed: float = 18.0
@export var sprint_acceleration: float = 18.0
@export var acceleration: float = 26.0
@export var braking: float = 32.0
@export var jump_speed: float = 13.5
@export var gravity: float = 24.0
@export var falling_gravity: float = 36.0
@export var turn_speed: float = 2.5
@export var stick_camera_speed: float = 2.1
@export var mouse_sensitivity: float = 0.003

@onready var visual: Node3D = $Visual
@onready var pivot: Node3D = $CameraPivot
@onready var arm: SpringArm3D = $CameraPivot/SpringArm3D
var character_id := "clay"
var display_name := "Clay"
var player_controlled := true
var is_human := false
var can_fly := true
var can_climb := true
var can_breathe_fire := true
var default_camera_distance := 15.0
var conversation_locked := false
var spawn_position: Vector3
var locomotion_state: StringName = &"grounded"
var state_time: float = 0.0
var air_time: float = 0.0
var landing_strength: float = 1.0
var landing_duration: float = 0.22
var queued_flight: bool = false
var flight_mode: StringName = &"gliding"
var flight_pitch: float = 0.0
var flight_body_pitch: float = 0.0
var flight_bank: float = 0.0
var flight_turn_rate := 0.0 ## Signed yaw rate in flight (rad/s); positive turns left.
var flight_turn_effort := 0.0 ## 0..1: how hard the wings must work to turn or brake.
var flight_airbrake := 0.0 ## 0..1: speed being shed to make a tight turn.
var bounding := false ## True during a high-speed landing's brace-and-hop sequence.
var bound_count := 0
var ground_distance: float = 0.0
var takeoff_horizontal_speed: float = 0.0
var jump_settings: Dictionary
var flight_settings: Dictionary
var climb: RefCounted
var mud_supported := false
var mud_sink := 0.0
var mud_profile: Dictionary = {}
var mud_load := .55
var mud_speed_limit := 2.4


func _ready() -> void:
	spawn_position = position
	_setup_locomotion()
	# The mouse stays free until clicked; a gamepad works without capturing it.
	get_window().focus_exited.connect(_release_controls)


func _setup_locomotion() -> void:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/locomotion.json"))
	jump_settings = config.jump
	flight_settings = config.flight
	climb = preload("res://scripts/surface_climb.gd").new()
	climb.setup(self)
	# Walking (up to the default 45 degrees) hands over to climbing just beyond it, and a climber
	# lets go on a slope shallower than 38.7 degrees, so the two never flicker on one slope.
	floor_max_angle = deg_to_rad(45.0)
	arm.add_excluded_object(get_rid())


func set_player_controlled(controlled: bool) -> void:
	player_controlled = controlled
	if visual.motion:
		visual.motion.player_controlled = controlled
	if not controlled:
		if locomotion_state == &"climbing":
			climb.release()
		queued_flight = false
		_set_state(&"grounded" if _supported() else &"airborne")


func _physics_process(delta: float) -> void:
	_update_mud_contact(delta)
	if not player_controlled or conversation_locked:
		velocity.x = move_toward(velocity.x, 0.0, braking * delta)
		velocity.z = move_toward(velocity.z, 0.0, braking * delta)
		velocity.y -= gravity * delta
		_apply_mud_physics(delta)
		move_and_slide()
		if not player_controlled and _supported() and locomotion_state != &"grounded":
			_set_state(&"grounded")
			if visual.motion:
				visual.motion.resume_ground_motion()
		return
	state_time += delta
	if Input.is_action_just_pressed("release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if position.y < -20.0:
		reset_to_spawn()
	if Input.is_action_just_pressed("recenter"):
		pivot.rotation.y = visual.rotation.y
		pivot.rotation.x = 0.0 if locomotion_state == &"flying" else -0.4
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	_orbit(look * stick_camera_speed * delta)
	var stick := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	ground_distance = _distance_to_ground()
	if climb.update(delta, stick):
		return
	if Input.is_action_just_pressed("jump"):
		_request_jump()
	if Input.is_action_just_pressed("cancel_flight") and locomotion_state == &"flying":
		_set_state(&"airborne")
		air_time = 0.0
	var launched := false
	if locomotion_state == &"preparing":
		if not _supported():
			_set_state(&"airborne")
		elif state_time >= float(jump_settings.preparation_seconds) + float(jump_settings.push_seconds):
			velocity.x *= float(jump_settings.horizontal_speed_multiplier)
			velocity.z *= float(jump_settings.horizontal_speed_multiplier)
			takeoff_horizontal_speed = Vector2(velocity.x, velocity.z).length()
			velocity.y = jump_speed
			_set_state(&"airborne")
			launched = true
			air_time = 0.0
			if queued_flight:
				_activate_flight()
	elif locomotion_state == &"landing" and state_time >= landing_duration:
		var landing_speed := Vector2(velocity.x, velocity.z).length()
		if bounding and landing_speed > float(jump_settings.bound_run_limit_m_s):
			# Spring off the braced legs: a hop proportional to the speed still to lose.
			velocity.y = clampf(landing_speed * float(jump_settings.bound_hop_ratio), 4.0, 9.5)
			bound_count += 1
			_set_state(&"airborne")
			air_time = 0.0
		else:
			bounding = false
			_set_state(&"grounded")
			if visual.motion:
				visual.motion.resume_ground_motion()
	if not _supported() and locomotion_state == &"grounded":
		_set_state(&"airborne")
		air_time = 0.0
	if locomotion_state == &"flying":
		_fly(delta, stick)
	else:
		if locomotion_state == &"airborne":
			_air_move(delta, stick)
		else:
			_walk(delta, stick)
		if _supported() and locomotion_state != &"airborne":
			velocity.y = 0.0
		elif not launched:
			var acceleration_y := falling_gravity if velocity.y < 0.0 else gravity
			velocity.y -= acceleration_y * delta
	if locomotion_state == &"airborne" or locomotion_state == &"flying":
		air_time += delta
	floor_snap_length = 0.0 if locomotion_state == &"airborne" or locomotion_state == &"flying" else 0.45
	var incoming_vertical := velocity.y
	_apply_mud_physics(delta)
	move_and_slide()
	if can_climb and climb.try_attach(stick): return
	ground_distance = _distance_to_ground()
	if _supported() and (locomotion_state == &"airborne" or locomotion_state == &"flying"):
		landing_strength = clampf(absf(incoming_vertical) / jump_speed, 0.35, 1.0)
		landing_duration = float(jump_settings.moving_landing_seconds) if Vector2(velocity.x, velocity.z).length() > walk_speed * 0.4 else float(jump_settings.landing_seconds)
		var impact_speed := Vector2(velocity.x, velocity.z).length()
		if impact_speed > float(jump_settings.bound_speed_m_s):
			# Too fast to run out: brace on the legs, shed speed on impact and hop again.
			if not bounding:
				bound_count = 0
			bounding = true
			landing_strength = 1.6
			landing_duration = float(jump_settings.bound_brace_seconds)
			velocity.x *= float(jump_settings.bound_keep)
			velocity.z *= float(jump_settings.bound_keep)
		else:
			bounding = false
		_set_state(&"landing")
		queued_flight = false
		flight_mode = &"gliding"


func _walk(delta: float, stick: Vector2) -> void:
	var direction := Basis(Vector3.UP, pivot.rotation.y) * Vector3(stick.x, 0, stick.y)
	# A gallop's gathered suspension is authored by the gait rather than a
	# jump state. Carry its momentum until a paw can push or brake again.
	var gallop = visual.motion.gait.gallop if visual.motion and visual.motion.gait else null
	if locomotion_state == &"grounded" and gallop and gallop.active and gallop.blend > 0.99 and gallop.suspension:
		var horizontal := Vector3(velocity.x, 0.0, velocity.z)
		if direction.length_squared() > 0.001:
			horizontal = horizontal.move_toward(direction.normalized() * horizontal.length(), float(jump_settings.air_steering_m_s2) * delta)
			_turn_on_ground(direction, delta, 1.0)
		velocity.x = horizontal.x
		velocity.z = horizontal.z
		return
	var speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	if mud_supported:speed=minf(speed,mud_speed_limit)
	var support := 1.0
	if visual.motion and visual.motion.gait and locomotion_state == &"grounded":
		support = float(visual.motion.gait.turn_support)
	if locomotion_state == &"landing":
		speed *= 0.85
	if direction.length_squared() > 0.001:
		var facing := Vector3(-sin(visual.rotation.y), 0, -cos(visual.rotation.y))
		# Slow sharp turns while the feet make room; a quadruped cannot strafe
		# sideways at full walking speed with the old stance still planted.
		var alignment := facing.dot(direction.normalized())
		speed *= clampf((alignment + 0.1) / 1.1, 0.15, 1.0)
		speed *= support
		_turn_on_ground(direction, delta, support)
		# Travel follows the turning body. Sending velocity straight toward a new
		# stick direction makes the torso strafe across its planted running paws.
		direction = Vector3(-sin(visual.rotation.y), 0, -cos(visual.rotation.y)) * stick.length()
	var rate := acceleration if not stick.is_zero_approx() else braking
	if Input.is_action_pressed("sprint") and not stick.is_zero_approx():
		rate = sprint_acceleration
	if Vector2(velocity.x, velocity.z).length() > speed:
		rate = braking
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(direction * speed, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func _turn_on_ground(direction: Vector3, delta: float, support: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	var rate := lerpf(4.5, 2.0, smoothstep(2.9, 6.0, speed))
	rate = lerpf(rate, 1.2, smoothstep(6.0, sprint_speed, speed))
	var error := angle_difference(visual.rotation.y, atan2(-direction.x, -direction.z))
	var change := error * (1.0 - exp(-turn_speed * support * delta))
	visual.rotation.y += clampf(change, -rate * support * delta, rate * support * delta)


func _air_move(delta: float, stick: Vector2) -> void:
	# Takeoff momentum survives releasing the stick. Steering adds control
	# without applying the ground brake or erasing a running jump's speed.
	if stick.length_squared() < 0.001:
		return
	var direction := Basis(Vector3.UP, pivot.rotation.y) * Vector3(stick.x, 0, stick.y)
	var ground_speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	var speed := maxf(ground_speed, maxf(takeoff_horizontal_speed, Vector2(velocity.x, velocity.z).length()))
	var target := direction * speed
	var horizontal := Vector3(velocity.x, 0, velocity.z).move_toward(target, float(jump_settings.air_steering_m_s2) * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z), 1.0 - exp(-turn_speed * delta))


func _request_jump() -> void:
	if _supported() and (locomotion_state == &"grounded" or locomotion_state == &"landing"):
		_set_state(&"preparing")
		queued_flight = false
	elif locomotion_state == &"preparing":
		# Preserve responsive double taps while the short preparation plays.
		queued_flight = can_fly
	elif can_fly and not _supported() and locomotion_state != &"flying":
		_activate_flight()


func _activate_flight() -> void:
	if not can_fly: return
	if not _wings_clear(): return
	_set_state(&"flying")
	queued_flight = false
	flight_body_pitch = clampf(atan2(velocity.y, maxf(2.0, Vector2(velocity.x, velocity.z).length())), -0.7, 0.7)


func _wings_clear() -> bool:
	var half_span: float = climb.settings.wing_half_span_m
	var center := global_position + Vector3.UP * 3.2
	for sign_side in [-1.0, 1.0]:
		var hit: Dictionary = climb.ray(center, center + visual.global_basis.x * half_span * sign_side)
		if not hit.is_empty(): return false
	return true

func _fly(delta: float, stick: Vector2) -> void:
	if not _wings_clear():
		_set_state(&"airborne")
		velocity.y -= gravity * delta
		return
	if visual.motion and visual.motion.fold_amount > .35:
		# Deployment carries ballistic momentum, not invisible-wing lift.
		flight_mode = &"deploying"
		velocity.y -= gravity * delta
		_air_move(delta, stick)
		return
	flight_pitch = clampf(pivot.rotation.x, -deg_to_rad(float(flight_settings.max_pitch_degrees)), deg_to_rad(float(flight_settings.max_pitch_degrees)))
	if absf(flight_pitch) < deg_to_rad(float(flight_settings.horizon_deadzone_degrees)):
		flight_pitch = 0.0
	flight_mode = &"climbing" if flight_pitch > 0.0 else &"gliding"
	var desired_yaw := pivot.rotation.y
	if stick.length() > 0.15:
		desired_yaw += atan2(-stick.x, -stick.y)
	var heading_error := wrapf(desired_yaw - visual.rotation.y, -PI, PI)
	var boosting := Input.is_action_pressed("sprint")
	var speed: float = flight_settings.boost_speed_m_s if boosting else flight_settings.speed_m_s
	var max_climb: float = flight_settings.boost_max_climb_m_s if boosting else flight_settings.max_climb_m_s
	var max_descent: float = flight_settings.boost_max_descent_m_s if boosting else flight_settings.max_descent_m_s
	# Turning is limited by a lateral-acceleration budget (lift), so the faster the dragon flies the
	# wider its turn. The body follows its heading; it never slides sideways or flies backwards.
	var turn_cap := float(flight_settings.max_turn_rate_rad_s)
	var lateral := float(flight_settings.lateral_accel_m_s2)
	var current_speed := Vector2(velocity.x, velocity.z).length()
	var wanted_rate := clampf(heading_error * float(flight_settings.turn_response), -turn_cap, turn_cap)
	var allowed_rate := minf(turn_cap, lateral / maxf(current_speed, 8.0))
	flight_turn_rate = move_toward(flight_turn_rate, clampf(wanted_rate, -allowed_rate, allowed_rate), float(flight_settings.turn_accel_rad_s2) * delta)
	visual.rotation.y = wrapf(visual.rotation.y + flight_turn_rate * delta, -PI, PI)
	var forward := Vector3(-sin(visual.rotation.y), 0, -cos(visual.rotation.y))
	var cruise := speed * cos(flight_pitch)
	var target_speed := cruise
	var braking_turn := 0.0
	if absf(wanted_rate) > allowed_rate + 0.05:
		# A tighter turn than this speed allows is flown by shedding speed with flared wings.
		var needed := lateral / maxf(absf(wanted_rate), 0.1)
		target_speed = minf(cruise, maxf(needed, float(flight_settings.min_turn_speed_m_s)))
		braking_turn = clampf((current_speed - target_speed) / maxf(current_speed, 1.0) * 3.0, 0.0, 1.0)
	var rate: float = flight_settings.boost_acceleration_m_s2 if boosting else flight_settings.acceleration_m_s2
	if current_speed > target_speed:
		# Releasing Shift carries momentum and eases back to cruise; a hard turn brakes much harder.
		rate = float(flight_settings.turn_brake_m_s2) if braking_turn > 0.0 else float(flight_settings.deceleration_m_s2)
	var new_speed := move_toward(current_speed, target_speed, rate * delta)
	# Aerodynamic sideslip damping: velocity swings onto the heading within a fraction of a second.
	var along := Vector2(forward.x, forward.z) * new_speed
	var slipped := Vector2(velocity.x, velocity.z).lerp(along, 1.0 - exp(-float(flight_settings.align_rate) * delta))
	if slipped.length() > 0.01:
		slipped = slipped.normalized() * new_speed
	velocity.x = slipped.x
	velocity.z = slipped.y
	var target_y := clampf(speed * sin(flight_pitch), -max_descent, max_climb)
	var vertical_rate: float = flight_settings.boost_vertical_acceleration_m_s2 if boosting else flight_settings.vertical_acceleration_m_s2
	velocity.y = move_toward(velocity.y, target_y, vertical_rate * delta)
	flight_body_pitch = clampf(atan2(velocity.y, maxf(1.0, Vector2(velocity.x, velocity.z).length())), -0.7, 0.7)
	# The body rolls into the turn (up to about 55 degrees) and the wings react to the effort.
	flight_bank = clampf(-flight_turn_rate * 0.42, -0.95, 0.95)
	flight_airbrake = move_toward(flight_airbrake, braking_turn, delta * 4.0)
	var demand := absf(flight_turn_rate) / turn_cap if absf(flight_turn_rate) > 0.25 else 0.0
	flight_turn_effort = move_toward(flight_turn_effort, maxf(demand, flight_airbrake), delta * 5.0)


func _set_state(next: StringName) -> void:
	if next == &"airborne":
		takeoff_horizontal_speed = Vector2(velocity.x, velocity.z).length()
	if next != &"flying":
		flight_turn_rate = 0.0
		flight_turn_effort = 0.0
		flight_airbrake = 0.0
	if next == &"flying":
		bounding = false
	locomotion_state = next
	state_time = 0.0


func _distance_to_ground() -> float:
	if mud_supported:return 0.0
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.2, global_position + Vector3.DOWN * 1000.0, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return maxf(0.0, global_position.y - float(hit.position.y)) if not hit.is_empty() else 1000.0


func _unhandled_input(event: InputEvent) -> void:
	if not player_controlled or conversation_locked:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			arm.spring_length = maxf(default_camera_distance * 0.35, arm.spring_length - (0.3 if is_human else 1.0))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			arm.spring_length = minf(default_camera_distance * 2.0, arm.spring_length + (0.3 if is_human else 1.0))
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_orbit(event.relative * mouse_sensitivity)


func _orbit(amount: Vector2) -> void:
	pivot.rotation.y -= amount.x
	var look_up_limit := deg_to_rad(float(flight_settings.max_pitch_degrees)) if locomotion_state == &"flying" else 0.75
	pivot.rotation.x = clampf(pivot.rotation.x - amount.y, -1.05, look_up_limit)


func reset_to_spawn() -> void:
	if climb and locomotion_state == &"climbing": climb.release()
	mud_supported=false;mud_sink=0;mud_profile.clear()
	position = spawn_position
	velocity = Vector3.ZERO
	locomotion_state = &"grounded"
	state_time = 0.0
	air_time = 0.0
	takeoff_horizontal_speed = 0.0
	queued_flight = false
	flight_body_pitch = 0.0
	flight_bank = 0.0
	flight_mode = &"gliding"
	visual.rotation = Vector3.ZERO
	pivot.rotation = Vector3(-0.4, 0, 0)
	if visual.motion:
		visual.motion.reset_motion()
	respawned.emit()


func _release_controls() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for action in InputMap.get_actions():
		Input.action_release(action)


func _supported() -> bool:
	return is_on_floor() or mud_supported

func _update_mud_contact(delta: float) -> void:
	mud_profile.clear();mud_supported=false
	var habitat:=get_parent()
	if not habitat or not habitat.has_method("sample_soft_mud"):return
	mud_profile=habitat.sample_soft_mud(global_position)
	if mud_profile.is_empty() or locomotion_state==&"flying" or velocity.y>2:
		mud_sink=move_toward(mud_sink,0,delta*.35);return
	var surface: float=mud_profile.surface_y
	mud_supported=position.y<=surface+.16 and position.y>surface-float(mud_profile.max_depth)-.20
	var load: float=mud_load*float(mud_profile.softness)
	if mud_profile.wallow:load*=1.25
	mud_sink=move_toward(mud_sink,minf(load,float(mud_profile.max_depth)*.88) if mud_supported else 0.0,delta*.16)

func _apply_mud_physics(delta: float) -> void:
	if not mud_supported or velocity.y>2:return
	floor_snap_length=0
	var target: float=float(mud_profile.surface_y)-mud_sink
	velocity.y=clampf((target-position.y)*5,-.25,.55)
	var horizontal:=Vector2(velocity.x,velocity.z)
	if horizontal.length()>mud_speed_limit:
		horizontal=horizontal.move_toward(horizontal.normalized()*mud_speed_limit,delta*12)
	horizontal*=exp(-delta*.6*float(mud_profile.softness))
	velocity.x=horizontal.x;velocity.z=horizontal.y
