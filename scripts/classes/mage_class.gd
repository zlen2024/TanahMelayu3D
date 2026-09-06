class_name MageClass
extends HeroClass

func _init():
	class_name_str = "mage"

# Mage bolts fly a little shorter than the archer's arrows.
const BASIC_BOLT_RANGE: float = 330.0

func execute_basic_attack(player: CharacterBody2D) -> void:
	# No play_slash_effect(): that is the warrior's melee swing.
	SoundManager.play("slash")
	var dir := aim_dir(player)
	player.face_direction(dir)
	NetworkManager._spawn_projectile(
		player.global_position + dir * 18, dir, player.peer_id,
		player.attack_damage, BASIC_BOLT_RANGE)
	NetworkManager.send_packet({
		"type": "attack", "spell": true,
		"pos": [player.global_position.x, player.global_position.y],
		"dir": [dir.x, dir.y]
	})

func execute_charged_attack(player: CharacterBody2D) -> void:
	SoundManager.play("slash")
	player.show_notification("STUN BOLT!", Color.CYAN)
	
	# Spawn a projectile that deals 1.6x damage and causes a 1.5s stun!
	var proj_scene = load("res://scenes/projectile.tscn")
	var proj = proj_scene.instantiate()
	proj.global_position = player.global_position + player.facing_dir * 18
	proj.direction = player.facing_dir
	proj.shooter_id = player.peer_id
	proj.damage = int(player.attack_damage * 1.6)
	proj.causes_stun = true
	proj.stun_duration = 1.5
	proj.modulate = Color(0.4, 0.8, 2.5) # Arcane cyan glow
	player.get_parent().add_child(proj)
	
	NetworkManager.send_packet({
		"type": "attack", "spell": true,
		"pos": [player.global_position.x, player.global_position.y],
		"dir": [player.facing_dir.x, player.facing_dir.y]
	})

func execute_skill(player: CharacterBody2D, idx: int) -> bool:
	if idx == 1 and player.skill1_cd <= 0:
		# Arcane Fireball
		if player.use_energy(15):
			player.skill1_cd = 1.0
			player.emit_signal("skill_cooldown_started", 1, 1.0)
			SoundManager.play("slash")
			var fdir := aim_dir(player)
			player.face_direction(fdir)
			NetworkManager._spawn_projectile(player.global_position + fdir * 18, fdir, player.peer_id, player.attack_damage, BASIC_BOLT_RANGE)
			NetworkManager.send_packet({
				"type": "attack", "spell": true,
				"pos": [player.global_position.x, player.global_position.y],
				"dir": [player.facing_dir.x, player.facing_dir.y]
			})
			return true
	elif idx == 2 and player.skill2_cd <= 0:
		# Frost Nova (360 Freeze shockwave)
		if player.use_energy(25):
			player.skill2_cd = 4.0
			player.emit_signal("skill_cooldown_started", 2, 4.0)
			SoundManager.play("slash")
			player.play_slash_effect()
			player.damage_enemies_in_radius(90, 22 + int(GameState.stat_int * 2.5))
			return true
	elif idx == 3 and player.skill3_cd <= 0:
		# Mana Surge: heal 60 HP + 25 Energy
		if player.use_energy(10):
			player.skill3_cd = 7.0
			player.emit_signal("skill_cooldown_started", 3, 7.0)
			player.heal(60)
			player.restore_energy(25)
			SoundManager.play("levelup")
			return true
	return false
