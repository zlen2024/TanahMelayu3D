extends PanelContainer

# StatsPanel: Displays STR, VIT, AGI, INT, DEF, MP Regen, and PK Toggle
# Includes UI Focus Lock

@onready var class_label: Label = $VBox/ClassLabel
@onready var points_label: Label = $VBox/PointsLabel
@onready var str_val: Label = $VBox/Grid/STRRow/Val
@onready var str_btn: Button = $VBox/Grid/STRRow/Btn
@onready var vit_val: Label = $VBox/Grid/VITRow/Val
@onready var vit_btn: Button = $VBox/Grid/VITRow/Btn
@onready var agi_val: Label = $VBox/Grid/AGIRow/Val
@onready var agi_btn: Button = $VBox/Grid/AGIRow/Btn
@onready var int_val: Label = $VBox/Grid/INTRow/Val
@onready var int_btn: Button = $VBox/Grid/INTRow/Btn
@onready var derived_label: Label = $VBox/DerivedLabel
@onready var close_btn: Button = $VBox/CloseBtn

var pk_btn: Button

func _ready():
	visible = false
	GameState.stats_updated.connect(_refresh_ui)
	GameState.pk_mode_changed.connect(func(_pk): _refresh_ui())
	str_btn.pressed.connect(func(): NetworkManager.send_allocate_stat("str"))
	vit_btn.pressed.connect(func(): NetworkManager.send_allocate_stat("vit"))
	agi_btn.pressed.connect(func(): NetworkManager.send_allocate_stat("agi"))
	int_btn.pressed.connect(func(): NetworkManager.send_allocate_stat("int"))
	close_btn.pressed.connect(func(): set_open(false))
	
	# Add PK Mode Toggle Button
	pk_btn = Button.new()
	pk_btn.name = "PKButton"
	pk_btn.custom_minimum_size = Vector2(160, 30)
	pk_btn.pressed.connect(_on_pk_btn_pressed)
	$VBox.add_child(pk_btn)
	$VBox.move_child(pk_btn, $VBox.get_child_count() - 2)
	
	_refresh_ui()

func _unhandled_input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_C:
			toggle()

func toggle():
	set_open(not visible)

func set_open(open: bool):
	if visible == open:
		return
	visible = open
	GameState.set_ui_modal_open(visible)
	if visible:
		_refresh_ui()

func _refresh_ui():
	var c_name = GameState.hero_class.capitalize()
	class_label.text = "Class: %s  |  Unspent Points: %d" % [c_name, GameState.unspent_stat_points]
	str_val.text = str(GameState.stat_str)
	vit_val.text = str(GameState.stat_vit)
	agi_val.text = str(GameState.stat_agi)
	int_val.text = str(GameState.stat_int)
	
	var has_points = GameState.unspent_stat_points > 0
	str_btn.visible = has_points
	vit_btn.visible = has_points
	agi_btn.visible = has_points
	int_btn.visible = has_points
	
	# Derived stats preview with DEF and MP Regen
	var bonus_gear = {
		"atk": GameState.get_equipment_bonus("atk"),
		"def": GameState.get_equipment_bonus("def"),
		"hp": GameState.get_equipment_bonus("hp"),
		"mp": GameState.get_equipment_bonus("mp")
	}
	var stats = CombatFormula.calc_player_stats(GameState.hero_class, GameState.stat_str, GameState.stat_vit, GameState.stat_agi, GameState.stat_int, bonus_gear)
	var mp_regen = CombatFormula.calc_energy_regen(GameState.stat_int)
	derived_label.text = "HP: %d | DEF: %d | MP: %d (+%.1f/s) | ATK: %d" % [
		stats["max_hp"], stats["defense"], stats["max_energy"], mp_regen, stats["attack_damage"]
	]
	
	# PK Button state
	if pk_btn:
		var local_player_level = 1
		for p in get_tree().get_nodes_in_group("players"):
			if p.get("is_local") == true:
				local_player_level = p.get("level")
				break
				
		if local_player_level < 10:
			pk_btn.text = "PK Mode: Locked (Lv 10+)"
			pk_btn.disabled = true
			pk_btn.modulate = Color.GRAY
		else:
			pk_btn.disabled = false
			if GameState.is_pk_enabled:
				pk_btn.text = "PK Mode: ON [DANGER!]"
				pk_btn.modulate = Color(1.0, 0.3, 0.3)
			else:
				pk_btn.text = "PK Mode: OFF"
				pk_btn.modulate = Color(0.3, 1.0, 0.5)

func _on_pk_btn_pressed():
	var local_player_level = 1
	for p in get_tree().get_nodes_in_group("players"):
		if p.get("is_local") == true:
			local_player_level = p.get("level")
			break
	GameState.toggle_pk_mode(local_player_level)
	_refresh_ui()
