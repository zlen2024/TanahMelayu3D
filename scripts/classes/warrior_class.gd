class_name WarriorClass
extends HeroClass

const FloatingText = preload("res://scripts/ui/floating_text.gd")
const CombatFormula = preload("res://scripts/combat/combat_formula.gd")

func _init():
	class_name_str = "warrior"

func execute_basic_attack(player: CharacterBody2D) -> void:
	player.play_slash_effect()
	SoundManager.play("slash")
	NetworkManager.send_packet({
		"type": "attack", "spell": false,
		"pos": [player.global_position.x, player.global_position.y],
		"dir": [player.facing_dir.x, player.facing_dir.y]
	})
	
	var targets = player.attack_area.get_overlapping_bodies()
	for t in targets:
		if t != player and t.is_in_group("monsters") and t.has_method("take_damage"):
			_deal_player_damage(player, t, player.attack_damage)

func execute_charged_attack(player: CharacterBody2D) -> void:
	player.play_slash_effect()
	SoundManager.play("slash")
	player.show_notification("HEAVY CLEAVE!", Color.ORANGE)
	var dmg = int(player.attack_damage * 1.8)
	
	# AoE cleave hitting enemies and knocking them backward
	var monsters = player.get_tree().get_nodes_in_group("monsters")
	for mob in monsters:
		if mob and is_instance_valid(mob) and not mob.is_queued_for_deletion() and not mob.get("is_dead"):
			if player.global_position.distance_to(mob.global_position) <= 85.0:
				_deal_player_damage(player, mob, dmg)
				# Apply knockback
				var knock_dir = (mob.global_position - player.global_position).normalized()
				if knock_dir == Vector2.ZERO:
					knock_dir = player.facing_dir
				mob.global_position += knock_dir * 60.0

func execute_skill(player: CharacterBody2D, idx: int) -> bool:
	if idx == 1 and player.skill1_cd <= 0:
		# Shield Charge: dash forward + damage
		if player.use_energy(15):
			player.skill1_cd = 2.0
			player.emit_signal("skill_cooldown_started", 1, 2.0)
			SoundManager.play("slash")
			player.global_position += player.facing_dir * 90.0
			player.damage_enemies_in_radius(65, 25 + int(GameState.stat_str * 2.5))
			player.play_slash_effect()
			return true
	elif idx == 2 and player.skill2_cd <= 0:
		# Whirlwind Spin (360 AoE)
		if player.use_energy(22):
			player.skill2_cd = 3.5
			player.emit_signal("skill_cooldown_started", 2, 3.5)
			SoundManager.play("slash")
			player.play_slash_effect()
			player.damage_enemies_in_radius(85, 30 + int(GameState.stat_str * 3.5))
			return true
	elif idx == 3 and player.skill3_cd <= 0:
		# Iron Will: heal 50 HP
		if player.use_energy(20):
			player.skill3_cd = 8.0
			player.emit_signal("skill_cooldown_started", 3, 8.0)
			player.heal(50 + int(GameState.stat_vit * 1.5))
			SoundManager.play("levelup")
			return true
	return false

func _deal_player_damage(player: CharacterBody2D, target: Node, base_dmg: int) -> void:
	var final_dmg = base_dmg
	var is_crit = CombatFormula.is_critical_hit(GameState.stat_agi)
	if is_crit:
		final_dmg = int(final_dmg * 1.5)
	var dealt = target.take_damage(final_dmg, player.peer_id)
	if is_crit:
		FloatingText.spawn(player.get_parent(), target.global_position, "CRIT! %d" % dealt, Color.YELLOW, true)
