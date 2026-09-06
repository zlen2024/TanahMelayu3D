class_name ItemDatabase
extends RefCounted

# Centralized registry and factory for all game items

const ITEMS = {
	# Consumables
	"potion_hp": {
		"id": "potion_hp",
		"name": "Health Potion",
		"slot_type": "consumable",
		"rarity": "Common",
		"class_req": "any",
		"lvl_req": 1,
		"effect": {"type": "heal", "val": 60},
		"description": "Restores 60 Health Points instantly."
	},
	"potion_mp": {
		"id": "potion_mp",
		"name": "Energy Potion",
		"slot_type": "consumable",
		"rarity": "Common",
		"class_req": "any",
		"lvl_req": 1,
		"effect": {"type": "energy", "val": 50},
		"description": "Replenishes 50 Energy Points instantly."
	},
	
	# Weapons
	"sword_iron": {
		"id": "sword_iron",
		"name": "Iron Blade",
		"slot_type": "weapon",
		"rarity": "Common",
		"class_req": "warrior",
		"lvl_req": 1,
		"stats": {"atk": 8, "def": 2},
		"description": "Sturdy forged iron blade. +8 ATK, +2 DEF."
	},
	"sword_steel": {
		"id": "sword_steel",
		"name": "Knight's Claymore",
		"slot_type": "weapon",
		"rarity": "Uncommon",
		"class_req": "warrior",
		"lvl_req": 5,
		"stats": {"atk": 16, "def": 5, "hp": 30},
		"description": "Heavy tempered steel sword. +16 ATK, +5 DEF, +30 HP."
	},
	"wand_mystic": {
		"id": "wand_mystic",
		"name": "Mystic Wand",
		"slot_type": "weapon",
		"rarity": "Common",
		"class_req": "mage",
		"lvl_req": 1,
		"stats": {"atk": 10, "mp": 20},
		"description": "Infused with arcane crystals. +10 ATK, +20 Max MP."
	},
	"wand_archmage": {
		"id": "wand_archmage",
		"name": "Archmage Staff",
		"slot_type": "weapon",
		"rarity": "Rare",
		"class_req": "mage",
		"lvl_req": 6,
		"stats": {"atk": 22, "mp": 45},
		"description": "Crackling with primal magic. +22 ATK, +45 Max MP."
	},
	"bow_hunting": {
		"id": "bow_hunting",
		"name": "Hunting Bow",
		"slot_type": "weapon",
		"rarity": "Common",
		"class_req": "archer",
		"lvl_req": 1,
		"stats": {"atk": 9, "def": 1},
		"description": "Flexible yew recurve bow. +9 ATK."
	},
	"bow_composite": {
		"id": "bow_composite",
		"name": "Windforce Recurve",
		"slot_type": "weapon",
		"rarity": "Uncommon",
		"class_req": "archer",
		"lvl_req": 5,
		"stats": {"atk": 18, "def": 3},
		"description": "Lightweight wind-carved bow. +18 ATK, +3 DEF."
	},
	
	# Armor
	"armor_plate": {
		"id": "armor_plate",
		"name": "Steel Plate",
		"slot_type": "armor",
		"rarity": "Uncommon",
		"class_req": "any",
		"lvl_req": 1,
		"stats": {"def": 10, "hp": 40},
		"description": "Forged iron cuirass. +10 DEF, +40 Max HP."
	},
	"robe_cloth": {
		"id": "robe_cloth",
		"name": "Arcane Robe",
		"slot_type": "armor",
		"rarity": "Common",
		"class_req": "any",
		"lvl_req": 1,
		"stats": {"def": 4, "mp": 25},
		"description": "Silk woven with mana wards. +4 DEF, +25 Max MP."
	},
	"armor_king": {
		"id": "armor_king",
		"name": "Royal Slime Carapace",
		"slot_type": "armor",
		"rarity": "Epic",
		"class_req": "any",
		"lvl_req": 10,
		"stats": {"def": 25, "hp": 120, "mp": 30},
		"description": "Glistening crystal armor from King Slime. +25 DEF, +120 HP, +30 MP."
	},
	
	# Accessories
	"ring_vitality": {
		"id": "ring_vitality",
		"name": "Ring of Vitality",
		"slot_type": "accessory",
		"rarity": "Uncommon",
		"class_req": "any",
		"lvl_req": 1,
		"stats": {"hp": 35, "def": 3},
		"description": "Carved from emerald jade. +35 HP, +3 DEF."
	},
	"amulet_agility": {
		"id": "amulet_agility",
		"name": "Wind Amulet",
		"slot_type": "accessory",
		"rarity": "Rare",
		"class_req": "any",
		"lvl_req": 5,
		"stats": {"atk": 6, "def": 5},
		"description": "Pulsing with swift air currents. +6 ATK, +5 DEF."
	}
}

static func create_item(item_id: String, quantity: int = 1) -> Dictionary:
	if not ITEMS.has(item_id):
		return {
			"id": item_id,
			"name": item_id.capitalize(),
			"slot_type": "consumable",
			"rarity": "Common",
			"class_req": "any",
			"lvl_req": 1,
			"stats": {},
			"quantity": quantity
		}
	var template = ITEMS[item_id]
	var item = template.duplicate(true)
	item["quantity"] = quantity
	return item

static func get_rarity_color(rarity: String) -> Color:
	match rarity.to_lower():
		"uncommon":
			return Color(0.2, 0.9, 0.3) # Green
		"rare":
			return Color(0.2, 0.6, 1.0) # Blue
		"epic":
			return Color(0.8, 0.3, 1.0) # Purple
		_:
			return Color(0.85, 0.85, 0.85) # Common Gray/White

static func can_equip(item: Dictionary, hero_class: String, player_level: int) -> bool:
	if item == null or item.is_empty():
		return false
	var slot_type = str(item.get("slot_type", ""))
	if slot_type != "weapon" and slot_type != "armor" and slot_type != "accessory":
		return false
	var class_req = str(item.get("class_req", "any")).to_lower()
	if class_req != "any" and class_req != hero_class.to_lower():
		return false
	var req_lvl = int(item.get("lvl_req", 1))
	if player_level < req_lvl:
		return false
	return true
