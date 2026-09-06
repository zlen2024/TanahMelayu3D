class_name Player
extends Entity

const HeroClass = preload("res://scripts/classes/hero_class.gd")

# Refactored Player Controller in Godot 4 OOP
# Inherits Entity and delegates class mechanics to HeroClass strategy

signal stats_changed(hp, max_hp, level, xp, xp_next)
signal energy_changed(current_energy, max_energy)
signal stamina_changed(current_stamina, max_stamina)
signal skill_cooldown_started(skill_index, duration)

@export var peer_id: int = 1
@export var player_name: String = "Hero"
@export var skin_index: int = 0
@export var is_local: bool = false
@export var hero_class: String = "warrior"

var hero_strategy: HeroClass

# Tri-Resource System (HP from Entity, MP, Stamina)
var max_energy: int = 80
var current_energy: int = 80
var energy_regen_rate: float = 6.0
var energy_regen_accum: float = 0.0
var health_regen_accum: float = 0.0

var max_stamina: float = 100.0
var current_stamina: float = 100.0
var stamina_regen_rate: float = 35.0

# Dodge-Roll & Evasion
var is_rolling: bool = false
var is_invulnerable: bool = false
var roll_dir: Vector2 = Vector2.RIGHT

# Combat & Leveling
var level: int = 1
var xp: int = 0
var xp_to_next: int = 40
var attack_damage: int = 25
var attack_cooldown: float = 0.35
var can_attack: bool = true
var facing_dir: Vector2 = Vector2.RIGHT

# Charged Attack (Unlocked at Level 11)
var attack_charge_time: float = 0.0
var is_charging_attack: bool = false

var skill1_cd: float = 0.0
var skill2_cd: float = 0.0
var skill3_cd: float = 0.0

# Client interpolation
var target_sync_pos: Vector2 = Vector2.ZERO
var send_sync_timer: float = 0.0

# Current AnimatedSprite2D clip. Tracked so a skin swap can resume the same
# animation instead of snapping back to idle.
var _current_anim: String = "idle"

# Cached lazily: the World node is built after players can exist, and is freed
# on disconnect, so a reference taken in _ready() would go stale.
var _world: Node = null

@onready var sprite: AnimatedSprite2D = $Sprite2D
@onready var name_label: Label = $UI/NameLabel
@onready var hp_bar: ProgressBar = $UI/HealthBar
@onready var camera: Camera2D = $Camera2D
@onready var attack_area: Area2D = $AttackArea
@onready var slash_sprite: Sprite2D = $SlashSprite

func _ready():
	super._ready()
	add_to_group("players")
	target_sync_pos = global_position
	slash_sprite.visible = false
	
	_apply_skin(skin_index)
	hero_strategy = HeroClass.create(hero_class)
	
	if is_local:
		camera.enabled = true
		name_label.modulate = Color(0.3, 0.9, 1.0)
		recalculate_stats()
		GameState.equipped_gear_updated.connect(func(_gear): recalculate_stats())
		GameState.stats_updated.connect(recalculate_stats)
		GameState.pk_mode_changed.connect(func(_pk): _update_nameplate())
	else:
		camera.enabled = false
		name_label.modulate = Color.WHITE
		
	_update_nameplate()
	_update_hp_bar()

func recalculate_stats():
	hero_class = GameState.hero_class
	hero_strategy = HeroClass.create(hero_class)
	
	var bonus_gear = {
		"atk": GameState.get_equipment_bonus("atk"),
		"def": GameState.get_equipment_bonus("def"),
		"hp": GameState.get_equipment_bonus("hp"),
		"mp": GameState.get_equipment_bonus("mp")
	}
	
	var stats = CombatFormula.calc_player_stats(hero_class, GameState.stat_str, GameState.stat_vit, GameState.stat_agi, GameState.stat_int, bonus_gear)
	max_hp = stats["max_hp"]
	max_energy = stats["max_energy"]
	move_speed = stats["move_speed"]
	attack_damage = stats["attack_damage"]
	defense = stats["defense"]
	
	current_hp = min(current_hp, max_hp)
	current_energy = min(current_energy, max_energy)
	
	if is_local:
		emit_signal("stats_changed", current_hp, max_hp, level, xp, xp_to_next)
		emit_signal("energy_changed", current_energy, max_energy)
		emit_signal("stamina_changed", current_stamina, max_stamina)
	_update_hp_bar()

func _apply_skin(idx: int):
	# Skins are whole SpriteFrames resources now, not single textures.
	var skins = [
		"res://assets/spriteframes/player_blue.tres",
		"res://assets/spriteframes/player_red.tres",
		"res://assets/spriteframes/player_green.tres"
	]
	var path = skins[idx % skins.size()]
	if ResourceLoader.exists(path):
		sprite.sprite_frames = load(path)
		sprite.play(_current_anim)

func _physics_process(delta: float):
	if process_entity_status(delta):
		return
		
	# Cooldown timers
	if skill1_cd > 0: skill1_cd = max(0.0, skill1_cd - delta)
	if skill2_cd > 0: skill2_cd = max(0.0, skill2_cd - delta)
	if skill3_cd > 0: skill3_cd = max(0.0, skill3_cd - delta)
		
	if is_local:
		# UI Focus Lock: block movement and actions when menu/chat is open
		if GameState.is_ui_focused():
			velocity = Vector2.ZERO
			move_and_slide()
			return
			
		# Passive energy / mana regeneration (scales with INT & gear)
		var total_mp_regen = CombatFormula.calc_energy_regen(GameState.stat_int, GameState.get_equipment_bonus("mp_regen"))
		if current_energy < max_energy:
			energy_regen_accum += total_mp_regen * delta
			if energy_regen_accum >= 1.0:
				var gain = int(energy_regen_accum)
				energy_regen_accum -= gain
				current_energy = min(max_energy, current_energy + gain)
				emit_signal("energy_changed", current_energy, max_energy)
				GameState.current_energy = current_energy
			
		# Passive stamina regeneration (when not dodge-rolling)
		if not is_rolling and current_stamina < max_stamina:
			current_stamina = min(max_stamina, current_stamina + (stamina_regen_rate * delta))
			emit_signal("stamina_changed", current_stamina, max_stamina)
			GameState.current_stamina = current_stamina
			
		# Passive VIT health regeneration (scales with VIT & gear)
		var total_hp_regen = CombatFormula.calc_health_regen(GameState.stat_vit, GameState.get_equipment_bonus("hp_regen"))
		if current_hp < max_hp and not is_dead:
			health_regen_accum += total_hp_regen * delta
			if health_regen_accum >= 1.0:
				var gain = int(health_regen_accum)
				health_regen_accum -= gain
				current_hp = min(max_hp, current_hp + gain)
				_update_hp_bar()
				emit_signal("stats_changed", current_hp, max_hp, level, xp, xp_to_next)
				
		_handle_local_input(delta)
	else:
		_handle_remote_interpolation(delta)

func _handle_local_input(delta: float):
	if is_rolling:
		velocity = roll_dir * (move_speed * 1.85) * _terrain_speed_multiplier()
		move_and_slide()
		return
		
	var input_vec = Vector2.ZERO
	if Input.is_action_pressed("move_left"): input_vec.x -= 1.0
	if Input.is_action_pressed("move_right"): input_vec.x += 1.0
	if Input.is_action_pressed("move_up"): input_vec.y -= 1.0
	if Input.is_action_pressed("move_down"): input_vec.y += 1.0
		
	input_vec = input_vec.normalized()
	velocity = input_vec * move_speed * _terrain_speed_multiplier()
	
	if input_vec != Vector2.ZERO:
		face_direction(input_vec)
	_set_anim("walk" if input_vec != Vector2.ZERO else "idle")
			
	move_and_slide()
	
	# Attack holding & charging logic
	if Input.is_action_pressed("attack") and can_attack:
		attack_charge_time += delta
		if attack_charge_time >= 0.4 and level >= 11 and not is_charging_attack:
			is_charging_attack = true
			sprite.modulate = Color(1.8, 1.8, 0.4) # Charging yellow shimmer
	elif Input.is_action_just_released("attack") or (not Input.is_action_pressed("attack") and attack_charge_time > 0):
		if can_attack:
			if attack_charge_time >= 0.4 and level >= 11:
				_execute_charged_attack()
			else:
				_execute_basic_attack()
		attack_charge_time = 0.0
		is_charging_attack = false
		sprite.modulate = Color.WHITE
		
	# Skills 1, 2, 3
	if Input.is_action_just_pressed("skill_1"):
		_execute_skill(1)
	elif Input.is_action_just_pressed("skill_2"):
		_execute_skill(2)
	elif Input.is_action_just_pressed("skill_3"):
		_execute_skill(3)
		
	# Network sync at 20Hz
	send_sync_timer -= delta
	if send_sync_timer <= 0:
		send_sync_timer = 0.05
		if velocity != Vector2.ZERO or global_position.distance_to(target_sync_pos) > 2.0:
			target_sync_pos = global_position
			NetworkManager.send_packet({
				"type": "move",
				"pos": [global_position.x, global_position.y],
				"flip": sprite.flip_h
			})

func _unhandled_input(event: InputEvent):
	if not is_local or GameState.is_ui_focused():
		return
		
	# Active Dodge-Roll
	if event.is_action_pressed("dodge") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_SHIFT or event.physical_keycode == KEY_SHIFT)):
		dodge_roll()
		
	# Quick-access hotbars
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q or event.physical_keycode == KEY_Q:
			GameState.use_quick_slot(0)
		elif event.keycode == KEY_E or event.physical_keycode == KEY_E:
			GameState.use_quick_slot(1)
		elif event.keycode == KEY_1 or event.physical_keycode == KEY_1:
			_execute_skill(1)
		elif event.keycode == KEY_2 or event.physical_keycode == KEY_2:
			_execute_skill(2)
		elif event.keycode == KEY_3 or event.physical_keycode == KEY_3:
			_execute_skill(3)

func dodge_roll() -> bool:
	if is_rolling or is_dead or current_stamina < 25.0:
		return false
		
	current_stamina -= 25.0
	emit_signal("stamina_changed", current_stamina, max_stamina)
	GameState.current_stamina = current_stamina
	
	is_rolling = true
	is_invulnerable = true
	roll_dir = facing_dir
	SoundManager.play("slash")
	
	# Visual ghost effect
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(0.3, 0.8, 2.5, 0.6), 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.25)
	
	NetworkManager.send_packet({
		"type": "roll",
		"pos": [global_position.x, global_position.y],
		"dir": [roll_dir.x, roll_dir.y]
	})
	
	var timer = get_tree().create_timer(0.35)
	timer.timeout.connect(func():
		is_rolling = false
		is_invulnerable = false
	)
	return true

func _handle_remote_interpolation(delta: float):
	# Remote peers have no input; infer movement from the distance still to cover.
	_set_anim("walk" if global_position.distance_to(target_sync_pos) > 1.5 else "idle")
	global_position = global_position.lerp(target_sync_pos, 16.0 * delta)

# Wading slows movement, and deeper water slows it more. World owns the depth
# map; this just asks it about the current position.
func _terrain_speed_multiplier() -> float:
	if not is_instance_valid(_world):
		_world = get_tree().root.find_child("World", true, false)
	if _world and _world.has_method("speed_multiplier_at_world"):
		return _world.speed_multiplier_at_world(global_position)
	return 1.0


# Switch clip only on change; calling play() every frame restarts it.
func _set_anim(name: String) -> void:
	if _current_anim == name:
		return
	_current_anim = name
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(name):
		sprite.play(name)


# Turn to face a direction, keeping the melee hitbox and slash sprite in sync.
# Used by keyboard input and by the ranged classes' auto-aim.
func face_direction(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		return
	facing_dir = dir
	if dir.x != 0:
		sprite.flip_h = dir.x < 0
		attack_area.position.x = -20 if sprite.flip_h else 20
		slash_sprite.position.x = -16 if sprite.flip_h else 16
		slash_sprite.flip_h = sprite.flip_h

func set_network_transform(pos: Vector2, flip: bool):
	target_sync_pos = pos
	sprite.flip_h = flip
	attack_area.position.x = -20 if flip else 20
	slash_sprite.position.x = -16 if flip else 16
	slash_sprite.flip_h = flip

func _execute_basic_attack():
	can_attack = false
	if hero_strategy:
		hero_strategy.execute_basic_attack(self)
	var timer = get_tree().create_timer(attack_cooldown)
	timer.timeout.connect(func(): can_attack = true)

func _execute_charged_attack():
	can_attack = false
	if hero_strategy:
		hero_strategy.execute_charged_attack(self)
	var timer = get_tree().create_timer(attack_cooldown * 1.5)
	timer.timeout.connect(func(): can_attack = true)

func _execute_skill(idx: int):
	if hero_strategy:
		hero_strategy.execute_skill(self, idx)

func damage_enemies_in_radius(radius: float, dmg: int):
	var monsters = get_tree().get_nodes_in_group("monsters")
	for mob in monsters:
		if mob and is_instance_valid(mob) and not mob.is_queued_for_deletion() and not mob.get("is_dead"):
			if global_position.distance_to(mob.global_position) <= radius:
				if mob.has_method("take_damage"):
					mob.take_damage(dmg, peer_id)

func take_damage(amount: int, attacker_id: int = -1) -> int:
	if is_dead:
		return 0
	if is_invulnerable:
		var parent_node = get_parent() if get_parent() else self
		FloatingText.spawn(parent_node, global_position, "DODGE!", Color(0.2, 0.9, 1.0), true)
		return 0
		
	var mitigated = super.take_damage(amount, attacker_id)
	_update_hp_bar()
	
	if is_local:
		GameState.sync_player_stat(peer_id, "hp", current_hp)
		emit_signal("stats_changed", current_hp, max_hp, level, xp, xp_to_next)
		NetworkManager.send_packet({
			"type": "stat_sync",
			"stat": "hp",
			"val": current_hp
		})
	return mitigated

func use_energy(amount: int) -> bool:
	if current_energy >= amount:
		current_energy -= amount
		emit_signal("energy_changed", current_energy, max_energy)
		return true
	show_notification("Out of Energy!", Color(0.4, 0.7, 1.0))
	return false

func restore_energy(amount: int, show_popup: bool = true):
	if is_dead:
		return
	current_energy = min(max_energy, current_energy + amount)
	emit_signal("energy_changed", current_energy, max_energy)
	if show_popup:
		show_notification("+%d MP" % amount, Color(0.3, 0.8, 1.0))

func show_notification(text: String, col: Color = Color.WHITE):
	var label = Label.new()
	label.text = text
	label.modulate = col
	label.position = Vector2(-20, -35)
	label.z_index = 100
	add_child(label)
	var tween = create_tween()
	tween.parallel().tween_property(label, "position:y", label.position.y - 25, 0.7)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.7)
	tween.tween_callback(label.queue_free)

func play_slash_effect():
	slash_sprite.visible = true
	slash_sprite.modulate = Color.WHITE
	var tween = create_tween()
	tween.tween_property(slash_sprite, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func(): slash_sprite.visible = false)

func gain_xp(amount: int):
	xp += amount
	if xp >= xp_to_next:
		_level_up()
	if is_local:
		emit_signal("stats_changed", current_hp, max_hp, level, xp, xp_to_next)
		NetworkManager.send_packet({
			"type": "stat_sync",
			"stat": "xp",
			"val": xp
		})

func _level_up():
	level += 1
	xp -= xp_to_next
	xp_to_next = int(xp_to_next * 1.5)
	max_hp += 25
	current_hp = max_hp
	attack_damage += 6
	SoundManager.play("levelup")
	
	_update_nameplate()
	_update_hp_bar()
	show_levelup_fanfare(level)
	
	if is_local:
		GameState.unspent_stat_points += 3
		GameState.emit_signal("stats_updated")
		show_notification("+3 Stat Points! [C]", Color.GOLD)
		GameState.sync_player_stat(peer_id, "level", level)
		GameState.sync_player_stat(peer_id, "max_hp", max_hp)
		GameState.sync_player_stat(peer_id, "hp", current_hp)
		emit_signal("stats_changed", current_hp, max_hp, level, xp, xp_to_next)
		NetworkManager.send_packet({"type": "stat_sync", "stat": "level", "val": level})
		NetworkManager.send_packet({"type": "stat_sync", "stat": "max_hp", "val": max_hp})
		NetworkManager.send_packet({"type": "stat_sync", "stat": "hp", "val": current_hp})
		NetworkManager.send_packet({
			"type": "chat",
			"sender": "SYSTEM",
			"text": "%s reached Level %d!" % [player_name, level],
			"is_sys": true
		})

func show_levelup_fanfare(new_level: int):
	var label = Label.new()
	label.text = "* LEVEL UP! [Lv %d] *" % new_level
	label.modulate = Color(1.0, 0.9, 0.2)
	label.position = Vector2(-55, -45)
	label.z_index = 100
	add_child(label)
	var float_tween = create_tween()
	float_tween.parallel().tween_property(label, "position:y", label.position.y - 35, 1.2)
	float_tween.parallel().tween_property(label, "modulate:a", 0.0, 1.2)
	float_tween.tween_callback(label.queue_free)

func _die(attacker_id: int = -1):
	super._die(attacker_id)
	visible = false
	NetworkManager.send_packet({
		"type": "player_died",
		"victim_id": peer_id,
		"attacker_id": attacker_id,
		"is_pk": GameState.is_pk_enabled
	})
	NetworkManager.send_packet({
		"type": "chat",
		"sender": "SYSTEM",
		"text": "%s was defeated!" % player_name,
		"is_sys": true
	})
	
	var timer = get_tree().create_timer(3.5)
	timer.timeout.connect(_respawn)

func _respawn():
	is_dead = false
	current_hp = max_hp
	current_energy = max_energy
	current_stamina = max_stamina
	global_position = Vector2(randf_range(-60, 60), randf_range(-60, 60))
	visible = true
	_update_hp_bar()
	if is_local:
		emit_signal("stats_changed", current_hp, max_hp, level, xp, xp_to_next)
		emit_signal("energy_changed", current_energy, max_energy)
		emit_signal("stamina_changed", current_stamina, max_stamina)

func _update_nameplate():
	if name_label:
		var prefix = "[PK] " if GameState.is_pk_enabled and is_local else ""
		name_label.text = "%s%s [Lv.%d]" % [prefix, player_name, level]
		if GameState.is_pk_enabled and is_local:
			name_label.modulate = Color(1.0, 0.3, 0.3)
		elif is_local:
			name_label.modulate = Color(0.3, 0.9, 1.0)
		else:
			name_label.modulate = Color.WHITE

func _update_hp_bar():
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = current_hp
