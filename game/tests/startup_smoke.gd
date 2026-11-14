extends SceneTree
## Exercise the real boot path and verify progress is monotonic until handoff.
var boot: Control
var last_progress := 0.0
var phases: Dictionary = {}
var frames := 0
var captured := false
var fullscreen_check := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	fullscreen_check = "--fullscreen-check" in OS.get_cmdline_user_args()
	var test_retry := "--failure-retry" in OS.get_cmdline_user_args()
	boot = load("res://scenes/startup.tscn").instantiate()
	var original_path: String = boot.load_jobs[0][0]
	if test_retry:
		boot.load_jobs[0][0] = "res://missing-model-for-loader-test.glb"
	root.add_child(boot)
	current_scene = boot
	if test_retry:
		while not boot.failed:
			await process_frame
		if not boot.retry.visible or current_scene != boot:
			printerr("Failed load did not show recovery UI")
			quit(1)
			return
		if DisplayServer.get_name() != "headless":
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../cache/overworld-review"))
			for dimensions in [Vector2i(1280, 800), Vector2i(800, 500)]:
				root.size = dimensions
				await process_frame
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../cache/overworld-review/failure-%d.png" % dimensions.x))
			root.size = Vector2i(1280, 800)
		boot.load_jobs[0][0] = original_path
		boot.retry.pressed.emit()
		await process_frame
		await process_frame
		boot = current_scene
		print("PASS: missing model displayed recovery UI and Retry restarted loading")
	var deadline := Time.get_ticks_msec() + 120000
	while is_instance_valid(boot):
		if boot.failed:
			printerr("Startup failed: ", boot.status.text)
			quit(1)
			return
		if boot.bar.value < last_progress:
			printerr("Loading progress regressed")
			quit(1)
			return
		last_progress = boot.bar.value
		phases[boot.status.text] = true
		if Time.get_ticks_msec() > deadline:
			printerr("Startup timed out at ", boot.status.text)
			quit(1)
			return
		if not captured and last_progress > 46 and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../cache/startup-preview.png"))
			if not fullscreen_check:
				root.size = Vector2i(800, 500)
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../cache/startup-small.png"))
				root.size = Vector2i(1280, 800)
			captured = true
		frames += 1
		await process_frame
	if not current_scene or current_scene.name != "MudwingWetlands" or last_progress != 100:
		printerr("Startup did not hand off at 100%")
		quit(1)
		return
	if not current_scene.get_node("Clay/Visual").model_loaded:
		printerr("Startup shipped placeholder Clay")
		quit(1)
		return
	if phases.size() < 10:
		printerr("Expected detailed world loading progress")
		quit(1)
		return
	if fullscreen_check:
		if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
			printerr("Expected native fullscreen at gameplay handoff")
			quit(1)
			return
		print("PASS: fullscreen gameplay; window ", DisplayServer.window_get_size(), " on screen ", DisplayServer.screen_get_size())
	print("PASS: startup reached 100%, handed off to wetlands; ", phases.size(), " observed phase labels across ", frames, " frames")
	quit()
