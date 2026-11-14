extends SceneTree
## Playable review window using the latest imported Clay asset and normal controls.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: Node3D = load("res://scenes/playground.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	DisplayServer.window_set_title("Clay — revised mouth and ear contour")
	var player: CharacterBody3D = scene.get_node("Clay")
	player.spawn_position = Vector3(0,0.1,30)
	player.reset_to_spawn()
	player.pivot.rotation = Vector3(-0.12, PI*0.75,0)
	player.arm.spring_length = 6.5
	player.get_node("CameraPivot/SpringArm3D/Camera3D").fov = 50.0
