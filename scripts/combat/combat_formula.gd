class_name CombatFormula
extends RefCounted

# Ragnarok-inspired static combat formulas and stat calculations

# Physical DEF Mitigation Formula:
# Damage = Raw_Damage * (100 / (100 + DEF))
# Examples:
#   DEF 0   -> 100% damage (no reduction)
#   DEF 50  -> 66.6% damage (33.3% reduction)
#   DEF 100 -> 50% damage (50% reduction)
static func calc_defense_mitigation(raw_damage: int, def_rating: int) -> int:
	if raw_damage <= 0:
		return 0
	var def_clamped = max(0, def_rating)
	var reduction_factor = 100.0 / (100.0 + float(def_clamped))
	var mitigated = int(round(float(raw_damage) * reduction_factor))
	return max(1, mitigated)

# Critical Hit Chance:
# Base 5% + (AGI * 0.4%)
# E.g. AGI 10 -> 9%, AGI 25 -> 15%
static func calc_crit_chance(agi: int) -> float:
	var agi_clamped = max(0, agi)
	return min(0.75, 0.05 + (float(agi_clamped) * 0.004))

static func is_critical_hit(agi: int) -> bool:
	return randf() < calc_crit_chance(agi)

# Calculate Base Stats for Hero Classes
static func calc_player_stats(hero_class: String, stat_str: int, stat_vit: int, stat_agi: int, stat_int: int, bonus_gear: Dictionary) -> Dictionary:
	var res = {
		"max_hp": 100,
		"max_energy": 50,
		"move_speed": 170.0,
		"attack_damage": 20,
		"defense": 0
	}
	
	var bonus_atk = int(bonus_gear.get("atk", 0))
	var bonus_def = int(bonus_gear.get("def", 0))
	var bonus_hp = int(bonus_gear.get("hp", 0))
	var bonus_mp = int(bonus_gear.get("mp", 0))
	
	# Base DEF scales with VIT + equipment
	res["defense"] = int(stat_vit * 0.5) + bonus_def
	
	match hero_class.to_lower():
		"warrior":
			res["max_hp"] = 60 + (stat_vit * 12) + bonus_hp
			res["max_energy"] = 30 + (stat_int * 5) + bonus_mp
			res["move_speed"] = 165.0 + (stat_agi * 2.2)
			res["attack_damage"] = 16 + int(stat_str * 2.8) + bonus_atk
		"mage":
			res["max_hp"] = 40 + (stat_vit * 8) + bonus_hp
			res["max_energy"] = 40 + (stat_int * 5) + bonus_mp
			res["move_speed"] = 155.0 + (stat_agi * 2.0)
			res["attack_damage"] = 12 + int(stat_int * 2.2) + bonus_atk
		"archer":
			res["max_hp"] = 50 + (stat_vit * 9) + bonus_hp
			res["max_energy"] = 35 + (stat_int * 5) + bonus_mp
			res["move_speed"] = 180.0 + (stat_agi * 2.6)
			res["attack_damage"] = 14 + int(stat_agi * 2.0) + int(stat_str * 1.0) + bonus_atk
		_:
			res["max_hp"] = 50 + (stat_vit * 10) + bonus_hp
			res["max_energy"] = 30 + (stat_int * 5) + bonus_mp
			res["move_speed"] = 170.0 + (stat_agi * 2.0)
			res["attack_damage"] = 15 + int(stat_str * 2.0) + bonus_atk
			
	return res

# Passive Resource Regeneration Formulas
static func calc_energy_regen(stat_int: int, bonus_mp_regen: int = 0) -> float:
	return 5.0 + (float(max(0, stat_int)) * 0.6) + float(bonus_mp_regen)

static func calc_health_regen(stat_vit: int, bonus_hp_regen: int = 0) -> float:
	return 1.0 + (float(max(0, stat_vit)) * 0.25) + float(bonus_hp_regen)

