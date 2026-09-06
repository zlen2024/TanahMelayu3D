extends CanvasLayer

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
	
	stats_btn.pressed.connect(func(): stats_panel.toggle())
	bag_btn.pressed.connect(func(): inventory_ui.toggle())
	
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
	
	var c_name = GameState.hero_class.capitalize()
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
	var timer = get_tree().create_timer(duration)
	timer.timeout.connect(func(): btn.disabled = false)

func _update_skill_labels():
	var c = GameState.hero_class
	if c == "mage":
		skill1_btn.text = "[1] Fireball\n(15 MP)"
		skill2_btn.text = "[2] Frost Nova\n(25 MP)"
		skill3_btn.text = "[3] Mana Surge\n(10 MP)"
	elif c == "archer":
		skill1_btn.text = "[1] Triple Shot\n(18 MP)"
		skill2_btn.text = "[2] Tumble\n(15 MP)"
		skill3_btn.text = "[3] Bandage\n(20 MP)"
	else:
		skill1_btn.text = "[1] Charge\n(15 MP)"
		skill2_btn.text = "[2] Whirlwind\n(22 MP)"
		skill3_btn.text = "[3] Iron Will\n(20 MP)"

func _on_players_changed(_id = 0, _info = {}):
	_refresh_player_list()

func _on_stat_changed(_id: int, _stat: String, _val: Variant):
	_refresh_player_list()

func _refresh_player_list():
	player_list.clear()
	var total_count = GameState.players.size()
	online_count_label.text = "Players Online: %d" % max(1, total_count)
	
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
