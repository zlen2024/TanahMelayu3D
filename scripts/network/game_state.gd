extends Node

# GameState Autoload
# Keeps track of connected players, global state, levels, and chat

signal player_registered(peer_id, info)
signal player_unregistered(peer_id)
signal chat_received(sender_name, text, is_system)
signal player_stat_changed(peer_id, stat_name, new_val)
signal system_banner(text)
signal auth_succeeded(user_data, char_data)
signal auth_failed(error_message)
signal inventory_updated(items)
signal stats_updated()
signal equipped_gear_updated(gear)
signal quick_slots_updated(slots)
signal pk_mode_changed(enabled)

var local_peer_id: int = 1
var local_player_name: String = "Hero"
var selected_skin_index: int = 0
var user_id: int = 0
var hero_class: String = "warrior"

# Core RPG Stats
var stat_str: int = 10
var stat_vit: int = 10
var stat_agi: int = 10
var stat_int: int = 10
var unspent_stat_points: int = 0

# Energy, Stamina & Health Pools
var current_energy: int = 80
var max_energy: int = 80
var current_stamina: float = 100.0
var max_stamina: float = 100.0

# PK Mode (Lv 10+)
var is_pk_enabled: bool = false

# Equipment Paperdoll & Quick Access
var equipped_gear: Dictionary = {
	"weapon": null,
	"armor": null,
	"accessory": null
}
var quick_slots: Array = [null, null]

# UI Focus Management (Locks input while menus are open)
var ui_modal_open_count: int = 0

# 16-slot inventory
var inventory: Array = []

var players: Dictionary = {}

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	inventory.resize(16)
	for i in range(16):
		inventory[i] = null

func init_inventory(items_array: Array) -> void:
	inventory.clear()
	inventory.resize(16)
	for i in range(16):
		inventory[i] = null
	for item in items_array:
		if item != null and item is Dictionary and item.has("slot"):
			var slot = int(item["slot"])
			if slot >= 0 and slot < 16:
				inventory[slot] = item
	emit_signal("inventory_updated", inventory)

func load_character_stats(data: Dictionary) -> void:
	hero_class = str(data.get("class_type", "warrior")).to_lower()
	stat_str = int(data.get("str", 10))
	stat_vit = int(data.get("vit", 10))
	stat_agi = int(data.get("agi", 10))
	stat_int = int(data.get("int", 10))
	unspent_stat_points = int(data.get("stat_points", 0))
	max_energy = int(data.get("max_energy", 30 + (stat_int * 5)))
	current_energy = int(data.get("energy", max_energy))
	emit_signal("stats_updated")

func register_local_player(peer_id: int, p_name: String, skin_idx: int) -> void:
	local_peer_id = peer_id
	local_player_name = p_name
	selected_skin_index = skin_idx

@rpc("any_peer", "call_local", "reliable")
func register_player_info(peer_id: int, p_name: String, skin_idx: int, level: int = 1, hp: int = 100, max_hp: int = 100) -> void:
	players[peer_id] = {
		"name": p_name,
		"skin": skin_idx,
		"level": level,
		"hp": hp,
		"max_hp": max_hp,
		"xp": 0
	}
	emit_signal("player_registered", peer_id, players[peer_id])
	print("[GameState] Registered player: ", p_name, " (Peer ID: ", peer_id, ")")

@rpc("any_peer", "call_local", "reliable")
func unregister_player(peer_id: int) -> void:
	if players.has(peer_id):
		var p_name = players[peer_id]["name"]
		players.erase(peer_id)
		emit_signal("player_unregistered", peer_id)
		emit_signal("chat_received", "SYSTEM", "%s has left the game." % p_name, true)

@rpc("any_peer", "call_local", "reliable")
func send_chat(sender_name: String, message_text: String, is_system: bool = false) -> void:
	emit_signal("chat_received", sender_name, message_text, is_system)

@rpc("any_peer", "call_local", "reliable")
func sync_player_stat(peer_id: int, stat_name: String, value: Variant) -> void:
	if players.has(peer_id):
		players[peer_id][stat_name] = value
		emit_signal("player_stat_changed", peer_id, stat_name, value)

func get_player_name(peer_id: int) -> String:
	if players.has(peer_id):
		return players[peer_id].get("name", "Player %d" % peer_id)
	return "Player %d" % peer_id

func get_player_info(peer_id: int) -> Dictionary:
	return players.get(peer_id, {})

# UI Focus Management
func set_ui_modal_open(is_open: bool) -> void:
	if is_open:
		ui_modal_open_count += 1
	else:
		ui_modal_open_count = max(0, ui_modal_open_count - 1)

func is_ui_focused() -> bool:
	return ui_modal_open_count > 0

# Equipment Management
func get_equipment_bonus(stat_name: String) -> int:
	var total = 0
	for slot_key in ["weapon", "armor", "accessory"]:
		var item = equipped_gear.get(slot_key)
		if item != null and item is Dictionary:
			var stats = item.get("stats", {})
			total += int(stats.get(stat_name, 0))
	return total

func equip_item(slot_idx: int, player_level: int = 1) -> bool:
	if slot_idx < 0 or slot_idx >= inventory.size():
		return false
	var item = inventory[slot_idx]
	if item == null or not (item is Dictionary):
		return false
	
	var slot_type = str(item.get("slot_type", "")).to_lower()
	if not equipped_gear.has(slot_type):
		return false
		
	# Class requirement check
	var class_req = str(item.get("class_req", "any")).to_lower()
	if class_req != "any" and class_req != hero_class:
		return false
		
	# Level requirement check
	var req_lvl = int(item.get("lvl_req", 1))
	if player_level < req_lvl:
		return false
		
	var old_item = equipped_gear[slot_type]
	equipped_gear[slot_type] = item
	inventory[slot_idx] = old_item
	
	emit_signal("equipped_gear_updated", equipped_gear)
	emit_signal("inventory_updated", inventory)
	emit_signal("stats_updated")
	return true

func unequip_slot(slot_type: String) -> bool:
	if not equipped_gear.has(slot_type) or equipped_gear[slot_type] == null:
		return false
		
	# Find free inventory slot
	var free_slot = -1
	for i in range(inventory.size()):
		if inventory[i] == null:
			free_slot = i
			break
	if free_slot == -1:
		return false # Bag full
		
	inventory[free_slot] = equipped_gear[slot_type]
	equipped_gear[slot_type] = null
	
	emit_signal("equipped_gear_updated", equipped_gear)
	emit_signal("inventory_updated", inventory)
	emit_signal("stats_updated")
	return true

# Quick Slots (Hotkeys Q and E)
func assign_quick_slot(quick_idx: int, inv_slot_idx: int) -> void:
	if quick_idx < 0 or quick_idx >= quick_slots.size():
		return
	if inv_slot_idx < 0 or inv_slot_idx >= inventory.size():
		quick_slots[quick_idx] = null
	else:
		quick_slots[quick_idx] = inventory[inv_slot_idx]
	emit_signal("quick_slots_updated", quick_slots)

func use_quick_slot(quick_idx: int) -> void:
	if quick_idx < 0 or quick_idx >= quick_slots.size():
		return
	var item = quick_slots[quick_idx]
	if item == null:
		return
	var item_id = item.get("id", "")
	# Find item in inventory
	for i in range(inventory.size()):
		var it = inventory[i]
		if it != null and it.get("id", "") == item_id:
			NetworkManager.send_item_use(i)
			return

# PK Mode (Level 10+)
func toggle_pk_mode(player_level: int) -> bool:
	if player_level < 10:
		return false
	is_pk_enabled = not is_pk_enabled
	emit_signal("pk_mode_changed", is_pk_enabled)
	NetworkManager.send_packet({
		"type": "pk_toggle",
		"enabled": is_pk_enabled
	})
	return is_pk_enabled

