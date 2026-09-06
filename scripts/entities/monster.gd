class_name Monster
extends Entity

# Refactored Monster Entity in Godot 4 OOP
# Inherits Entity, implements State Machine and Red Ground Telegraph Zones

const ItemDatabase = preload("res://scripts/items/item_database.gd")

enum State { IDLE, CHASE, TELEGRAPH_WINDUP, ATTACK_STRIKE, RECOVERY, DEAD }
enum MonsterType { GREEN_SLIME, RED_SLIME, KING_SLIME }

@export var monster_type: MonsterType = MonsterType.GREEN_SLIME
@export var is_king_slime: bool = false
@export var aggro_radius: float = 160.0
@export var attack_radius: float = 38.0
@export var attack_damage: int = 12
@export var attack_cooldown: float = 1.4

# Compatibility aliases for existing test cases
var max_health: int:
	get: return max_hp
	set(val): max_hp = val
var current_health: int:
	get: return current_hp
	set(val): current_hp = val

var current_state: State = State.IDLE
var target_player: Node2D = null
var can_attack: bool = true

var windup_duration: float = 0.6
var windup_timer: float = 0.0
var recovery_timer: float = 0.0

# Respawn is authority-driven: only the room host (or a solo session) counts
# down. Remote clients are resurrected by apply_sync_state() when the host's
# next monsters_sync reports the monster alive again.
const RESPAWN_TIME: float = 8.0
const RESPAWN_TIME_BOSS: float = 30.0
var respawn_timer: float = 0.0

var target_pos: Vector2 = Vector2.ZERO
var target_sync_pos: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0
var spawn_pos: Vector2 = Vector2.ZERO
var attack_target_pos: Vector2 = Vector2.ZERO

@onready var sprite: AnimatedSprite2D = $Sprite2D
@onready var hp_bar: ProgressBar = $UI/HealthBar
@onready var name_label: Label = $UI/NameLabel
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready():
	super._ready()
	add_to_group("monsters")
	spawn_pos = global_position
	target_sync_pos = global_position
	
	if is_king_slime or monster_type == MonsterType.KING_SLIME:
		monster_type = MonsterType.KING_SLIME
		is_king_slime = true
		max_hp = 220
		current_hp = 220
		attack_damage = 26
		attack_radius = 95.0
		defense = 12
		windup_duration = 0.75
		name_label.text = "King Slime [BOSS]"
		name_label.modulate = Color(1.0, 0.84, 0.0)
		sprite.sprite_frames = preload("res://assets/spriteframes/slime_king.tres")
	elif monster_type == MonsterType.RED_SLIME:
		max_hp = 85
		current_hp = 85
		attack_damage = 18
		attack_radius = 140.0 # Ranged Spitter
		defense = 6
		windup_duration = 0.65
		name_label.text = "Magma Slime [Lv.6]"
		name_label.modulate = Color(1.0, 0.4, 0.2)
		sprite.modulate = Color(1.5, 0.4, 0.4)
	else:
		max_hp = 60
		current_hp = 60
		attack_damage = 12
		attack_radius = 35.0
		defense = 2
		windup_duration = 0.55
		name_label.text = "Forest Slime [Lv.2]"
		
	_update_hp_bar()

func apply_sync_state(pos: Vector2, flip: bool, hp: int, dead: bool):
	target_sync_pos = pos
	if sprite:
		sprite.flip_h = flip
	current_hp = hp
	_update_hp_bar()
	
	if dead and not is_dead:
		_die(0)
	elif not dead and is_dead:
		is_dead = false
		can_attack = true
		visible = true
		scale = Vector2.ONE
		current_state = State.IDLE
		if collision_shape:
			collision_shape.set_deferred("disabled", false)
		if name_label:
			name_label.visible = true

func _physics_process(delta: float):
	# Must run before process_entity_status(), which early-returns for dead
	# entities and would otherwise never let the countdown tick.
	if is_dead and (NetworkManager.is_room_host or NetworkManager.is_solo_mode):
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			_respawn()

	if process_entity_status(delta):
		current_state = State.IDLE
		queue_redraw()
		return
		
	# Remote client interpolation
	if not NetworkManager.is_room_host and not NetworkManager.is_solo_mode:
		global_position = global_position.lerp(target_sync_pos, 15.0 * delta)
		queue_redraw()
		return

	# State Machine Processing
	match current_state:
		State.IDLE, State.CHASE:
			_process_chase(delta)
		State.TELEGRAPH_WINDUP:
			_process_windup(delta)
		State.RECOVERY:
			_process_recovery(delta)
			
	queue_redraw()

func _process_chase(delta: float):
	_find_nearest_player()
	
	if target_player:
		current_state = State.CHASE
		var dir = (target_player.global_position - global_position).normalized()
		velocity = dir * move_speed
		if dir.x != 0:
			sprite.flip_h = dir.x < 0
			
		var dist = global_position.distance_to(target_player.global_position)
		if dist <= attack_radius and can_attack:
			_start_attack_windup(target_player)
			return
	else:
		current_state = State.IDLE
		wander_timer -= delta
		if wander_timer <= 0:
			wander_timer = randf_range(2.5, 5.0)
			target_pos = spawn_pos + Vector2(randf_range(-70, 70), randf_range(-70, 70))
			
		var to_target = target_pos - global_position
		if to_target.length() > 6.0:
			velocity = to_target.normalized() * (move_speed * 0.5)
			if velocity.x != 0:
				sprite.flip_h = velocity.x < 0
		else:
			velocity = Vector2.ZERO
			
	move_and_slide()

var _world: Node = null

# Monsters wade as well, so a pond is a real obstacle rather than a shortcut
# only the player has to respect.
func _terrain_speed_multiplier() -> float:
	if not is_instance_valid(_world):
		_world = get_tree().root.find_child("World", true, false)
	if _world and _world.has_method("speed_multiplier_at_world"):
		return _world.speed_multiplier_at_world(global_position)
	return 1.0


# Switch clip only on change; play() every frame would restart it.
func _set_anim(name: String) -> void:
	if not sprite or not sprite.sprite_frames:
		return
	if sprite.animation == name or not sprite.sprite_frames.has_animation(name):
		return
	sprite.play(name)


func _find_nearest_player():
	var nearest_dist = aggro_radius
	target_player = null
	for p in get_tree().get_nodes_in_group("players"):
		if is_instance_valid(p) and not p.is_queued_for_deletion() and not p.get("is_dead"):
			var dist = global_position.distance_to(p.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				target_player = p

func _start_attack_windup(target: Node2D):
	current_state = State.TELEGRAPH_WINDUP
	can_attack = false
	windup_timer = windup_duration
	attack_target_pos = target.global_position
	velocity = Vector2.ZERO
	SoundManager.play("slash")

func _process_windup(delta: float):
	velocity = Vector2.ZERO
	windup_timer -= delta
	
	# Keep facing the attack target position
	var to_target = attack_target_pos - global_position
	if to_target.x != 0:
		sprite.flip_h = to_target.x < 0
		
	if windup_timer <= 0:
		_execute_attack_strike()

func _execute_attack_strike():
	current_state = State.ATTACK_STRIKE
	SoundManager.play("hit")
	
	if monster_type == MonsterType.KING_SLIME:
		# Heavy circular AoE slam hitting any players in 100px radius
		for p in get_tree().get_nodes_in_group("players"):
			if is_instance_valid(p) and not p.get("is_dead"):
				if global_position.distance_to(p.global_position) <= 100.0:
					p.take_damage(attack_damage, 0)
	elif monster_type == MonsterType.RED_SLIME:
		# Ranged fire spit projectile towards attack_target_pos
		var dir = (attack_target_pos - global_position).normalized()
		NetworkManager._spawn_projectile(global_position + dir * 16, dir, 0)
	else:
		# Green Slime Melee Lunge
		var lunge_dir = (attack_target_pos - global_position).normalized()
		global_position += lunge_dir * 25.0
		if target_player and is_instance_valid(target_player):
			if global_position.distance_to(target_player.global_position) <= attack_radius + 20.0:
				target_player.take_damage(attack_damage, 0)
				
	# Enter recovery pause
	current_state = State.RECOVERY
	recovery_timer = 0.45

func _process_recovery(delta: float):
	velocity = Vector2.ZERO
	recovery_timer -= delta
	if recovery_timer <= 0:
		current_state = State.IDLE
		var timer = get_tree().create_timer(attack_cooldown)
		timer.timeout.connect(func():
			if not is_dead:
				can_attack = true
		)

func _attack_target(player_node: Node2D):
	if is_dead or not can_attack:
		return
	if player_node and player_node.has_method("take_damage"):
		player_node.take_damage(attack_damage, 0)

func _draw():
	if is_dead:
		return
		
	# Draw red danger zone telegraph indicator during windup
	if current_state == State.TELEGRAPH_WINDUP:
		if monster_type == MonsterType.KING_SLIME:
			# Expanding red circle slam danger zone
			var progress = 1.0 - (windup_timer / windup_duration)
			var cur_rad = 100.0 * progress
			draw_circle(Vector2.ZERO, cur_rad, Color(1.0, 0.15, 0.15, 0.35))
			draw_arc(Vector2.ZERO, 100.0, 0, TAU, 32, Color(1.0, 0.2, 0.2, 0.8), 2.0)
		elif monster_type == MonsterType.RED_SLIME:
			# Trajectory aim line
			var to_target = to_local(attack_target_pos)
			draw_line(Vector2.ZERO, to_target, Color(1.0, 0.3, 0.1, 0.7), 3.0)
			draw_circle(to_target, 8.0, Color(1.0, 0.2, 0.2, 0.6))
		else:
			# Directional lunge cone / rectangle
			var dir = (attack_target_pos - global_position).normalized()
			var local_dir = dir.rotated(-rotation)
			var end_pt = local_dir * 45.0
			var side_pt1 = local_dir.rotated(deg_to_rad(28)) * 38.0
			var side_pt2 = local_dir.rotated(deg_to_rad(-28)) * 38.0
			draw_colored_polygon(PackedVector2Array([Vector2.ZERO, side_pt1, end_pt, side_pt2]), Color(1.0, 0.2, 0.2, 0.4))

func take_damage(amount: int, attacker_peer_id: int = -1) -> int:
	if is_dead:
		return 0
		
	NetworkManager.send_packet({
		"type": "monster_hit",
		"mob_idx": get_index(),
		"damage": amount,
		"attacker": attacker_peer_id
	})
	return apply_damage_from_network(amount, attacker_peer_id)

func apply_damage_from_network(amount: int, attacker_peer_id: int = -1) -> int:
	if is_dead:
		return 0
		
	var mitigated = super.take_damage(amount, attacker_peer_id)
	_update_hp_bar()
	
	if current_hp <= 0:
		_die(attacker_peer_id)
	return mitigated

func _die(killer_id: int = -1):
	if is_dead:
		return
	super._die(killer_id)
	
	can_attack = false
	velocity = Vector2.ZERO
	target_player = null
	current_state = State.DEAD
	respawn_timer = RESPAWN_TIME_BOSS if is_king_slime else RESPAWN_TIME

	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	# Hide the corpse. apply_sync_state()'s resurrection branch restores
	# visibility, so both sides of the cycle stay symmetrical.
	visible = false
	if name_label:
		name_label.visible = false

	_spawn_loot()
	
	if killer_id == NetworkManager.local_id:
		var xp_gain = 50 if is_king_slime else 18
		for p in get_tree().get_nodes_in_group("players"):
			if p.get("peer_id") == killer_id and p.has_method("gain_xp"):
				p.gain_xp(xp_gain)
				break
				
		NetworkManager.send_packet({
			"type": "chat",
			"sender": "SYSTEM",
			"text": "%s was slain!" % name_label.text,
			"is_sys": true
		})

func _respawn():
	is_dead = false
	can_attack = true
	current_state = State.IDLE
	target_player = null
	current_hp = max_hp
	respawn_timer = 0.0

	# Return to the original spawn point rather than dying where it fell,
	# so the arena layout stays as world.gd laid it out.
	global_position = spawn_pos
	target_sync_pos = spawn_pos
	velocity = Vector2.ZERO

	visible = true
	scale = Vector2.ONE
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	if name_label:
		name_label.visible = true

	_update_hp_bar()


func _spawn_loot():
	var loot_scene = load("res://scenes/loot_drop.tscn")
	if not loot_scene:
		return
	var parent_node = get_parent() if get_parent() else self
	
	# 1. Drop XP Gem
	var xp_gem = loot_scene.instantiate()
	xp_gem.global_position = global_position + Vector2(randf_range(-12, 12), randf_range(-12, 12))
	xp_gem.loot_type = 0 # XP_GEM
	xp_gem.value = 35 if is_king_slime else 15
	parent_node.add_child(xp_gem)
	
	# 2. Drop Item (Potion, Gear, or Gold) using ItemDatabase
	var item_to_drop = ""
	var roll = randf()
	if is_king_slime:
		if roll < 0.4: item_to_drop = "armor_king"
		elif roll < 0.7: item_to_drop = "wand_archmage"
		else: item_to_drop = "amulet_agility"
	elif monster_type == MonsterType.RED_SLIME:
		if roll < 0.35: item_to_drop = "sword_steel"
		elif roll < 0.65: item_to_drop = "bow_composite"
		else: item_to_drop = "potion_hp"
	else:
		if roll < 0.45: item_to_drop = "potion_hp"
		elif roll < 0.75: item_to_drop = "potion_mp"
		elif roll < 0.90: item_to_drop = "sword_iron"
		else: item_to_drop = "ring_vitality"
		
	if item_to_drop != "":
		var gear_drop = loot_scene.instantiate()
		gear_drop.global_position = global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		gear_drop.loot_type = 1 # Consumable / Gear
		gear_drop.item_payload = ItemDatabase.create_item(item_to_drop)
		parent_node.add_child(gear_drop)

func _update_hp_bar():
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = current_hp
