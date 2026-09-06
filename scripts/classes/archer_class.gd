class_name ArcherClass
extends HeroClass

func _init():
	class_name_str = "archer"

# Range the basic shot travels before expiring. Slightly beyond AUTO_AIM_RANGE
# so an acquired target is always reachable.
const BASIC_SHOT_RANGE: float = 380.0

func execute_basic_attack(player: CharacterBody2D) -> void:
	# No play_slash_effect() here: that is the warrior's melee sword swing and
	# it made the archer look like it was meleeing as well as firing.
	SoundManager.play("slash")
	var dir := aim_dir(player)
	player.face_direction(dir)
	NetworkManager._spawn_projectile(
		player.global_position + dir * 18, dir, player.peer_id,
		player.attack_damage, BASIC_SHOT_RANGE)
	NetworkManager.send_packet({
		"type": "attack", "spell": true,
		"pos": [player.global_position.x, player.global_position.y],
		"dir": [dir.x, dir.y]
	})

func execute_charged_attack(player: CharacterBody2D) -> void:
	SoundManager.play("slash")
	player.show_notification("PIERCING SHOT!", Color.YELLOW)
	
	# Spawn a high-speed projectile that pierces all targets!
	var proj_scene = load("res://scenes/projectile.tscn")
	var proj = proj_scene.instantiate()
	proj.global_position = player.global_position + player.facing_dir * 18
	proj.direction = player.facing_dir
	proj.speed = 520.0 # Faster
	proj.lifetime = 2.0 # Extended range
	proj.damage = int(player.attack_damage * 1.7)
	proj.is_piercing = true
	proj.shooter_id = player.peer_id
	proj.modulate = Color(2.5, 1.8, 0.4) # Bright golden pierce
	player.get_parent().add_child(proj)
	
	NetworkManager.send_packet({
		"type": "attack", "spell": true,
		"pos": [player.global_position.x, player.global_position.y],
		"dir": [player.facing_dir.x, player.facing_dir.y]
	})

func execute_skill(player: CharacterBody2D, idx: int) -> bool:
	if idx == 1 and player.skill1_cd <= 0:
		# Triple Shot (3-arrow fan cone)
		if player.use_energy(18):
			player.skill1_cd = 1.5
			player.emit_signal("skill_cooldown_started", 1, 1.5)
			SoundManager.play("slash")
			for angle_deg in [-15.0, 0.0, 15.0]:
				var dir = player.facing_dir.rotated(deg_to_rad(angle_deg))
				NetworkManager._spawn_projectile(player.global_position + dir * 18, dir, player.peer_id)
			return true
	elif idx == 2 and player.skill2_cd <= 0:
		# Tumble Dash (swift escape leap)
		if player.use_energy(15):
			player.skill2_cd = 2.5
			player.emit_signal("skill_cooldown_started", 2, 2.5)
			SoundManager.play("slash")
			player.global_position += player.facing_dir * 130.0
			player.show_notification("Tumble!", Color.YELLOW)
			return true
	elif idx == 3 and player.skill3_cd <= 0:
		# Field Bandage: heal 45 HP
		if player.use_energy(20):
			player.skill3_cd = 6.0
			player.emit_signal("skill_cooldown_started", 3, 6.0)
			player.heal(45 + int(GameState.stat_vit * 1.2))
			SoundManager.play("levelup")
			return true
	return false
