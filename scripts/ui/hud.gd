extends CanvasLayer

const Heritage = preload("res://scripts/ui/heritage_style.gd")
var skill_titles: Array[String] = []
var region_label: Label
var region_timer := 0.0

# In-Game HUD: Displays HP, Energy, Stamina, XP, Leaderboard, Skill Bar, Hotbar, and Stats/Bag toggles.

@onready var hp_bar: ProgressBar = $TopLeft/VBoxContainer/HBoxHP/HPBar
@onready var hp_label: Label = $TopLeft/VBoxContainer/HBoxHP/HPLabel
@onready var energy_bar: ProgressBar = $TopLeft/VBoxContainer/HBoxEnergy/EnergyBar
@onready var energy_label: Label = $TopLeft/VBoxContainer/HBoxEnergy/EnergyLabel
@onready var xp_bar: ProgressBar = $TopLeft/VBoxContainer/HBoxXP/XPBar
@onready var xp_label: Label = $TopLeft/VBoxContainer/HBoxXP/XPLabel
@onready var level_label: Label = $TopLeft/VBoxContainer/LevelLabel

@onready var stats_btn: Button = $TopLeft/VBoxContainer/HBoxButtons/StatsBtn
@onready var bag_btn: Button = $TopLeft/VBoxContainer/HBoxButtons/BagBtn

@onready var online_count_label: Label = $TopRight/Panel/VBox/OnlineCount
@onready var player_list: ItemList = $TopRight/Panel/VBox/PlayerList

@onready var skill1_btn: Button = $SkillBar/Skill1Btn
@onready var skill2_btn: Button = $SkillBar/Skill2Btn
@onready var skill3_btn: Button = $SkillBar/Skill3Btn

@onready var stats_panel = $StatsPanel
@onready var inventory_ui = $InventoryUI

var stamina_bar: ProgressBar
var stamina_label: Label
var quick_q_btn: Button
var quick_e_btn: Button

var local_player_node: CharacterBody2D = null

func _ready():
	GameState.player_registered.connect(_on_players_changed)
	GameState.player_unregistered.connect(_on_players_changed)
	GameState.player_stat_changed.connect(_on_stat_changed)
	GameState.stats_updated.connect(_update_skill_labels)
	GameState.quick_slots_updated.connect(_on_quick_slots_updated)
	GameState.pk_mode_changed.connect(func(_pk): _refresh_player_list())
	
	_build_stamina_bar_ui()
	_build_quick_slots_ui()
	_apply_heritage_ui()
	
	stats_btn.pressed.connect(func(): stats_panel.toggle())
	bag_btn.pressed.connect(func(): inventory_ui.toggle())
	stats_panel.visibility_changed.connect(func():
		if stats_panel.visible: inventory_ui.set_open(false)
	)
	inventory_ui.visibility_changed.connect(func():
		if inventory_ui.visible: stats_panel.set_open(false)
	)
	
	skill1_btn.pressed.connect(func(): if local_player_node: local_player_node._execute_skill(1))
	skill2_btn.pressed.connect(func(): if local_player_node: local_player_node._execute_skill(2))
	skill3_btn.pressed.connect(func(): if local_player_node: local_player_node._execute_skill(3))
	
	_update_skill_labels()
	_on_quick_slots_updated(GameState.quick_slots)
	
	# Connect to local player stats when spawned
	var world = get_tree().root.find_child("World", true, false)
	if world:
		var players_container = world.find_child("Players", true, false)
		if players_container:
			players_container.child_entered_tree.connect(_on_player_spawned)

func _build_stamina_bar_ui():
	var vbox = $TopLeft/VBoxContainer
	var hbox = HBoxContainer.new()
	hbox.name = "HBoxStamina"
	
	var tag = Label.new()
	tag.text = "STA"
	tag.custom_minimum_size = Vector2(32, 0)
	tag.modulate = Color(0.2, 0.9, 0.4)
	hbox.add_child(tag)
	
	stamina_bar = ProgressBar.new()
	stamina_bar.name = "StaminaBar"
	stamina_bar.custom_minimum_size = Vector2(120, 14)
	stamina_bar.max_value = 100
	stamina_bar.value = 100
	stamina_bar.show_percentage = false
	stamina_bar.modulate = Color(0.2, 0.9, 0.4)
	hbox.add_child(stamina_bar)
	
	stamina_label = Label.new()
	stamina_label.text = "100 / 100"
	stamina_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stamina_label.modulate = Color(0.9, 1.0, 0.9)
	hbox.add_child(stamina_label)
	
	# Insert right after Energy bar
	var energy_idx = $TopLeft/VBoxContainer/HBoxEnergy.get_index()
	vbox.add_child(hbox)
	vbox.move_child(hbox, energy_idx + 1)

func _build_quick_slots_ui():
	var skill_bar = $SkillBar
	var hbox = HBoxContainer.new()
	hbox.name = "QuickSlots"
	
	quick_q_btn = Button.new()
	quick_q_btn.name = "QuickQBtn"
	quick_q_btn.custom_minimum_size = Vector2(50, 42)
	quick_q_btn.text = "[Q]\n---"
	quick_q_btn.pressed.connect(func(): GameState.use_quick_slot(0))
	hbox.add_child(quick_q_btn)
	
	quick_e_btn = Button.new()
	quick_e_btn.name = "QuickEBtn"
	quick_e_btn.custom_minimum_size = Vector2(50, 42)
	quick_e_btn.text = "[E]\n---"
	quick_e_btn.pressed.connect(func(): GameState.use_quick_slot(1))
	hbox.add_child(quick_e_btn)
	
	skill_bar.add_child(hbox)
	skill_bar.move_child(hbox, 0) # Insert at start of skillbar

func _on_player_spawned(node: Node):
	if node is CharacterBody2D and node.get("is_local") == true:
		local_player_node = node
		node.stats_changed.connect(update_stats)
		node.energy_changed.connect(update_energy)
		node.stamina_changed.connect(update_stamina)
		node.skill_cooldown_started.connect(_on_skill_cooldown)
		_update_skill_labels()

func update_stats(hp: int, max_hp: int, level: int, xp: int, xp_next: int):
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	hp_label.text = "%d / %d" % [hp, max_hp]
	
	xp_bar.max_value = xp_next
	xp_bar.value = xp
	xp_label.text = "%d / %d XP" % [xp, xp_next]
	
	var c_name = Heritage.CLASS_NAMES.get(GameState.hero_class, "Pendekar")
	level_label.text = "Level %d %s" % [level, c_name]

func update_energy(curr: int, max_en: int):
	energy_bar.max_value = max_en
	energy_bar.value = curr
	energy_label.text = "%d / %d" % [curr, max_en]

func update_stamina(curr: float, max_sta: float):
	if stamina_bar:
		stamina_bar.max_value = max_sta
		stamina_bar.value = curr
	if stamina_label:
		stamina_label.text = "%d / %d" % [int(curr), int(max_sta)]

func _on_quick_slots_updated(slots: Array):
	if quick_q_btn:
		var q_item = slots[0] if slots.size() > 0 else null
		if q_item:
			quick_q_btn.text = "[Q]\n%s" % q_item.get("name", "Item").substr(0, 5)
			quick_q_btn.modulate = Color(0.3, 1.0, 0.4)
		else:
			quick_q_btn.text = "[Q]\n---"
			quick_q_btn.modulate = Color.GRAY
			
	if quick_e_btn:
		var e_item = slots[1] if slots.size() > 1 else null
		if e_item:
			quick_e_btn.text = "[E]\n%s" % e_item.get("name", "Item").substr(0, 5)
			quick_e_btn.modulate = Color(0.3, 0.8, 1.0)
		else:
			quick_e_btn.text = "[E]\n---"
			quick_e_btn.modulate = Color.GRAY

func _on_skill_cooldown(skill_idx: int, duration: float):
	var btn = skill1_btn if skill_idx == 1 else (skill2_btn if skill_idx == 2 else skill3_btn)
	btn.disabled = true
	btn.tooltip_text = "Recovering for %.1f seconds" % duration

func _update_skill_labels():
	var c = GameState.hero_class
	if c == "mage":
		skill1_btn.text = "[1] Api Sakti\n15 energy"
		skill2_btn.text = "[2] Embun Beku\n25 energy"
		skill3_btn.text = "[3] Semangat\n10 energy"
	elif c == "archer":
		skill1_btn.text = "[1] Tiga Panah\n18 energy"
		skill2_btn.text = "[2] Elak\n15 energy"
		skill3_btn.text = "[3] Balutan\n20 energy"
	else:
		skill1_btn.text = "[1] Terjah\n15 energy"
		skill2_btn.text = "[2] Putaran\n22 energy"
		skill3_btn.text = "[3] Tekad Besi\n20 energy"
	skill_titles = [skill1_btn.text, skill2_btn.text, skill3_btn.text]
	var tips := ["Charge toward your target", "Strike surrounding foes", "Fortify your resolve"]
	if c == "mage": tips = ["Launch a fireball", "Freeze nearby enemies", "Restore your magical strength"]
	if c == "archer": tips = ["Fire three arrows", "Tumble out of danger", "Recover health"]
	for i in range(3):
		[skill1_btn, skill2_btn, skill3_btn][i].tooltip_text = tips[i]

func _apply_heritage_ui():
	$TopLeft.offset_left = 24
	$TopLeft.offset_top = 24
	$TopLeft.offset_right = 300
	$TopLeft.offset_bottom = 198
	var back := Panel.new()
	back.position = Vector2(-8, -8)
	back.size = Vector2(284, 178)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_theme_stylebox_override("panel", Heritage.panel(Color(0.025, 0.065, 0.055, 0.94)))
	$TopLeft.add_child(back)
	$TopLeft.move_child(back, 0)
	stats_btn.text = "Ilmu [C]"
	bag_btn.text = "Bekal [B]"
	for bar in [hp_bar, energy_bar, xp_bar, stamina_bar]:
		bar.tooltip_text = "Health" if bar == hp_bar else ("Energy for skills" if bar == energy_bar else ("Experience" if bar == xp_bar else "Stamina for dodging"))
	for btn in [skill1_btn, skill2_btn, skill3_btn]:
		btn.custom_minimum_size = Vector2(116, 54)
		btn.add_theme_font_size_override("font_size", 13)
	region_label = Heritage.label("T A N A H   M E L A Y U\nSimpang Rimba", 16, Heritage.GOLD)
	region_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	region_label.offset_left = -180
	region_label.offset_right = 180
	region_label.offset_top = 22
	region_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	region_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	region_label.add_theme_constant_override("shadow_offset_x", 1)
	region_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(region_label)
	$ChatBox._set_minimized(true)
	$ChatBox.offset_top = -260
	$ChatBox.offset_bottom = -94
	$ChatBox/TabToggleBtn.position.y = 140
	$ChatBox/TabToggleBtn.pressed.connect(func(): $ChatBox/TabToggleBtn.position.y = 140 if $ChatBox.is_minimized else -25)
	$ControlsHint.text = "WASD  Move    ·    SPACE  Attack    ·    SHIFT  Dodge    ·    1 / 2 / 3  Skills    ·    Q / E  Items    ·    ENTER  Chat"
	$ControlsHint.add_theme_font_size_override("font_size", 12)
	$ControlsHint.add_theme_color_override("font_color", Heritage.IVORY)
	$ControlsHint.add_theme_color_override("font_shadow_color", Color.BLACK)
	$ControlsHint.add_theme_constant_override("shadow_offset_y", 2)

func _process(delta: float):
	if not is_instance_valid(local_player_node): return
	var cooldowns := [local_player_node.skill1_cd, local_player_node.skill2_cd, local_player_node.skill3_cd]
	for i in range(3):
		var btn: Button = [skill1_btn, skill2_btn, skill3_btn][i]
		btn.disabled = cooldowns[i] > 0 or local_player_node.is_dead
		if skill_titles.size() == 3:
			btn.text = "%s\n%.1fs" % [skill_titles[i].split("\n")[0], cooldowns[i]] if cooldowns[i] > 0 else skill_titles[i]
	region_timer -= delta
	if region_timer <= 0:
		region_timer = 0.5
		var pos: Vector2 = local_player_node.global_position
		var region := "Simpang Rimba"
		if pos.y < -300: region = "Batu Purba · Jin Belian territory"
		elif pos.x > 350 and pos.y > 220: region = "Tasik Sunyi"
		elif absf(pos.x) > 330: region = "Kampung di Rimba"
		region_label.text = "T A N A H   M E L A Y U\n" + region

func _on_players_changed(_id = 0, _info = {}):
	_refresh_player_list()

func _on_stat_changed(_id: int, _stat: String, _val: Variant):
	_refresh_player_list()

func _refresh_player_list():
	player_list.clear()
	var total_count = GameState.players.size()
	online_count_label.text = "Solo expedition" if NetworkManager.is_solo_mode else "Adventurers: %d" % total_count
	
	for pid in GameState.players:
		var p_info = GameState.players[pid]
		var p_name = p_info.get("name", "Hero")
		var p_level = p_info.get("level", 1)
		var p_skin = p_info.get("skin", 0)
		
		var tag = "%s (Lv.%d)" % [p_name, p_level]
		if pid == NetworkManager.local_id:
			tag += " [You]"
			if GameState.is_pk_enabled:
				tag += " [PK]"
		player_list.add_item(tag)
