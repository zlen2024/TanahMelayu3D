extends RefCounted

const GOLD := Color("d5b578")
const IVORY := Color("eee7d5")
const MUTED := Color("92aaa0")
const INK := Color("0b1b18")
const CLASS_NAMES := {"warrior": "Pendekar", "mage": "Pawang", "archer": "Pemanah"}

static func panel(color: Color = INK, border: Color = Color("425449"), padding: int = 16) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

static func label(text: String, font_size: int = 16, color: Color = IVORY) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.add_theme_constant_override("outline_size", 0)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

static func display_font() -> Font:
	return preload("res://assets/fonts/CormorantGaramond.ttf")
