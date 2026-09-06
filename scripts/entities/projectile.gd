extends Area2D

# Projectile spell / arrow fired by a player

@export var speed: float = 380.0
@export var damage: int = 25
@export var lifetime: float = 1.5
@export var is_piercing: bool = false
@export var causes_stun: bool = false
@export var stun_duration: float = 1.5

var direction: Vector2 = Vector2.RIGHT
var shooter_id: int = 1
var hit_targets: Array = []

func _ready():
	monitoring = true
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	var timer = get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)

func _physics_process(delta: float):
	position += direction * speed * delta

func _on_body_entered(body: Node2D):
	_handle_hit(body)

func _on_area_entered(area: Area2D):
	_handle_hit(area.get_parent())

func _handle_hit(target: Node2D):
	if target == null:
		return
	
	# Don't hit self
	if target.is_in_group("players") and target.get("peer_id") == shooter_id:
		return
		
	if hit_targets.has(target):
		return
	hit_targets.append(target)
		
	# Check if monster
	if target.is_in_group("monsters") and target.has_method("take_damage"):
		target.take_damage(damage, shooter_id)
		if causes_stun and target.has_method("apply_stun"):
			target.apply_stun(stun_duration)
		SoundManager.play("hit")
		if not is_piercing:
			queue_free()
	# Check if another player (PvP enabled)
	elif target.is_in_group("players") and target.has_method("take_damage"):
		target.take_damage(damage, shooter_id)
		SoundManager.play("hit")
		if not is_piercing:
			queue_free()
	elif target.is_in_group("obstacles"):
		queue_free()
