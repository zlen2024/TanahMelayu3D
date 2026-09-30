class_name Entity
extends CharacterBody2D

const FloatingText = preload("res://scripts/ui/floating_text.gd")
const CombatFormula = preload("res://scripts/combat/combat_formula.gd")

# Base Living Entity Class in Godot 4 OOP
# Shared by Player, Monsters, and NPCs

signal health_changed(current_hp, max_hp)
signal entity_died()
signal stun_state_changed(is_stunned)

@export var max_hp: int = 100
@export var current_hp: int = 100
@export var move_speed: float = 150.0
@export var defense: int = 0

var is_dead: bool = false
var is_stunned: bool = false
var stun_timer: float = 0.0

# Typed as CanvasItem because subclasses use AnimatedSprite2D here and this
# base only ever touches modulate.
@onready var entity_sprite: CanvasItem = get_node_or_null("Sprite2D")

func _ready():
	add_to_group("entities")

func process_entity_status(delta: float) -> bool:
	if is_dead:
		velocity = Vector2.ZERO
		return true
		
	if is_stunned:
		stun_timer -= delta
		velocity = Vector2.ZERO
		move_and_slide()
		if stun_timer <= 0.0:
			is_stunned = false
			emit_signal("stun_state_changed", false)
			if entity_sprite:
				entity_sprite.modulate = Color.WHITE
		return true # Interrupted / stunned
		
	return false

func take_damage(amount: int, attacker_id: int = -1) -> int:
	if is_dead:
		return 0
		
	var mitigated = CombatFormula.calc_defense_mitigation(amount, defense)
	current_hp = max(0, current_hp - mitigated)
	emit_signal("health_changed", current_hp, max_hp)
	
	play_damage_feedback(mitigated)
	
	if current_hp <= 0:
		_die(attacker_id)
		
	return mitigated

func heal(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	current_hp = min(max_hp, current_hp + amount)
	emit_signal("health_changed", current_hp, max_hp)
	var parent_node = get_parent() if get_parent() else self
	FloatingText.spawn(parent_node, global_position, "+%d" % amount, Color(0.2, 1.0, 0.4))

func apply_stun(duration: float) -> void:
	if is_dead or duration <= 0:
		return
	is_stunned = true
	stun_timer = max(stun_timer, duration)
	emit_signal("stun_state_changed", true)
	if entity_sprite:
		entity_sprite.modulate = Color(1.4, 1.4, 0.4) # Dizzy yellow
	var parent_node = get_parent() if get_parent() else self
	FloatingText.spawn(parent_node, global_position, "STUNNED!", Color(1.0, 0.8, 0.2), true)

func play_damage_feedback(amount: int) -> void:
	SoundManager.play("hit")
	var fx = get_node_or_null("CombatFX")
	if fx and fx.has_method("burst"):
		fx.burst(Vector2.ZERO, Color("ffb36b"), 22.0 if amount < 40 else 30.0, amount >= 60)
	if entity_sprite:
		var facing_left := false
		if entity_sprite is AnimatedSprite2D:
			facing_left = entity_sprite.flip_h
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(self, "position", position + Vector2(-4 if not facing_left else 4, 0), 0.04)
		tween.tween_property(entity_sprite, "scale", Vector2(1.14, 0.88), 0.04)
		tween.chain().tween_property(self, "position", position, 0.10)
		tween.chain().tween_property(entity_sprite, "scale", Vector2.ONE, 0.10)
		tween.set_parallel(false)
		tween.tween_property(entity_sprite, "modulate", Color(2.5, 0.3, 0.3), 0.08)
		tween.tween_property(entity_sprite, "modulate", Color.WHITE if not is_stunned else Color(1.4, 1.4, 0.4), 0.15)
	var parent_node = get_parent() if get_parent() else self
	FloatingText.spawn(parent_node, global_position, "-%d" % amount, Color(1.0, 0.25, 0.25))

func _die(_attacker_id: int = -1) -> void:
	is_dead = true
	emit_signal("entity_died")
