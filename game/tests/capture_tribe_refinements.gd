extends "res://tests/moon_game_pass.gd"
## Quick anatomical review cameras in the real village, without replaying the
## full locomotion suite before each close-up. Does not write collection saves.
func run() -> void:
	output="res://../cache/tribe-refinements"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(1400,900)
	world=load("res://scenes/mudwing_wetlands.tscn").instantiate()
	world.roster_save_path=""
	root.add_child(world)
	await ticks(4)
	var roster=world.get_node("Protagonists")
	camera=roster.camera
	camera.reparent(world)
	camera.make_current()
	var play_only:bool="--play-blue" in OS.get_cmdline_user_args()
	var mouth_only:bool="--mouth-only" in OS.get_cmdline_user_args()
	for character in ([] if play_only else ["Moon","Blue"]):
		moon=world.get_node(character)
		moon.set_physics_process(false)
		var motion=moon.visual.motion
		motion.enabled=false
		motion.reset_motion()
		framing_scale=moon.visual.model_scale/1.1
		frame_actor(Vector3(10,3.5,.4),Vector3(0,1.7,-.5),44)
		await capture(character.to_lower()+"-side")
		if not mouth_only:
			frame_actor(Vector3(2.2,2.35,-3.25),Vector3(0,1.95,-1.75),38)
			await capture(character.to_lower()+"-head")
			frame_actor(Vector3(0,4.8,-1.8),Vector3(0,2,-1.75),35)
			await capture(character.to_lower()+"-top")
			frame_actor(Vector3(0,2.25,-4.9),Vector3(0,2.05,-1.75),34)
			await capture(character.to_lower()+"-front")
		motion.fire.jaw_angle=.58
		motion.fire._apply_mouth()
		frame_actor(Vector3(2.2,2.35,-3.25),Vector3(0,1.95,-1.75),38)
		await capture(character.to_lower()+"-mouth")
		motion.reset_motion()
		if not mouth_only:
			motion.fold_amount=0.
			motion.apply_wings()
			frame_actor(Vector3(7.5,5,-8),Vector3(0,1.4,0),55)
			await capture(character.to_lower()+"-spread")
			if character=="Blue":
				frame_actor(Vector3(0,11,-1),Vector3(0,1.4,0),55)
				await capture("blue-spread-top")
				var state=moon.locomotion_state
				var clearance=moon.ground_distance
				moon.locomotion_state=&"flying"
				moon.state_time=3.
				moon.ground_distance=10.
				for phase in [0.,.42]:
					motion.skeleton.reset_bone_poses()
					motion.fold_amount=0.
					motion.apply_wings()
					motion.flight.was_flying=true
					motion.flight.phase=phase
					motion.flight.flap_blend=1.
					motion.flight.update(0.)
					motion.flight.apply_stroke(1.,motion.gait)
					frame_actor(Vector3(7.5,5,-8),Vector3(0,1.4,0),55)
					await capture("blue-upstroke" if phase==0. else "blue-downstroke")
				moon.locomotion_state=state
				moon.ground_distance=clearance
				motion.reset_motion()
	if play_only or "--keep-playing" in OS.get_cmdline_user_args():
		moon=world.get_node("Blue")
		for character in [world.get_node("Moon"),moon]:
			character.set_physics_process(true)
			character.visual.motion.reset_motion()
			character.visual.motion.enabled=true
		roster._switch(moon)
		moon.pivot.rotation=Vector3(-.22,-1.05,0)
		moon.arm.spring_length=moon.default_camera_distance
		camera.position=Vector3.BACK*moon.default_camera_distance
		camera.rotation=Vector3.ZERO
		camera.fov=75
		print("Village ready: updated Blue controlled; collection save untouched.")
		return
	print("Captured fresh anatomy views in the actual village")
	quit()
