extends Node3D
## Exposes the same visual contract as a dragon, with an independently animated biped.
var motion: Node = null
var human: Node3D
var model_loaded := false

func _ready() -> void:
	human = preload("res://scripts/scavenger_visual.gd").new()
	human.character_id = get_parent().character_id
	human.child_age = 15
	add_child(human)
	model_loaded = human.model_loaded
	process_physics_priority = 10

func _physics_process(delta: float) -> void:
	var body = get_parent()
	if not body.player_controlled and body.locomotion_state == &"grounded":
		return
	var speed: float = Vector2(body.velocity.x, body.velocity.z).length()
	var airborne: bool = body.locomotion_state == &"airborne"
	human.animate(delta, 0.0 if airborne else speed, "walking", false, null)
	if not human.model_loaded:
		return
	if airborne:
		for side in ["L", "R"]:
			human._turn("upperleg01." + side, Vector3.RIGHT, -0.25)
			human._turn("lowerleg01." + side, Vector3.RIGHT, 0.42)
			human._turn("upperarm01." + side, Vector3.BACK, 0.25 if side == "L" else -0.25)

