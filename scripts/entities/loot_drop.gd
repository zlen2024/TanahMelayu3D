extends Area2D

# LootDrop: Collectible XP gem or HP potion

enum LootType { XP_GEM, HP_POTION, MP_POTION, SWORD, ARMOR, WAND, GOLD }

@export var loot_type: LootType = LootType.XP_GEM
@export var value: int = 15
var item_payload: Dictionary = {}

@onready var sprite: Sprite2D = $Sprite2D

var initial_y: float = 0.0
var time_passed: float = 0.0

func _ready():
	add_to_group("loot")
	initial_y = position.y
	body_entered.connect(_on_body_entered)
	
	match loot_type:
		LootType.XP_GEM:
			sprite.texture = preload("res://assets/sprites/gem_xp.png")
			sprite.modulate = Color(0.3, 0.9, 1.0)
		LootType.HP_POTION:
			sprite.texture = preload("res://assets/sprites/potion_hp.png")
			sprite.modulate = Color(1.0, 0.3, 0.3)
		LootType.MP_POTION:
			sprite.texture = preload("res://assets/sprites/potion_hp.png")
			sprite.modulate = Color(0.2, 0.6, 1.0)
		LootType.SWORD:
			sprite.texture = preload("res://assets/sprites/slash.png")
			sprite.modulate = Color(1.0, 0.85, 0.3)
		LootType.ARMOR:
			sprite.texture = preload("res://assets/sprites/potion_hp.png")
			sprite.modulate = Color(0.8, 0.8, 0.8)
		LootType.WAND:
			sprite.texture = preload("res://assets/sprites/projectile.png")
			sprite.modulate = Color(0.8, 0.3, 1.0)
		LootType.GOLD:
			sprite.texture = preload("res://assets/sprites/gem_xp.png")
			sprite.modulate = Color(1.0, 0.85, 0.0)

func _process(delta: float):
	time_passed += delta * 4.0
	sprite.position.y = sin(time_passed) * 3.0

func _on_body_entered(body: Node2D):
	if body.is_in_group("players"):
		if loot_type == LootType.XP_GEM:
			if body.has_method("gain_xp"):
				body.gain_xp(value)
				SoundManager.play("pickup")
				queue_free()
		else:
			var item_id = "potion_hp"
			var item_name = "Health Potion"
			var item_type = "consumable"
			
			if not item_payload.is_empty():
				item_id = item_payload.get("id", "potion_hp")
				item_name = item_payload.get("name", "Item")
				item_type = item_payload.get("slot_type", "consumable")
			else:
				match loot_type:
					LootType.HP_POTION:
						item_id = "potion_hp"; item_name = "Health Potion"; item_type = "consumable"
					LootType.MP_POTION:
						item_id = "potion_mp"; item_name = "Energy Potion"; item_type = "consumable"
					LootType.SWORD:
						item_id = "sword"; item_name = "Iron Blade (+5 STR)"; item_type = "equipment"
					LootType.ARMOR:
						item_id = "armor"; item_name = "Plate Armor (+5 VIT)"; item_type = "equipment"
					LootType.WAND:
						item_id = "wand"; item_name = "Mystic Wand (+5 INT)"; item_type = "equipment"
					LootType.GOLD:
						item_id = "gold"; item_name = "%d Gold Coins" % value; item_type = "currency"
					
			var final_payload = item_payload if not item_payload.is_empty() else {
				"id": item_id,
				"name": item_name,
				"type": item_type,
				"quantity": 1
			}
			NetworkManager.send_item_pickup(final_payload)
			if body.has_method("show_notification"):
				body.show_notification("+1 %s" % item_name, Color(0.3, 1.0, 0.5))
			SoundManager.play("pickup")
			queue_free()
