extends RefCounted
## The game's shared light, modern interface style (after Google Maps): white cards with soft
## shadows and rounded corners, dark grey text, blue for actions. Every screen builds its UI from
## these helpers so the map, splash, HUD, terrain controls and dialogue stay in sync.
## Text colours are chosen to keep at least 4.5:1 contrast on the surfaces they sit on
## (checked by tests/ui_contrast_smoke.gd).
const INK := Color("202124")
const INK_SECONDARY := Color("5f6368")
const BLUE := Color("1a73e8") ## Fills, rings and primary buttons (white text on it passes).
const BLUE_TEXT := Color("185abc") ## Blue text on white, tints and tinted land.
const BLUE_TINT := Color("e8f0fe")
const SURFACE := Color.WHITE
const BACKDROP := Color("f8f9fa")
const STROKE := Color("dadce0")
const HOVER_GRAY := Color("f1f3f4")
const PIN_RED := Color("ea4335")
const PIN_BLUE := Color("4285f4")
const PIN_GRAY := Color("9aa0a6")
const LOGO_PATH := "res://assets/branding/wings-of-fire.svg"

static var _bold: FontVariation


static func bold_font() -> FontVariation:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = ThemeDB.fallback_font
		_bold.variation_embolden = 0.55
	return _bold


## A white card with a soft shadow, like Google Maps' floating panels.
static func card(radius := 12, pad_h := 16, pad_v := 12, shadow := 7, fill_color := SURFACE) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.set_corner_radius_all(radius)
	style.content_margin_left = pad_h
	style.content_margin_right = pad_h
	style.content_margin_top = pad_v
	style.content_margin_bottom = pad_v
	style.shadow_color = Color(0, 0, 0, 0.24)
	style.shadow_size = shadow
	style.shadow_offset = Vector2(0, 2)
	return style


static func fill(color: Color, radius := 8, border := Color(0, 0, 0, 0), border_width := 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.border_color = border
	style.set_border_width_all(border_width)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


## Flat button: transparent at rest, grey on hover, blue-tinted when selected. `outline` gives an
## outlined pill; a focus ring keeps keyboard and controller focus visible.
static func style_button(button: Button, ink := INK_SECONDARY, selected_ink := BLUE_TEXT, radius := 8, outline := false) -> void:
	var rest := fill(SURFACE if outline else Color(0, 0, 0, 0), radius, STROKE if outline else Color(0, 0, 0, 0), 1 if outline else 0)
	var hover := fill(Color("f8f9fa") if outline else HOVER_GRAY, radius, STROKE if outline else Color(0, 0, 0, 0), 1 if outline else 0)
	var selected := fill(BLUE_TINT, radius)
	var focus := fill(Color(0, 0, 0, 0), radius, BLUE, 2)
	button.add_theme_stylebox_override("normal", rest)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", selected if button.toggle_mode else hover)
	button.add_theme_stylebox_override("hover_pressed", selected if button.toggle_mode else hover)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_stylebox_override("disabled", rest)
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink)
	button.add_theme_color_override("font_pressed_color", selected_ink if button.toggle_mode else ink)
	button.add_theme_color_override("font_hover_pressed_color", selected_ink if button.toggle_mode else ink)
	button.add_theme_color_override("font_focus_color", ink)
	button.add_theme_color_override("font_disabled_color", PIN_GRAY)
	button.add_theme_font_size_override("font_size", 14)


## A filled blue button for the main action on a screen.
static func primary_button(button: Button, radius := 20) -> void:
	button.add_theme_stylebox_override("normal", fill(BLUE, radius))
	button.add_theme_stylebox_override("hover", fill(Color("1765cc"), radius))
	button.add_theme_stylebox_override("pressed", fill(Color("185abc"), radius))
	button.add_theme_stylebox_override("focus", fill(BLUE, radius, Color("a8c7fa"), 3))
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(key, Color.WHITE)
	button.add_theme_font_size_override("font_size", 15)
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, 40)


static func text(copy: String, font_size: int, color := INK, bold := false) -> Label:
	var label := Label.new()
	label.text = copy
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if bold:
		label.add_theme_font_override("font", bold_font())
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Map-style text: dark grey with a white halo so it reads over land and water alike.
static func halo_label(copy: String, font_size: int, color := INK) -> Label:
	var label := text(copy, font_size, color)
	label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.95))
	label.add_theme_constant_override("outline_size", 5)
	return label


## Frosted glass for the HUD over a 3D scene: the scene behind is blurred and washed white (see
## shaders/frosted_ui.gdshader), so cards stay readable without blocking the view. The tint keeps
## dark text at 6:1 even over the darkest scene.
static var _frost_material: ShaderMaterial

static func frost_material() -> ShaderMaterial:
	if _frost_material == null:
		_frost_material = ShaderMaterial.new()
		_frost_material.shader = load("res://shaders/frosted_ui.gdshader")
	return _frost_material


## The shape of a frosted card: opaque white (the shader replaces it with the frosted scene), a
## faint bright edge and no shadow.
static func frost_style(radius := 14, pad_h := 14, pad_v := 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.set_corner_radius_all(radius)
	style.border_color = Color(1, 1, 1, 0.7)
	style.set_border_width_all(1)
	style.content_margin_left = pad_h
	style.content_margin_right = pad_h
	style.content_margin_top = pad_v
	style.content_margin_bottom = pad_v
	return style


## Makes a panel a frosted card.
static func frost_panel(panel: PanelContainer, radius := 14, pad_h := 14, pad_v := 8) -> void:
	panel.add_theme_stylebox_override("panel", frost_style(radius, pad_h, pad_v))
	panel.material = frost_material()


## Wraps a button in a frosted card (a button cannot be frosted directly because its text would be
## frosted too). The button is made transparent with a faint hover and a blue focus ring. Add the
## returned card to the scene instead of the button; hiding the button hides the card.
static func frost_button(button: Button, radius := 18) -> PanelContainer:
	var holder := PanelContainer.new()
	frost_panel(holder, radius, 2, 2)
	holder.size_flags_horizontal = button.size_flags_horizontal
	holder.size_flags_vertical = button.size_flags_vertical
	var clear := fill(Color(0, 0, 0, 0), radius)
	button.add_theme_stylebox_override("normal", clear)
	button.add_theme_stylebox_override("hover", fill(Color(0.13, 0.13, 0.14, 0.10), radius))
	button.add_theme_stylebox_override("pressed", fill(Color(0.10, 0.45, 0.91, 0.20), radius))
	button.add_theme_stylebox_override("hover_pressed", fill(Color(0.10, 0.45, 0.91, 0.20), radius))
	button.add_theme_stylebox_override("focus", fill(Color(0, 0, 0, 0), radius, BLUE, 2))
	for key in ["font_color", "font_hover_color", "font_focus_color"]:
		button.add_theme_color_override(key, INK)
	for key in ["font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(key, BLUE_TEXT)
	holder.add_child(button)
	button.visibility_changed.connect(func(): holder.visible = button.visible)
	return holder


## A label on a small frosted card so it stays readable over a 3D scene. Hiding the label hides the
## card. Returns the card; the label is its child.
static func card_label(label: Label, radius := 12) -> PanelContainer:
	var holder := PanelContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frost_panel(holder, radius, 12, 8)
	label.add_theme_color_override("font_color", INK)
	holder.add_child(label)
	label.visibility_changed.connect(func(): holder.visible = label.visible)
	return holder


## The logo, drawn from its vector source at the pixel size it will actually be shown, so it stays
## sharp on any display. (An imported SVG is rasterized once at import size and goes soft when
## scaled up.) `logical_height` is the on-screen height in UI units.
static func logo_texture(canvas: CanvasItem, logical_height: float) -> ImageTexture:
	var bytes := FileAccess.get_file_as_bytes(LOGO_PATH)
	if bytes.is_empty():
		return null
	var window := canvas.get_window()
	var logical := canvas.get_viewport().get_visible_rect().size.y
	var density := maxf(1.0, float(window.size.y) / maxf(logical, 1.0))
	var pixel_height := clampf(logical_height * density, 64.0, 3000.0)
	var image := Image.new()
	if image.load_svg_from_buffer(bytes, pixel_height / 400.0) != OK:
		return null
	return ImageTexture.create_from_image(image)
