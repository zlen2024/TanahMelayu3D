class_name HeroClass
extends RefCounted

# Strategy Pattern Base for RPG Classes in Godot 4 OOP

var class_name_str: String = "warrior"

# How far a ranged class will auto-acquire a target. Beyond this the shot goes
# where the player is facing instead.
const AUTO_AIM_RANGE: float = 320.0

func get_class_name() -> String:
	return class_name_str

# Nearest living monster within AUTO_AIM_RANGE, or null.
func acquire_target(player: CharacterBody2D) -> Node2D:
	var best: Node2D = null
	var best_dist := AUTO_AIM_RANGE
	for mob in player.get_tree().get_nodes_in_group("monsters"):
		if not is_instance_valid(mob) or mob.is_queued_for_deletion() or mob.get("is_dead"):
			continue
		var d := player.global_position.distance_to(mob.global_position)
		if d < best_dist:
			best_dist = d
			best = mob
	return best

# Direction a ranged attack should travel: at the nearest target if one is in
# range, otherwise straight ahead.
func aim_dir(player: CharacterBody2D) -> Vector2:
	var target := acquire_target(player)
	if target:
		return (target.global_position - player.global_position).normalized()
	return player.facing_dir

# Virtual methods to be overridden by concrete classes
func execute_basic_attack(_player: CharacterBody2D) -> void:
	pass

func execute_charged_attack(_player: CharacterBody2D) -> void:
	pass

func execute_skill(_player: CharacterBody2D, _idx: int) -> bool:
	return false

# Factory method to instantiate the concrete class strategy
static func create(class_type: String) -> HeroClass:
	match class_type.to_lower():
		"mage":
			var script = load("res://scripts/classes/mage_class.gd")
			return script.new()
		"archer":
			var script = load("res://scripts/classes/archer_class.gd")
			return script.new()
		_:
			var script = load("res://scripts/classes/warrior_class.gd")
			return script.new()
