extends Node

# NetworkManager Autoload
# Uses WebSocketPeer for universal web browser & native compatibility.
# Features Host Authority election for monster AI synchronization and live stat syncing.

signal connection_succeeded
signal connection_failed_event
signal server_disconnected_event
signal peer_connected_event(id)
signal peer_disconnected_event(id)
signal match_started

const DEFAULT_PORT: int = 8080
const DEFAULT_HOST: String = "127.0.0.1"

var socket: WebSocketPeer = null
var is_connected_to_server: bool = false
var was_connected: bool = false
var is_solo_mode: bool = false
var is_room_host: bool = false
var local_id: int = 1

var monster_sync_timer: float = 0.0

var player_scene = preload("res://scenes/player.tscn")

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float):
	if socket == null or is_solo_mode:
		return
		
	socket.poll()
	var state = socket.get_ready_state()
	
	if state == WebSocketPeer.STATE_OPEN:
		if not is_connected_to_server:
			is_connected_to_server = true
			was_connected = true
			print("[NetworkManager] WebSocket connection opened successfully!")
			emit_signal("connection_succeeded")
			emit_signal("match_started")
			
		while socket.get_available_packet_count() > 0:
			var raw_packet = socket.get_packet().get_string_from_utf8()
			var msg = JSON.parse_string(raw_packet)
			if msg is Dictionary:
				_handle_network_message(msg)
				
		# Host broadcasts authoritative monster state at 10Hz
		if is_room_host:
			monster_sync_timer -= delta
			if monster_sync_timer <= 0:
				monster_sync_timer = 0.1
				_broadcast_monsters_state()
				
	elif state == WebSocketPeer.STATE_CLOSED:
		if was_connected:
			print("[NetworkManager] WebSocket disconnected by server (code: %d, reason: %s)" % [socket.get_close_code(), socket.get_close_reason()])
			is_connected_to_server = false
			was_connected = false
			is_room_host = false
			emit_signal("server_disconnected_event")
		elif socket != null:
			print("[NetworkManager] Connection failed to open.")
			is_connected_to_server = false
			is_room_host = false
			emit_signal("connection_failed_event")
			socket = null

func start_client(url: String) -> Error:
	is_solo_mode = false
	url = url.strip_edges()
	while url.ends_with("/"):
		url = url.substr(0, url.length() - 1)
		
	if not url.begins_with("ws://") and not url.begins_with("wss://"):
		if url.contains(":"):
			url = "ws://" + url
		else:
			url = "ws://" + url + ":8080"
			
	print("[NetworkManager] Connecting WebSocket to %s ..." % url)
	socket = WebSocketPeer.new()
	var err = socket.connect_to_url(url)
	if err != OK:
		print("[NetworkManager] Error connecting to %s: %d" % [url, err])
		emit_signal("connection_failed_event")
		return err
	return OK

func start_solo():
	is_solo_mode = true
	is_room_host = true
	local_id = 1
	GameState.register_local_player(1, GameState.local_player_name, GameState.selected_skin_index)
	GameState.register_player_info(1, GameState.local_player_name, GameState.selected_skin_index)
	emit_signal("connection_succeeded")
	emit_signal("match_started")
	spawn_player_node(1, GameState.local_player_name, GameState.selected_skin_index, Vector2.ZERO, true)

func disconnect_network():
	if socket:
		socket.close()
		socket = null
	is_connected_to_server = false
	was_connected = false
	is_solo_mode = false
	is_room_host = false
	GameState.players.clear()
	
	var world = get_tree().root.find_child("World", true, false)
	if world:
		var players_container = world.find_child("Players", true, false)
		if players_container:
			for child in players_container.get_children():
				child.queue_free()

func send_packet(dict: Dictionary):
	if socket and socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(JSON.stringify(dict))

func _broadcast_monsters_state():
	var world = get_tree().root.find_child("World", true, false)
	if not world:
		return
	var monsters = world.find_child("Monsters", true, false)
	if not monsters:
		return
		
	var mob_data = []
	for i in range(monsters.get_child_count()):
		var mob = monsters.get_child(i)
		# Stable id, not the child index: an index shifts under any runtime
		# spawn and silently retargets every later monster.
		mob_data.append({
			"id": mob.monster_id,
			"pos": [round(mob.global_position.x), round(mob.global_position.y)],
			"flip": mob.sprite.flip_h if mob.get("sprite") else false,
			"hp": mob.current_health,
			"dead": mob.is_dead
		})
		
	send_packet({
		"type": "monsters_sync",
		"monsters": mob_data
	})

func _handle_network_message(msg: Dictionary):
	var mtype = msg.get("type", "")
	match mtype:
		"welcome":
			local_id = int(msg.get("id", 1))
			is_room_host = bool(msg.get("is_host", false))
			print("[NetworkManager] Welcome received! Assigned ID: %d, Host: %s" % [local_id, is_room_host])

		"auth_success":
			var u_data = msg.get("user", {})
			var c_data = msg.get("character", {})
			var inv_data = msg.get("inventory", [])
			GameState.user_id = int(u_data.get("id", 0))
			GameState.local_player_name = str(c_data.get("name", "Hero"))
			GameState.selected_skin_index = int(c_data.get("skin", 0))
			GameState.load_character_stats(c_data)
			GameState.init_inventory(inv_data)
			
			GameState.register_local_player(local_id, GameState.local_player_name, GameState.selected_skin_index)
			GameState.register_player_info(local_id, GameState.local_player_name, GameState.selected_skin_index, int(c_data.get("level", 1)), int(c_data.get("hp", 150)), int(c_data.get("max_hp", 150)))
			
			var spawn_pos = Vector2(randf_range(-80, 80), randf_range(-80, 80))
			spawn_player_node(local_id, GameState.local_player_name, GameState.selected_skin_index, spawn_pos, true, int(c_data.get("level", 1)), int(c_data.get("hp", 150)), int(c_data.get("max_hp", 150)))
			
			send_packet({
				"type": "player_join",
				"id": local_id,
				"name": GameState.local_player_name,
				"skin": GameState.selected_skin_index,
				"pos": [spawn_pos.x, spawn_pos.y],
				"hp": int(c_data.get("hp", 150)),
				"max_hp": int(c_data.get("max_hp", 150)),
				"level": int(c_data.get("level", 1))
			})
			
			GameState.emit_signal("auth_succeeded", u_data, c_data)

		"error_msg":
			# Previously unhandled: failed stat allocation and failed item pickup
			# both fail silently in the UI without this.
			GameState.emit_signal("chat_received", "SYSTEM", str(msg.get("text", "Action failed.")), true)

		"auth_error":
			var err_msg = msg.get("error", "Authentication failed.")
			GameState.emit_signal("auth_failed", err_msg)

		"stat_allocated":
			var c_data = msg.get("character", {})
			GameState.load_character_stats(c_data)
			var world = get_tree().root.find_child("World", true, false)
			if world:
				var players_node = world.find_child("Players", true, false)
				if players_node and players_node.has_node(str(local_id)):
					var pnode = players_node.get_node(str(local_id))
					pnode.recalculate_stats()

		"inventory_sync":
			var inv = msg.get("inventory", [])
			GameState.init_inventory(inv)

		"item_used":
			var inv = msg.get("inventory", [])
			GameState.init_inventory(inv)
			var item_id = msg.get("item_id", "")
			_apply_item_effect(item_id)

		"host_promoted":
			is_room_host = true
			print("[NetworkManager] Promoted to Host Authority for synchronized monsters!")

		"host_revoked":
			# Sent when a client that never entered the world was holding authority.
			# Without this the old host keeps broadcasting monsters_sync and fights
			# the new host over monster state.
			is_room_host = false
			print("[NetworkManager] Host Authority revoked; following the new host.")

		"existing_players":
			var existing = msg.get("players", [])
			for p in existing:
				var pid = int(p.get("id", 0))
				if pid != local_id and pid > 0:
					var p_name = p.get("name", "Hero")
					var p_skin = int(p.get("skin", 0))
					var pos_arr = p.get("pos", [0, 0])
					var pos = Vector2(pos_arr[0], pos_arr[1])
					var p_lvl = int(p.get("level", 1))
					var p_hp = int(p.get("hp", 100))
					var p_max_hp = int(p.get("max_hp", 100))
					
					GameState.register_player_info(pid, p_name, p_skin, p_lvl, p_hp, p_max_hp)
					spawn_player_node(pid, p_name, p_skin, pos, false, p_lvl, p_hp, p_max_hp)

		"player_join":
			var pid = int(msg.get("id", 0))
			if pid != local_id and pid > 0:
				var p_name = msg.get("name", "Hero")
				var p_skin = int(msg.get("skin", 0))
				var pos_arr = msg.get("pos", [0, 0])
				var pos = Vector2(pos_arr[0], pos_arr[1])
				var p_lvl = int(msg.get("level", 1))
				var p_hp = int(msg.get("hp", 100))
				var p_max_hp = int(msg.get("max_hp", 100))
				
				GameState.register_player_info(pid, p_name, p_skin, p_lvl, p_hp, p_max_hp)
				spawn_player_node(pid, p_name, p_skin, pos, false, p_lvl, p_hp, p_max_hp)
				GameState.emit_signal("chat_received", "SYSTEM", "%s (Lv.%d) entered the realm!" % [p_name, p_lvl], true)
				
				# Host sends immediate monster state sync to new player
				if is_room_host:
					_broadcast_monsters_state()

		"player_leave":
			var pid = int(msg.get("id", 0))
			if pid > 0:
				GameState.unregister_player(pid)
				despawn_player_node(pid)

		"move":
			var pid = int(msg.get("id", 0))
			if pid != local_id:
				var pos_arr = msg.get("pos", [0, 0])
				var flip = msg.get("flip", false)
				var world = get_tree().root.find_child("World", true, false)
				if world:
					var players_node = world.find_child("Players", true, false)
					if players_node and players_node.has_node(str(pid)):
						var pnode = players_node.get_node(str(pid))
						pnode.set_network_transform(Vector2(pos_arr[0], pos_arr[1]), flip)

		"stat_sync":
			var pid = int(msg.get("id", 0))
			var stat_name = msg.get("stat", "")
			var val = msg.get("val")
			if pid != local_id and pid > 0:
				GameState.sync_player_stat(pid, stat_name, val)
				var world = get_tree().root.find_child("World", true, false)
				if world:
					var players_node = world.find_child("Players", true, false)
					if players_node and players_node.has_node(str(pid)):
						var pnode = players_node.get_node(str(pid))
						if stat_name == "level":
							pnode.level = int(val)
							pnode._update_nameplate()
						elif stat_name == "hp":
							pnode.current_hp = int(val)
							pnode._update_hp_bar()
						elif stat_name == "max_hp":
							pnode.max_hp = int(val)
							pnode._update_hp_bar()

		"monsters_sync":
			if not is_room_host:
				var m_data = msg.get("monsters", [])
				var world = get_tree().root.find_child("World", true, false)
				if world:
					var monsters = world.find_child("Monsters", true, false)
					if monsters:
						for m_info in m_data:
							var mob = world.find_monster(int(m_info.get("id", -1)))
							if mob:
								if mob.has_method("apply_sync_state"):
									var pos_arr = m_info.get("pos", [0, 0])
									mob.apply_sync_state(
										Vector2(pos_arr[0], pos_arr[1]),
										bool(m_info.get("flip", false)),
										int(m_info.get("hp", 60)),
										bool(m_info.get("dead", false))
									)

		"attack":
			var pid = int(msg.get("id", 0))
			if pid != local_id:
				var world = get_tree().root.find_child("World", true, false)
				if world:
					var players_node = world.find_child("Players", true, false)
					if players_node and players_node.has_node(str(pid)):
						var pnode = players_node.get_node(str(pid))
						pnode.play_slash_effect()
				if msg.get("spell", false):
					var pos_arr = msg.get("pos", [0, 0])
					var dir_arr = msg.get("dir", [1, 0])
					_spawn_projectile(Vector2(pos_arr[0], pos_arr[1]), Vector2(dir_arr[0], dir_arr[1]), pid)

		"chat":
			var sender = msg.get("sender", "Hero")
			var text = msg.get("text", "")
			var is_sys = msg.get("is_sys", false)
			GameState.emit_signal("chat_received", sender, text, is_sys)

		"monster_hit":
			var mob_id = int(msg.get("mob_id", -1))
			var damage = int(msg.get("damage", 10))
			var attacker = int(msg.get("attacker", 0))
			var world = get_tree().root.find_child("World", true, false)
			if world:
				var mob = world.find_monster(mob_id)
				if mob and mob.has_method("apply_damage_from_network"):
					mob.apply_damage_from_network(damage, attacker)

func spawn_player_node(peer_id: int, p_name: String, skin_idx: int, pos: Vector2, is_local_player: bool, p_level: int = 1, p_hp: int = 100, p_max_hp: int = 100) -> void:
	var world = get_tree().root.find_child("World", true, false)
	if not world:
		return
	var players_container = world.find_child("Players", true, false)
	if not players_container:
		return
		
	if players_container.has_node(str(peer_id)):
		var existing_node = players_container.get_node(str(peer_id))
		existing_node.level = p_level
		existing_node.current_hp = p_hp
		existing_node.max_hp = p_max_hp
		existing_node._update_nameplate()
		existing_node._update_hp_bar()
		return
		
	var player_instance = player_scene.instantiate()
	player_instance.name = str(peer_id)
	player_instance.peer_id = peer_id
	player_instance.player_name = p_name
	player_instance.skin_index = skin_idx
	player_instance.is_local = is_local_player
	player_instance.level = p_level
	player_instance.current_hp = p_hp
	player_instance.max_hp = p_max_hp
	player_instance.global_position = pos
	players_container.add_child(player_instance)
	print("[NetworkManager] Spawned player node for ID: %d (local: %s, Lv.%d)" % [peer_id, is_local_player, p_level])

func despawn_player_node(peer_id: int) -> void:
	var world = get_tree().root.find_child("World", true, false)
	if not world:
		return
	var players_container = world.find_child("Players", true, false)
	if players_container and players_container.has_node(str(peer_id)):
		players_container.get_node(str(peer_id)).queue_free()
		print("[NetworkManager] Despawned player node for ID: %d" % peer_id)

func _spawn_projectile(pos: Vector2, dir: Vector2, shooter: int, damage: int = -1, max_range: float = -1.0):
	var proj_scene = preload("res://scenes/projectile.tscn")
	var proj = proj_scene.instantiate()
	proj.shooter_id = shooter
	proj.direction = dir
	proj.global_position = pos
	# Defaults are kept for remote "attack" packets, which carry neither value.
	if damage > 0:
		proj.damage = damage
	if max_range > 0.0:
		proj.lifetime = max_range / proj.speed
	var world = get_tree().root.find_child("World", true, false)
	if world:
		world.add_child(proj)

func _get_class_for_skin(skin_idx: int) -> String:
	match skin_idx:
		1: return "mage"
		2: return "archer"
		_: return "warrior"

func start_guest(class_type: String = "warrior"):
	is_solo_mode = true
	is_room_host = true
	local_id = 1
	GameState.hero_class = class_type
	var base_stats = {
		"warrior": {"str": 14, "vit": 12, "agi": 9, "int": 5, "hp": 180, "max_hp": 180, "energy": 60, "max_energy": 60, "skin": 0},
		"mage": {"str": 5, "vit": 8, "agi": 9, "int": 16, "hp": 120, "max_hp": 120, "energy": 120, "max_energy": 120, "skin": 1},
		"archer": {"str": 10, "vit": 10, "agi": 15, "int": 7, "hp": 140, "max_hp": 140, "energy": 80, "max_energy": 80, "skin": 2}
	}
	var st = base_stats.get(class_type, base_stats["warrior"])
	GameState.selected_skin_index = st["skin"]
	GameState.load_character_stats({
		"class_type": class_type,
		"str": st["str"], "vit": st["vit"], "agi": st["agi"], "int": st["int"],
		"hp": st["hp"], "max_hp": st["max_hp"], "energy": st["energy"], "max_energy": st["max_energy"],
		"stat_points": 0
	})
	GameState.init_inventory([
		{"slot": 0, "id": "potion_hp", "name": "Health Potion", "type": "consumable", "quantity": 3},
		{"slot": 1, "id": "potion_mp", "name": "Energy Potion", "type": "consumable", "quantity": 2}
	])
	GameState.register_local_player(1, GameState.local_player_name, st["skin"])
	GameState.register_player_info(1, GameState.local_player_name, st["skin"], 1, st["hp"], st["max_hp"])
	emit_signal("connection_succeeded")
	emit_signal("match_started")
	spawn_player_node(1, GameState.local_player_name, st["skin"], Vector2.ZERO, true, 1, st["hp"], st["max_hp"])
	GameState.emit_signal("auth_succeeded", {"id": 1, "username": GameState.local_player_name}, {"name": GameState.local_player_name, "class_type": class_type})

func send_register(u: String, p: String, class_type: String = "warrior", skin: int = 0):
	send_packet({
		"type": "register",
		"username": u,
		"password": p,
		"class_type": class_type,
		"skin": skin
	})

func send_login(u: String, p: String):
	send_packet({
		"type": "login",
		"username": u,
		"password": p
	})

func send_allocate_stat(stat_name: String):
	if is_solo_mode:
		if GameState.unspent_stat_points > 0:
			GameState.unspent_stat_points -= 1
			if stat_name == "str": GameState.stat_str += 1
			elif stat_name == "vit":
				GameState.stat_vit += 1
				GameState.current_energy = GameState.current_energy
			elif stat_name == "agi": GameState.stat_agi += 1
			elif stat_name == "int":
				GameState.stat_int += 1
				GameState.max_energy = 30 + (GameState.stat_int * 5)
			GameState.emit_signal("stats_updated")
			var world = get_tree().root.find_child("World", true, false)
			if world:
				var players_node = world.find_child("Players", true, false)
				if players_node and players_node.has_node(str(local_id)):
					players_node.get_node(str(local_id)).recalculate_stats()
	else:
		send_packet({
			"type": "stat_allocate",
			"stat": stat_name
		})

func send_item_pickup(item_dict: Dictionary):
	if is_solo_mode:
		var placed = false
		for i in range(GameState.inventory.size()):
			var existing = GameState.inventory[i]
			if existing != null and existing.get("id") == item_dict.get("id") and (existing.get("type") == "consumable" or existing.get("type") == "currency"):
				existing["quantity"] = existing.get("quantity", 1) + item_dict.get("quantity", 1)
				placed = true
				break
		if not placed:
			for i in range(GameState.inventory.size()):
				if GameState.inventory[i] == null:
					GameState.inventory[i] = item_dict
					GameState.inventory[i]["slot"] = i
					placed = true
					break
		if placed:
			GameState.emit_signal("inventory_updated", GameState.inventory)
	else:
		send_packet({
			"type": "item_pickup",
			"item": item_dict
		})

func send_item_use(slot_idx: int):
	if is_solo_mode:
		if slot_idx >= 0 and slot_idx < GameState.inventory.size():
			var it = GameState.inventory[slot_idx]
			if it != null:
				_apply_item_effect(it.get("id", ""))
				if it.get("quantity", 1) > 1:
					it["quantity"] -= 1
				else:
					GameState.inventory[slot_idx] = null
				GameState.emit_signal("inventory_updated", GameState.inventory)
	else:
		send_packet({
			"type": "item_use",
			"slot": slot_idx
		})

func _apply_item_effect(item_id: String):
	var pnode = null
	for p in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(p) or p.is_queued_for_deletion():
			continue
		if p.peer_id == local_id or p.name == str(local_id) or p.is_local:
			pnode = p
			if p.peer_id == local_id or p.name == str(local_id):
				break
	if not pnode:
		var world = get_tree().root.find_child("World", true, false)
		if world:
			var players_node = world.find_child("Players", true, false)
			if players_node and players_node.has_node(str(local_id)):
				pnode = players_node.get_node(str(local_id))
	if not pnode:
		return
	if item_id == "potion_hp":
		pnode.heal(60)
		SoundManager.play("levelup")
	elif item_id == "potion_mp":
		pnode.restore_energy(50)
		SoundManager.play("levelup")
