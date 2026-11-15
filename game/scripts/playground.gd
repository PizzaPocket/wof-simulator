extends Node3D
## Small, disposable test space. Replace this scene when the world is ready.

@onready var player: CharacterBody3D = $Clay
var hud: CanvasLayer
var help_panel: PanelContainer
var help_toggle: Button
var credits_panel: PanelContainer


func _ready() -> void:
	_make_environment()
	_box("Ground", Vector3(500, 1, 500), Vector3(0, -0.5, 0), Color("7b8a65"))
	# Low boundary walls and a few obstacles exercise collision and the spring arm.
	for side in [-1, 1]:
		_box("BoundaryX", Vector3(1, 3, 120), Vector3(side * 60, 1.5, 0), Color("61735e"))
		_box("BoundaryZ", Vector3(120, 3, 1), Vector3(0, 1.5, side * 60), Color("61735e"))
	for i in range(5):
		_box("JumpBlock", Vector3(3, 0.4 + i * 0.3, 3), Vector3(-12 + i * 6, 0.2 + i * 0.15, -10), Color("ae9270"))
	var ramp := _box("Slope", Vector3(8, 0.5, 14), Vector3(18, 1.65, -1), Color("b29d7d"))
	ramp.rotation.x = deg_to_rad(-14)
	_box("RampPlatform", Vector3(8, 3.1, 6), Vector3(18, 1.55, -10), Color("ae9270"))
	for x in [-26, 26]:
		for z in [-26, 26]:
			_box("Landmark", Vector3(2, 8, 2), Vector3(x, 4, z), Color("566c69"))
	# Flat non-colliding strips make speed and direction easy to judge.
	for i in range(-5, 6):
		_stripe(Vector3(i * 10, 0.008, 0), Vector3(0.045, 0.012, 116))
		_stripe(Vector3(0, 0.009, i * 10), Vector3(116, 0.012, 0.045))
	_make_hud()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("world_map"):
		_return_to_map()
		return
	if Input.is_action_just_pressed("character_review"):
		get_tree().change_scene_to_file("res://scenes/character_review.tscn")
		return
	if Input.is_action_just_pressed("toggle_hud"):
		help_toggle.button_pressed = not help_toggle.button_pressed


func _make_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("739bad")
	sky_material.sky_horizon_color = Color("d2d8c4")
	sky_material.ground_bottom_color = Color("657459")
	sky_material.ground_horizon_color = Color("d2d8c4")
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("e8ecf2")
	environment.ambient_light_energy = 0.7
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 0.6
	environment.tonemap_white = 6.0
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -145, 0)
	sun.light_color = Color("fff4e6")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-25, -35, 0)
	rim.light_color = Color("b8c8ff")
	rim.light_energy = 0.35
	rim.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(rim)


func _box(title: String, size: Vector3, center: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = title
	body.position = center
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color)
	body.add_child(instance)
	add_child(body)
	return body


func _stripe(center: Vector3, size: Vector3) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = center
	instance.material_override = _material(Color("93a17b"))
	add_child(instance)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material


const UiStyle = preload("res://scripts/ui_style.gd")


## A readable card of text over the 3D scene (the location name and the like). Returns the label;
## hiding it hides the card, so the help panel can cover it.
func _add_location_label(copy: String, at := Vector2(24, 68)) -> Label:
	var label := UiStyle.text(copy, 13, UiStyle.INK)
	var holder := UiStyle.card_label(label)
	holder.position = at
	hud.add_child(holder)
	if is_instance_valid(help_toggle):
		help_toggle.toggled.connect(func(expanded: bool): label.visible = not expanded)
	return label


func _make_hud() -> void:
	var canvas := CanvasLayer.new()
	hud = canvas
	add_child(canvas)
	var panel := PanelContainer.new()
	help_panel = panel
	panel.position = Vector2(24, 68)
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UiStyle.frost_style(16, 22, 18)
	panel.add_theme_stylebox_override("panel", style)
	panel.material = UiStyle.frost_material()
	canvas.add_child(panel)
	help_toggle = Button.new()
	help_toggle.text = "Help"
	help_toggle.tooltip_text = "Show controls · H / Back (Share)"
	help_toggle.position = Vector2(24, 20)
	help_toggle.custom_minimum_size = Vector2(64, 36)
	help_toggle.toggle_mode = true
	# H / controller Back handle keyboard focus; don't steal Space from jumping.
	help_toggle.focus_mode = Control.FOCUS_NONE
	help_toggle.toggled.connect(func(expanded: bool) -> void:
		help_panel.visible = expanded
		if is_instance_valid(credits_panel): credits_panel.hide())
	var help_card := UiStyle.frost_button(help_toggle, 18)
	help_card.position = Vector2(24, 20)
	canvas.add_child(help_card)
	var map_button := Button.new()
	map_button.name = "WorldMapButton"
	map_button.text = "World map"
	map_button.tooltip_text = "Return to the world map · M / Start"
	map_button.custom_minimum_size = Vector2(112, 36)
	map_button.focus_mode = Control.FOCUS_NONE
	map_button.pressed.connect(_return_to_map)
	var map_card := UiStyle.frost_button(map_button, 18)
	map_card.position = Vector2(100, 20)
	canvas.add_child(map_card)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	panel.add_child(stack)
	stack.add_child(UiStyle.text("Controls", 20, UiStyle.INK, true))
	var help := UiStyle.text("Move   WASD / left stick\nLook / aim   click + mouse / right stick / Q E\nRun / faster flight   Shift / LB (L1)\nJump   Space / A (Cross)\nFly   jump again in the air\nClimb / descend in flight   aim the camera up / down\nClimb   move into any wall or steep slope\nLeave a wall   jump, or Ctrl / B to let go\nLand   Ctrl / B (Circle)\nBreathe fire   hold V / RB (R1)\nWings   F · [ / ] / triggers\nTalk / reply   J / D-pad right\nSelect response   Enter / A (Cross), or click\nLeave conversation   Esc / B (Circle)\nRecenter camera   C / right-stick click\nZoom   mouse wheel\nRelease mouse   Esc / Start\nClose help   H / Back (Share)", 15, UiStyle.INK)
	if has_method("_make_villagers"):
		help.text += "\nMeet and switch dragons   X / X (Square)\nSwitch collected dragons   Tab / D-pad left"
	stack.add_child(help)
	help.text += "\n3D character review   F8 / Y (Triangle)"
	help.text += "\nReturn to world map   M / Start"
	var credits_link := Button.new()
	credits_link.text = "Credits"
	credits_link.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	UiStyle.style_button(credits_link, UiStyle.BLUE_TEXT, UiStyle.BLUE_TEXT, 8)
	credits_link.pressed.connect(func():
		help_panel.hide()
		credits_panel.show())
	stack.add_child(credits_link)
	# Keep asset attribution available on its own page, outside the controls.
	credits_panel = PanelContainer.new()
	credits_panel.position = panel.position
	credits_panel.custom_minimum_size.x = 500
	credits_panel.add_theme_stylebox_override("panel", style)
	credits_panel.material = UiStyle.frost_material()
	credits_panel.hide()
	canvas.add_child(credits_panel)
	var credit_stack := VBoxContainer.new()
	credit_stack.add_theme_constant_override("separation", 14)
	credits_panel.add_child(credit_stack)
	credit_stack.add_child(UiStyle.text("Credits", 20, UiStyle.INK, true))
	var credits := RichTextLabel.new()
	credits.bbcode_enabled = true
	credits.fit_content = true
	credits.scroll_active = false
	credits.add_theme_font_size_override("normal_font_size", 15)
	credits.add_theme_color_override("default_color", UiStyle.INK)
	credits.add_theme_color_override("meta_color", UiStyle.BLUE_TEXT)
	credits.text = "Human base, skeleton, lip boundary and Kai hair: MakeHuman (CC0).\n\nCamille’s wavy hair: Elvaerwyn, [url=https://static.makehumancommunity.org/assets/assetpacks/hair02.html]CC BY[/url].\n\nCorinne’s curly hair: [url=https://www.makehumancommunity.org/node/477]punkduck[/url], [url=https://www.makehumancommunity.org/assets/assetpacks/hair03.html]CC BY[/url].\nFitted, recolored and weighted for this game."
	credits.meta_clicked.connect(func(link): OS.shell_open(str(link)))
	credit_stack.add_child(credits)
	var back := Button.new()
	back.text = "Back to controls"
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	UiStyle.style_button(back, UiStyle.BLUE_TEXT, UiStyle.BLUE_TEXT, 17, true)
	back.pressed.connect(func():
		credits_panel.hide()
		help_panel.show())
	credit_stack.add_child(back)


func _return_to_map() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/overworld.tscn")
