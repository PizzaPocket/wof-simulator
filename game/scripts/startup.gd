extends Control
## A book-cover title on marsh green. Progress is measured work, never elapsed time.
## Assets occupy 0–45%; completed world stages occupy 45–100%. Not an ETA.
const WORLD := "res://scenes/mudwing_wetlands.tscn"
const ASSETS := [
	["res://assets/clay.glb", "Loading Clay’s model and textures"],
	["res://assets/dragons/moon.glb", "Loading Moon’s NightWing model"],
	["res://assets/dragons/blue.glb", "Loading Blue’s SilkWing model"],
	["res://assets/dragons/darkstalker.glb", "Loading Darkstalker’s ancient NightWing model"],
	["res://assets/scavengers/kai.glb", "Loading Kai"],
	["res://assets/scavengers/camille.glb", "Loading Camille"],
	["res://assets/scavengers/corinne.glb", "Loading Corinne"],
	["res://assets/scavengers/umber_pouch.glb", "Loading Umber’s satchel"],
	["res://assets/scavengers/wren.glb", "Loading Wren’s travel outfit and curls"],
	[WORLD, "Loading village scenes and shaders"],
]
var load_jobs: Array = ASSETS.duplicate(true)
var resources: Array[Resource] = [] # Keep dynamic loads cached through world creation.
var bar: ProgressBar
var status: Label
var percentage: Label
var retry: Button
var back_to_map: Button
var world: Node
var failed := false
var logo: TextureRect
var column: VBoxContainer
var credit: Label
var destination_name := "the village"
var terrain_entry := -1

func configure(location: Dictionary) -> void:
	destination_name = location.name
	terrain_entry = int(location.get("terrain_entry", -1))
	load_jobs = location.get("assets", []).duplicate(true)
	load_jobs.append([location.scene, "Loading " + destination_name])

func _ready() -> void:
	_build_ui()
	_start.call_deferred()

const UiStyle = preload("res://scripts/ui_style.gd")
var logo_height := 0.0

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = UiStyle.BACKDROP
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var center := CenterContainer.new()
	margin.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.card(20, 40, 32, 14))
	center.add_child(panel)
	column = VBoxContainer.new()
	column.custom_minimum_size.x = 500
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	logo = TextureRect.new()
	logo.self_modulate = UiStyle.INK
	logo.custom_minimum_size = Vector2(0, 220)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	column.add_child(logo)
	var title := _label("WOF Simulator", 22, UiStyle.INK, true)
	column.add_child(title)
	column.add_child(_label("A fan-made tribute · Private playtest · Not for sale", 13, UiStyle.INK_SECONDARY))
	var gap := Control.new()
	gap.custom_minimum_size.y = 10
	column.add_child(gap)
	var row := HBoxContainer.new()
	column.add_child(row)
	status = _label("Preparing to load…", 14, UiStyle.INK)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(status)
	percentage = _label("0%", 14, UiStyle.BLUE_TEXT, true)
	row.add_child(percentage)
	bar = ProgressBar.new()
	bar.custom_minimum_size.y = 6
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", UiStyle.fill(Color("e8eaed"), 3))
	bar.add_theme_stylebox_override("fill", UiStyle.fill(UiStyle.BLUE, 3))
	column.add_child(bar)
	retry = Button.new()
	retry.text = "Retry loading"
	retry.visible = false
	UiStyle.primary_button(retry)
	retry.pressed.connect(_restart)
	column.add_child(retry)
	back_to_map = Button.new()
	back_to_map.text = "Back to world map"
	back_to_map.hide()
	back_to_map.custom_minimum_size.y = 40
	UiStyle.style_button(back_to_map, UiStyle.BLUE_TEXT, UiStyle.BLUE_TEXT, 20, true)
	back_to_map.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/overworld.tscn"))
	column.add_child(back_to_map)
	credit = _label("Inspired by the books by Tui T. Sutherland. An unofficial homage, made with love.\nNot affiliated with or endorsed by the author or Scholastic.", 12, UiStyle.INK_SECONDARY)
	credit.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	credit.offset_top = -72
	credit.offset_bottom = -20
	add_child(credit)
	resized.connect(_resize_layout)
	get_window().size_changed.connect(_resize_layout)
	_resize_layout()

func _resize_layout() -> void:
	var height := clampf(100 + (size.y - 500) * 0.45, 100, 230)
	logo.custom_minimum_size.y = height
	column.add_theme_constant_override("separation", 8 if size.y < 650 else 16)
	# Draw the vector logo at the pixel size it is shown, so it is sharp on any display.
	var density := float(get_window().size.y) / maxf(size.y, 1.0)
	if absf(height * density - logo_height) > 4.0 or logo.texture == null:
		logo_height = height * density
		logo.texture = UiStyle.logo_texture(self, height)

func _label(copy: String, font_size: int, color := UiStyle.INK, bold := false) -> Label:
	var label := UiStyle.text(copy, font_size, color, bold)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label

func _start() -> void:
	await _paint()
	for index in load_jobs.size():
		var path: String = load_jobs[index][0]
		if ResourceLoader.load_threaded_request(path) != OK:
			_fail("Could not request " + path.get_file())
			return
		while true:
			var progress: Array = []
			var state := ResourceLoader.load_threaded_get_status(path, progress)
			if state == ResourceLoader.THREAD_LOAD_FAILED or state == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				_fail("Could not load " + path.get_file())
				return
			var fraction: float = float(progress[0]) if not progress.is_empty() else 0.0
			_set_progress(45.0 * (index + fraction) / load_jobs.size(), load_jobs[index][1])
			if state == ResourceLoader.THREAD_LOAD_LOADED:
				break
			await get_tree().process_frame
		resources.append(ResourceLoader.load_threaded_get(path))
	_set_progress(45, "Preparing " + destination_name)
	await _paint()
	world = (resources.back() as PackedScene).instantiate()
	world.set_meta("startup_loader", true)
	if terrain_entry >= 0: world.set_meta("terrain_entry", terrain_entry)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(world)
	world.visible = false
	if world.has_method("initialize_world"):
		await world.initialize_world(_world_progress)
	_set_progress(100, "Ready to explore")
	await _paint()
	world.visible = true
	world.process_mode = Node.PROCESS_MODE_INHERIT
	get_tree().current_scene = world
	queue_free()

func _world_progress(fraction: float, description: String) -> void:
	_set_progress(45 + 55 * fraction, description)
	await _paint()

func _paint() -> void:
	# Two frames allow the label/bar to draw before the next synchronous stage.
	await get_tree().process_frame
	await get_tree().process_frame

func _set_progress(value: float, description: String) -> void:
	bar.value = maxf(bar.value, value)
	percentage.text = "%d%%" % floori(bar.value)
	status.text = description

func _fail(message: String) -> void:
	failed = true
	# Recovery replaces the cover composition, keeping both actions clear even
	# at the minimum window height.
	logo.hide()
	credit.hide()
	status.text = message + ". Check the game files, then retry."
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	retry.show()
	back_to_map.show()
	retry.grab_focus()
	push_error(message)

func _restart() -> void:
	var replacement: Control = load("res://scenes/startup.tscn").instantiate()
	replacement.load_jobs = load_jobs.duplicate(true)
	replacement.destination_name = destination_name
	replacement.terrain_entry = terrain_entry
	get_tree().root.add_child(replacement)
	get_tree().current_scene = replacement
	queue_free()
