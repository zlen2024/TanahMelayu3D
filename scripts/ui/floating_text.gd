class_name FloatingText
extends Node2D

var text: String = ""
var color: Color = Color.WHITE
var is_crit: bool = false

static func spawn(parent: Node, world_pos: Vector2, display_text: String, text_color: Color = Color.WHITE, crit: bool = false):
	if not parent or not is_instance_valid(parent):
		return null
	var ft_script = load("res://scripts/ui/floating_text.gd")
	var node = Node2D.new()
	node.set_script(ft_script)
	# Combat text is parented to the entity container, which is Y-sorted, so
	# without this an entity standing lower on the map would draw over the
	# damage number. z_index is resolved before Y-sorting.
	node.z_index = 100
	node.text = display_text
	node.color = text_color
	node.is_crit = crit
	node.global_position = world_pos + Vector2(randf_range(-10, 10), randf_range(-8, 6))
	parent.add_child(node)
	return node

func _ready():
	var lbl = Label.new()
	lbl.name = "Label"
	lbl.text = text
	lbl.modulate = color
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	lbl.add_theme_font_size_override("font_size", 16 if is_crit else 12)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 4 if is_crit else 2)
	lbl.position = Vector2(-50, -12)
	lbl.custom_minimum_size = Vector2(100, 24)
	add_child(lbl)
	
	var tween = create_tween()
	tween.set_parallel(true)
	var rise_dist = 42.0 if is_crit else 28.0
	tween.tween_property(self, "position:y", position.y - rise_dist, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if is_crit:
		scale = Vector2(1.35, 1.35)
		tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(queue_free)
