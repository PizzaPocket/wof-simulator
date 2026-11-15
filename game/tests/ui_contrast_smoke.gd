extends SceneTree
## Text must stay legible: every text colour keeps at least 4.5:1 contrast on the surfaces it is
## drawn over (map water, land and each climate tint, white cards and the splash backdrop).
const UiStyle = preload("res://scripts/ui_style.gd")
const WorldMap = preload("res://scripts/world_map.gd")
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func luminance(color: Color) -> float:
	var lin := color.srgb_to_linear()
	return 0.2126 * lin.r + 0.7152 * lin.g + 0.0722 * lin.b

func contrast(a: Color, b: Color) -> float:
	var la := luminance(a)
	var lb := luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)

func require(name: String, ink: Color, surface: Color, minimum := 4.5) -> void:
	var ratio := contrast(ink, surface)
	if ratio < minimum:
		failures.append("%s: %.2f:1 is below %.1f:1" % [name, ratio, minimum])
		printerr(failures[-1])

func _run() -> void:
	var map_surfaces := {"water": WorldMap.WATER, "land": WorldMap.LAND}
	for key in WorldMap.CLIMATE:
		map_surfaces["climate " + key] = WorldMap.CLIMATE[key]
	var card_surfaces := {"white card": UiStyle.SURFACE, "blue tint": UiStyle.BLUE_TINT, "hover grey": UiStyle.HOVER_GRAY, "splash backdrop": UiStyle.BACKDROP}
	# Map text sits on water, land and every climate tint.
	for surface in map_surfaces:
		require("pin names on " + surface, UiStyle.INK, map_surfaces[surface])
		require("region names on " + surface, WorldMap.REGION_INK, map_surfaces[surface])
		require("continent names on " + surface, WorldMap.CONTINENT_INK, map_surfaces[surface])
	# Interface text sits on cards.
	for surface in card_surfaces:
		require("body text on " + surface, UiStyle.INK, card_surfaces[surface])
		require("secondary text on " + surface, UiStyle.INK_SECONDARY, card_surfaces[surface])
		require("blue text on " + surface, UiStyle.BLUE_TEXT, card_surfaces[surface])
	require("white on a blue button", Color.WHITE, UiStyle.BLUE)
	require("white on the toast", Color.WHITE, Color(0.125, 0.129, 0.141))
	if failures.is_empty():
		print("PASS: every text colour keeps at least 4.5:1 contrast on its surfaces")
	quit(0 if failures.is_empty() else 1)
