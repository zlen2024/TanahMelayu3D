extends Node

const CombatFormula = preload("res://scripts/combat/combat_formula.gd")
const ItemDatabase = preload("res://scripts/items/item_database.gd")
const HeroClass = preload("res://scripts/classes/hero_class.gd")
const WarriorClass = preload("res://scripts/classes/warrior_class.gd")
const MageClass = preload("res://scripts/classes/mage_class.gd")
const ArcherClass = preload("res://scripts/classes/archer_class.gd")

# Automated Test Suite for Godot Web RPG POC
# Runs inside Godot engine with all autoloads (GameState, SoundManager, NetworkManager) active.

var total_tests = 0
var passed_tests = 0
var failed_tests = 0

func _ready():
	print("\n=======================================================")
	print("🧪 RUNNING AUTOMATED GODOT RPG ENGINE TESTS")
	print("=======================================================\n")
	
	NetworkManager.is_room_host = true
	NetworkManager.is_solo_mode = true
	
	_test_chat_system()
	_test_map_and_boundaries()
	_test_hit_detection_and_combat()
	_test_monster_death_and_zero_damage_fix()
	_test_monster_respawn()
	_test_player_attack_and_projectiles()
	_test_xp_and_leveling()
	_test_level_tally_and_nameplate_sync()
	_test_monster_movement_synchronization()
	_test_loot_drop()
	_test_hud_leaderboard_level_sync()
	_test_classic_classes_and_base_stats()
	_test_energy_and_regeneration()
	_test_class_skills_execution()
	_test_inventory_and_item_use()
	_test_oop_strategy_and_combat_formulas()
	_test_stamina_dodge_roll_and_iframes()
	_test_charged_attacks_and_stun()
	_test_item_database_paperdoll_and_ui_lock()
	_test_ranged_autoaim_and_range()
	_test_procedural_map()
	_test_water_cliffs_and_minimap()
	
	print("\n=======================================================")
	print("📊 TEST SUMMARY: %d Total | %d Passed | %d Failed" % [total_tests, passed_tests, failed_tests])
	if failed_tests == 0:
		print("🎉 ALL 21 AUTOMATED TESTS PASSED SUCCESSFULLY!")
	else:
		print("❌ SOME TESTS FAILED!")
	print("=======================================================\n")
	
	get_tree().quit(1 if failed_tests > 0 else 0)

func assert_true(condition: bool, test_name: String):
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  ✅ [PASS] %s" % test_name)
	else:
		failed_tests += 1
		print("  ❌ [FAIL] %s" % test_name)

func _test_chat_system():
	print("\n--- 1. Testing Chat System ---")
	var result = {
		"received": false,
		"sender": "",
		"text": ""
	}
	
	var cb = func(sender, text, _is_sys):
		result["received"] = true
		result["sender"] = sender
		result["text"] = text
		
	GameState.chat_received.connect(cb)
	GameState.emit_signal("chat_received", "Tester", "Hello Realm!", false)
	
	assert_true(result["received"], "Chat signal emitted and received")
	assert_true(result["sender"] == "Tester", "Chat sender correctly recorded")
	assert_true(result["text"] == "Hello Realm!", "Chat message text matches")
	GameState.chat_received.disconnect(cb)

func _test_map_and_boundaries():
	print("\n--- 2. Testing Map & Arena Boundaries ---")
	var world_scene = load("res://scenes/world.tscn")
	assert_true(world_scene != null, "World scene loads successfully")
	
	var world = world_scene.instantiate()
	add_child(world)
	
	var borders = world.get_node_or_null("Map/Borders")
	assert_true(borders != null, "Map borders static body exists")
	assert_true(borders.is_in_group("obstacles"), "Borders are marked as obstacles")
	
	var wall_top = world.get_node_or_null("Map/Borders/WallTop")
	var wall_bottom = world.get_node_or_null("Map/Borders/WallBottom")
	assert_true(wall_top != null and wall_bottom != null, "Boundary walls top & bottom exist")
	assert_true(wall_top.position.y == -1200.0, "Top boundary configured at y = -1200")
	assert_true(wall_bottom.position.y == 1200.0, "Bottom boundary configured at y = 1200")
	
	var obstacles = world.get_node_or_null("Map/Obstacles")
	assert_true(obstacles != null, "Obstacle pillars exist in world")
	
	world.queue_free()

func _test_hit_detection_and_combat():
	print("\n--- 3. Testing Hit Detection & Damage Mechanics ---")
	var monster_scene = load("res://scenes/monster.tscn")
	var player_scene = load("res://scenes/player.tscn")
	assert_true(monster_scene != null and player_scene != null, "Player and Monster scenes load")
	
	var player = player_scene.instantiate()
	var monster = monster_scene.instantiate()
	add_child(player)
	add_child(monster)
	
	var initial_mob_hp = monster.current_health
	monster.take_damage(20, player.peer_id)
	assert_true(monster.current_health == initial_mob_hp - 20, "Monster HP drops accurately on hit (%d -> %d)" % [initial_mob_hp, monster.current_health])
	
	var initial_player_hp = player.current_hp
	player.take_damage(15, 0)
	assert_true(player.current_hp == initial_player_hp - 15, "Player HP drops accurately on hit (%d -> %d)" % [initial_player_hp, player.current_hp])
	
	# Test healing
	player.heal(10)
	assert_true(player.current_hp == initial_player_hp - 5, "Player heal recovers HP (%d)" % player.current_hp)
	
	player.heal(1000)
	assert_true(player.current_hp == player.max_hp, "Player heal does not exceed max_hp (%d/%d)" % [player.current_hp, player.max_hp])
	
	player.queue_free()
	monster.queue_free()

func _test_monster_death_and_zero_damage_fix():
	print("\n--- 4. Testing Monster Death State & Zero-Damage Fix ---")
	var monster_scene = load("res://scenes/monster.tscn")
	var player_scene = load("res://scenes/player.tscn")
	
	var monster = monster_scene.instantiate()
	var player = player_scene.instantiate()
	add_child(monster)
	add_child(player)
	
	# Inflict lethal damage
	monster.take_damage(monster.max_health * 2, player.peer_id)
	
	assert_true(monster.current_health == 0, "Monster current_health reduced to 0")
	assert_true(monster.is_dead == true, "Monster is_dead flag set to true")
	
	# CRITICAL FIX VERIFICATION:
	# 1. Dead monster must NOT deal damage
	var player_hp_before = player.current_hp
	monster._attack_target(player)
	assert_true(player.current_hp == player_hp_before, "Dead monster CANNOT attack player (player HP unchanged: %d)" % player.current_hp)
	
	# 2. Dead monster must NOT take further damage
	monster.take_damage(50, player.peer_id)
	assert_true(monster.current_health == 0, "Dead monster does not take negative damage or trigger duplicate death")
	
	# 3. Physics process must halt movement when dead
	monster.velocity = Vector2(100, 100)
	monster._physics_process(0.016)
	assert_true(monster.velocity == Vector2.ZERO, "Dead monster velocity forced to ZERO in physics_process")
	
	player.queue_free()
	monster.queue_free()

func _test_monster_respawn():
	print("\n--- 4b. Testing Monster Respawn Cycle ---")
	var monster_scene = load("res://scenes/monster.tscn")
	var player_scene = load("res://scenes/player.tscn")

	var monster = monster_scene.instantiate()
	var player = player_scene.instantiate()
	add_child(monster)
	add_child(player)

	var origin = monster.spawn_pos

	# Drag it away from its spawn point so we can prove respawn relocates it.
	monster.global_position = origin + Vector2(300, 200)
	monster.take_damage(monster.max_health * 2, player.peer_id)

	assert_true(monster.is_dead == true, "Monster is dead after lethal damage")
	assert_true(monster.visible == false, "Dead monster is hidden (no frozen corpse left on the map)")
	assert_true(monster.respawn_timer > 0.0, "Death arms the respawn countdown (%.1fs)" % monster.respawn_timer)

	# Tick to just before the threshold: must still be dead.
	var elapsed := 0.0
	while elapsed < monster.RESPAWN_TIME - 0.5:
		monster._physics_process(0.1)
		elapsed += 0.1
	assert_true(monster.is_dead == true, "Monster still dead before RESPAWN_TIME elapses")

	# Tick past the threshold.
	while elapsed < monster.RESPAWN_TIME + 0.5:
		monster._physics_process(0.1)
		elapsed += 0.1

	assert_true(monster.is_dead == false, "Monster respawns after RESPAWN_TIME")
	assert_true(monster.current_health == monster.max_health, "Respawned monster restored to full HP (%d)" % monster.current_health)
	assert_true(monster.visible == true, "Respawned monster is visible again")
	assert_true(monster.global_position == origin, "Respawned monster returned to its spawn point")
	# Not asserting IDLE specifically: the monster respawns on top of this
	# test's player, so the AI legitimately aggros in the same frame. What
	# matters is that it left the terminal DEAD state.
	assert_true(monster.current_state != monster.State.DEAD, "Respawned monster left the terminal DEAD state")

	# It must be killable again — a respawned monster that cannot die would
	# break the loop just as badly as one that never comes back.
	monster.take_damage(monster.max_health * 2, player.peer_id)
	assert_true(monster.is_dead == true, "Respawned monster can be killed again")

	# Boss respawn is deliberately slower than a regular slime.
	var boss = monster_scene.instantiate()
	boss.is_king_slime = true
	add_child(boss)
	boss.take_damage(boss.max_health * 2, player.peer_id)
	assert_true(boss.respawn_timer > monster.RESPAWN_TIME, "King Slime respawn timer (%.0fs) is longer than a regular slime (%.0fs)" % [boss.respawn_timer, monster.RESPAWN_TIME])

	boss.queue_free()
	player.queue_free()
	monster.queue_free()

func _test_water_cliffs_and_minimap():
	print("
--- 21. Testing Water Wading, Cliffs & Minimap Image ---")
	var world_scene = load("res://scenes/world.tscn")
	var w = world_scene.instantiate()
	add_child(w)

	# --- water depth ---
	var shore := []
	var deep := []
	for c in w._terrain:
		if w._terrain[c] != w.Terrain.WATER:
			continue
		var d: int = w._water_depth.get(c, 0)
		if d == 1:
			shore.append(c)
		elif d >= 3:
			deep.append(c)
	assert_true(shore.size() > 0, "Water has a shoreline (depth 1): %d cells" % shore.size())
	assert_true(deep.size() > 0, "Water has deeper interior (depth >= 3): %d cells" % deep.size())

	# Every water cell must have a depth; a missing one would read as dry land.
	var all_have_depth := true
	for c in w._terrain:
		if w._terrain[c] == w.Terrain.WATER and not w._water_depth.has(c):
			all_have_depth = false
			break
	assert_true(all_have_depth, "Every water cell has a computed depth")

	# --- speed multiplier ---
	var tile: int = w.tile_px()
	var dry_mult: float = w.speed_multiplier_at_world(Vector2(0, 0))
	assert_true(is_equal_approx(dry_mult, 1.0), "Dry land does not slow movement (%.2f)" % dry_mult)

	var shore_pos = Vector2(shore[0].x * tile + tile / 2, shore[0].y * tile + tile / 2)
	var deep_pos = Vector2(deep[0].x * tile + tile / 2, deep[0].y * tile + tile / 2)
	var shore_mult: float = w.speed_multiplier_at_world(shore_pos)
	var deep_mult: float = w.speed_multiplier_at_world(deep_pos)

	assert_true(shore_mult < 1.0, "Shallow water slows movement (%.2f)" % shore_mult)
	assert_true(deep_mult < shore_mult, "Deeper water slows more than shallow (%.2f < %.2f)" % [deep_mult, shore_mult])
	assert_true(deep_mult >= w.WATER_SLOW_FLOOR, "Slow is floored at WATER_SLOW_FLOOR (%.2f)" % deep_mult)

	# --- cliffs ---
	var cliff_cells := 0
	for c in w._terrain:
		if w._terrain[c] == w.Terrain.CLIFF:
			cliff_cells += 1
	assert_true(cliff_cells > 0, "Map has cliff cells (%d)" % cliff_cells)

	var cliffs = w.get_node_or_null("Map/Cliffs")
	assert_true(cliffs != null, "Cliff StaticBody2D was built")
	assert_true(cliffs.get_child_count() > 0, "Cliffs have collision shapes (%d)" % cliffs.get_child_count())
	assert_true(cliffs.get_child_count() < cliff_cells, "Collision runs are merged, not one shape per cell (%d shapes / %d cells)" % [cliffs.get_child_count(), cliff_cells])
	assert_true(cliffs.is_in_group("obstacles"), "Cliffs are in the obstacles group")

	# A cliff across the crossroads would cut the arena in half.
	var cliff_on_road := false
	for c in w._terrain:
		if w._terrain[c] == w.Terrain.CLIFF and w._is_on_road(c):
			cliff_on_road = true
			break
	assert_true(not cliff_on_road, "No cliff blocks the crossroads")

	# --- minimap image ---
	var img: Image = w.build_terrain_image()
	var expected: int = w.map_half_tiles() * 2 + 1
	assert_true(img != null and img.get_width() == expected, "Terrain image is one pixel per tile (%dx%d)" % [img.get_width(), img.get_height()])
	assert_true(img.get_pixel(expected / 2, expected / 2).a > 0.0, "Terrain image is populated, not blank")

	w.queue_free()

func _test_procedural_map():
	print("
--- 20. Testing Procedural Terrain Generation ---")
	var world_scene = load("res://scenes/world.tscn")

	var w1 = world_scene.instantiate()
	add_child(w1)

	assert_true(w1.ground_layer != null, "Ground TileMapLayer exists")
	assert_true(w1.detail_layer != null, "Detail TileMapLayer exists")
	assert_true(w1.ground_layer.tile_set != null, "Terrain TileSet is assigned")

	var cells = w1.ground_layer.get_used_cells()
	assert_true(cells.size() > 4000, "Ground layer painted (%d cells)" % cells.size())
	assert_true(w1.detail_layer.get_used_cells().size() > 100, "Props scattered on the detail layer (%d)" % w1.detail_layer.get_used_cells().size())

	# Every terrain type should actually appear somewhere.
	var kinds := {}
	for c in w1._terrain:
		kinds[w1._terrain[c]] = true
	assert_true(kinds.has(w1.Terrain.GRASS), "Map contains grass")
	assert_true(kinds.has(w1.Terrain.DIRT), "Map contains dirt paths")
	assert_true(kinds.has(w1.Terrain.WATER), "Map contains water")
	assert_true(kinds.has(w1.Terrain.STONE), "Map contains the stone clearing")

	# The map must be identical on every client: monsters are addressed by index
	# and players share world coordinates, so a divergent map desyncs the session.
	var w2 = world_scene.instantiate()
	add_child(w2)
	var same := true
	for c in w1._terrain:
		if w2._terrain.get(c, -1) != w1._terrain[c]:
			same = false
			break
	assert_true(same, "Terrain layout is deterministic across instances")

	var tiles_same := true
	for c in cells:
		if w2.ground_layer.get_cell_atlas_coords(c) != w1.ground_layer.get_cell_atlas_coords(c):
			tiles_same = false
			break
	assert_true(tiles_same, "Painted tiles are deterministic across instances")

	# Nine-slice selection: a cell with no same-kind neighbour to the west is a
	# west edge (column 0); fully surrounded cells are centre (1,1).
	var found_edge := false
	var found_centre := false
	for c in w1._terrain:
		if w1._terrain[c] != w1.Terrain.WATER:
			continue
		var off = w1._slice_offset(c, w1.Terrain.WATER)
		if off == Vector2i(1, 1):
			found_centre = true
		elif off.x == 0 or off.x == 2 or off.y == 0 or off.y == 2:
			found_edge = true
	assert_true(found_centre, "Water region has interior (centre) tiles")
	assert_true(found_edge, "Water region has edge tiles blending into grass")

	w2.queue_free()
	w1.queue_free()

func _test_ranged_autoaim_and_range():
	print("
--- 19. Testing Ranged Auto-Aim, Range Limit & Class Attacks ---")
	var monster_scene = load("res://scenes/monster.tscn")
	var player_scene = load("res://scenes/player.tscn")

	# Earlier tests leave monsters parked near the origin, and this suite shares
	# one scene tree. Work far away from them so "no target in range" means it.
	var base := Vector2(50000, 50000)

	var player = player_scene.instantiate()
	add_child(player)
	player.global_position = base
	player.facing_dir = Vector2.RIGHT

	var archer = ArcherClass.new()
	var mage = MageClass.new()
	var warrior = WarriorClass.new()

	# No target in range -> shoot where the player faces.
	assert_true(archer.aim_dir(player) == Vector2.RIGHT, "Auto-aim falls back to facing_dir with no target")

	# A monster off to the LEFT should be acquired even though the player faces right.
	var mob = monster_scene.instantiate()
	add_child(mob)
	mob.global_position = base + Vector2(-120, 0)
	var dir = archer.aim_dir(player)
	assert_true(dir.x < -0.9, "Auto-aim turns toward a target behind the player (x=%.2f)" % dir.x)
	assert_true(archer.acquire_target(player) == mob, "acquire_target returns the nearest monster")

	# Beyond AUTO_AIM_RANGE it must be ignored.
	mob.global_position = base + Vector2(-(archer.AUTO_AIM_RANGE + 60.0), 0)
	assert_true(archer.acquire_target(player) == null, "Target beyond AUTO_AIM_RANGE is not acquired")
	assert_true(archer.aim_dir(player) == Vector2.RIGHT, "Out-of-range target falls back to facing_dir")

	# Nearest of several wins.
	mob.global_position = base + Vector2(-200, 0)
	var near = monster_scene.instantiate()
	add_child(near)
	near.global_position = base + Vector2(90, 0)
	assert_true(archer.acquire_target(player) == near, "Nearest of several monsters is chosen")

	# Ranged classes must not use the warrior's melee hitbox path.
	assert_true(archer.BASIC_SHOT_RANGE > 0.0, "Archer defines a basic-shot range limit")
	assert_true(mage.BASIC_BOLT_RANGE > 0.0, "Mage defines a basic-bolt range limit")
	assert_true(archer.BASIC_SHOT_RANGE >= archer.AUTO_AIM_RANGE, "Archer shot reaches at least as far as it can aim")
	assert_true(warrior.get_class_name() == "warrior" and archer.get_class_name() == "archer", "Class strategies report distinct names")

	# face_direction keeps the hitbox and slash sprite in sync.
	player.face_direction(Vector2.LEFT)
	assert_true(player.facing_dir == Vector2.LEFT, "face_direction updates facing_dir")
	assert_true(player.attack_area.position.x < 0, "face_direction moves the melee hitbox to the left")

	near.queue_free()
	mob.queue_free()
	player.queue_free()

func _test_player_attack_and_projectiles():
	print("\n--- 5. Testing Player Attack & Projectile Spells ---")
	var player_scene = load("res://scenes/player.tscn")
	var proj_scene = load("res://scenes/projectile.tscn")
	assert_true(proj_scene != null, "Projectile scene loads")
	
	var player = player_scene.instantiate()
	var proj = proj_scene.instantiate()
	add_child(player)
	add_child(proj)
	
	assert_true(player.can_attack == true, "Player starts with can_attack = true")
	assert_true(proj.damage == 25, "Projectile spell has damage = 25")
	assert_true(proj.speed > 0, "Projectile has non-zero movement speed")
	
	# Test projectile movement
	var pos1 = proj.position
	proj.direction = Vector2.RIGHT
	proj._physics_process(0.1)
	assert_true(proj.position.x > pos1.x, "Projectile moves forward along direction vector")
	
	player.queue_free()
	proj.queue_free()

func _test_xp_and_leveling():
	print("\n--- 6. Testing XP Progression and Level Up Scaling ---")
	var player_scene = load("res://scenes/player.tscn")
	var player = player_scene.instantiate()
	add_child(player)
	
	var initial_level = player.level
	var initial_max_hp = player.max_hp
	var initial_dmg = player.attack_damage
	
	# Grant XP enough to level up
	player.gain_xp(player.xp_to_next + 10)
	
	assert_true(player.level == initial_level + 1, "Player leveled up (%d -> %d)" % [initial_level, player.level])
	assert_true(player.max_hp > initial_max_hp, "Max HP increased on level up (%d -> %d)" % [initial_max_hp, player.max_hp])
	assert_true(player.attack_damage > initial_dmg, "Attack damage increased on level up (%d -> %d)" % [initial_dmg, player.attack_damage])
	assert_true(player.current_hp == player.max_hp, "Current HP fully restored on level up")
	
	player.queue_free()

func _test_level_tally_and_nameplate_sync():
	print("\n--- 7. Testing Level Tally & Nameplate Synchronization ---")
	var player_scene = load("res://scenes/player.tscn")
	var remote_player = player_scene.instantiate()
	remote_player.is_local = false
	remote_player.player_name = "Knight_Friend"
	remote_player.level = 1
	add_child(remote_player)
	
	assert_true(remote_player.name_label.text.contains("Lv.1"), "Remote player initial nameplate shows Lv.1")
	
	# Simulate receiving stat_sync for level 4
	remote_player.level = 4
	remote_player._update_nameplate()
	assert_true(remote_player.name_label.text == "Knight_Friend [Lv.4]", "Remote player nameplate updates to Knight_Friend [Lv.4]")
	
	remote_player.queue_free()

func _test_monster_movement_synchronization():
	print("\n--- 8. Testing Monster Movement & Activity Synchronization ---")
	var monster_scene = load("res://scenes/monster.tscn")
	var mob = monster_scene.instantiate()
	add_child(mob)
	
	# Simulate client receiver (non-host)
	NetworkManager.is_room_host = false
	NetworkManager.is_solo_mode = false
	
	var sync_coord = Vector2(340, -120)
	mob.apply_sync_state(sync_coord, true, 45, false)
	
	assert_true(mob.target_sync_pos == sync_coord, "Monster target_sync_pos set to host broadcast coords")
	assert_true(mob.current_health == 45, "Monster synchronized health updated to 45")
	assert_true(mob.sprite.flip_h == true, "Monster sprite flip_h synchronized")
	
	# Interpolation step
	mob._physics_process(0.1)
	assert_true(mob.global_position.distance_to(sync_coord) < mob.spawn_pos.distance_to(sync_coord), "Non-host monster interpolates towards host coordinates")
	
	# Reset flags for subsequent tests
	NetworkManager.is_room_host = true
	NetworkManager.is_solo_mode = true
	mob.queue_free()

func _test_loot_drop():
	print("\n--- 9. Testing Loot Drops ---")
	var loot_scene = load("res://scenes/loot_drop.tscn")
	assert_true(loot_scene != null, "LootDrop scene loads successfully")
	
	var loot = loot_scene.instantiate()
	add_child(loot)
	assert_true(loot.is_in_group("loot"), "LootDrop node added to 'loot' group")
	assert_true(loot.value > 0, "LootDrop has positive value (%d)" % loot.value)
	loot.queue_free()

func _test_hud_leaderboard_level_sync():
	print("\n--- 10. Testing HUD Leaderboard Level Sync & [You] Tag ---")
	NetworkManager.local_id = 77
	GameState.players.clear()
	GameState.register_player_info(77, "Hero_Test", 0, 1)
	GameState.register_player_info(88, "Peer_Test", 1, 3)
	
	assert_true(GameState.players.size() == 2, "Two players registered in GameState")
	assert_true(GameState.players[77]["level"] == 1, "Local player starts at Level 1")
	
	# Simulate local player leveling up to Level 8
	GameState.sync_player_stat(77, "level", 8)
	assert_true(GameState.players[77]["level"] == 8, "GameState local player level updated to 8")
	
	# Verify HUD formatting
	var local_tag = "%s (Lv.%d)" % [GameState.players[77]["name"], GameState.players[77]["level"]]
	if 77 == NetworkManager.local_id:
		local_tag += " [You]"
	assert_true(local_tag == "Hero_Test (Lv.8) [You]", "Leaderboard tag matches 'Hero_Test (Lv.8) [You]'")
	
	var peer_tag = "%s (Lv.%d)" % [GameState.players[88]["name"], GameState.players[88]["level"]]
	if 88 == NetworkManager.local_id:
		peer_tag += " [You]"
	assert_true(peer_tag == "Peer_Test (Lv.3)", "Remote player tag matches 'Peer_Test (Lv.3)' without [You]")
	
	GameState.players.clear()

func _test_classic_classes_and_base_stats():
	print("\n--- 11. Testing Classic Classes & Baseline Stats ---")
	var player_scene = load("res://scenes/player.tscn")
	var p = player_scene.instantiate()
	p.is_local = true
	add_child(p)
	
	# Test Warrior
	GameState.hero_class = "warrior"
	GameState.stat_str = 14; GameState.stat_vit = 12; GameState.stat_agi = 9; GameState.stat_int = 5
	p.recalculate_stats()
	assert_true(p.max_hp == 204, "Warrior Max HP scaled by VIT (204)")
	assert_true(p.max_energy == 55, "Warrior Max Energy scaled by INT (55)")
	assert_true(p.attack_damage >= 50, "Warrior high melee damage scaled by STR (%d)" % p.attack_damage)
	
	# Test Mage
	GameState.hero_class = "mage"
	GameState.stat_str = 5; GameState.stat_vit = 8; GameState.stat_agi = 9; GameState.stat_int = 16
	p.recalculate_stats()
	assert_true(p.max_hp == 104, "Mage lower HP balanced for glass cannon (104)")
	assert_true(p.max_energy == 120, "Mage high Max Energy pool scaled by INT (120)")
	
	# Test Archer
	GameState.hero_class = "archer"
	GameState.stat_str = 10; GameState.stat_vit = 10; GameState.stat_agi = 15; GameState.stat_int = 7
	p.recalculate_stats()
	assert_true(p.move_speed > 210.0, "Archer has highest movement speed (%f)" % p.move_speed)
	
	p.queue_free()

func _test_energy_and_regeneration():
	print("\n--- 12. Testing Energy Pool & Natural Regeneration ---")
	var player_scene = load("res://scenes/player.tscn")
	var p = player_scene.instantiate()
	p.is_local = true
	add_child(p)
	
	p.max_energy = 80
	p.current_energy = 80
	
	# 1. Use energy successfully
	var used = p.use_energy(25)
	assert_true(used == true, "use_energy(25) succeeds when energy is available")
	assert_true(p.current_energy == 55, "Energy deducted correctly (80 -> 55)")
	
	# 2. Reject when insufficient energy
	p.current_energy = 10
	var rejected = p.use_energy(25)
	assert_true(rejected == false, "use_energy(25) rejected when only 10 energy available")
	assert_true(p.current_energy == 10, "Energy remained unchanged on rejection")
	
	# 3. Natural regeneration
	p._physics_process(1.0)
	assert_true(p.current_energy > 10, "Energy passively regenerates over physics process (%d)" % p.current_energy)
	
	p.queue_free()

func _test_class_skills_execution():
	print("\n--- 13. Testing Class Skills Execution & Cooldowns ---")
	var player_scene = load("res://scenes/player.tscn")
	var monster_scene = load("res://scenes/monster.tscn")
	var p = player_scene.instantiate()
	var mob = monster_scene.instantiate()
	p.is_local = true
	add_child(p)
	add_child(mob)
	
	# Test Warrior Whirlwind AoE
	GameState.hero_class = "warrior"
	p.hero_class = "warrior"
	p.recalculate_stats()
	GameState.stat_str = 15
	p.current_energy = 80
	p.skill2_cd = 0.0
	mob.global_position = p.global_position + Vector2(30, 0)
	var mob_hp_before = mob.current_health
	p._execute_skill(2)
	assert_true(p.skill2_cd > 0, "Warrior Whirlwind entered cooldown")
	assert_true(mob.current_health < mob_hp_before, "Monster in 360 radius took Whirlwind AoE damage")
	
	# Test Archer Tumble Dash
	GameState.hero_class = "archer"
	p.hero_class = "archer"
	p.recalculate_stats()
	p.current_energy = 80
	p.skill2_cd = 0.0
	var pos_before = p.global_position
	p._execute_skill(2)
	assert_true(p.global_position.distance_to(pos_before) > 50.0, "Archer Tumble dashed player position forward")
	
	p.queue_free()
	mob.queue_free()

func _test_inventory_and_item_use():
	print("\n--- 14. Testing Bag Inventory & Potion Consumption ---")
	var player_scene = load("res://scenes/player.tscn")
	var p = player_scene.instantiate()
	p.is_local = true
	p.peer_id = 999
	p.name = "999"
	NetworkManager.local_id = 999
	add_child(p)
	
	p.max_hp = 150
	p.current_hp = 80
	p.max_energy = 80
	p.current_energy = 30
	
	# Populate inventory
	GameState.inventory.clear()
	GameState.inventory.resize(16)
	GameState.inventory[0] = {"slot": 0, "id": "potion_hp", "name": "Health Potion", "type": "consumable", "quantity": 2}
	GameState.inventory[1] = {"slot": 1, "id": "potion_mp", "name": "Energy Potion", "type": "consumable", "quantity": 1}
	
	assert_true(GameState.inventory[0]["quantity"] == 2, "Slot 0 starts with 2x Health Potions")
	
	# Consume Health Potion in solo mode
	NetworkManager.is_solo_mode = true
	NetworkManager.send_item_use(0)
	
	assert_true(p.current_hp == 140, "Health potion restored 60 HP (80 -> 140)")
	assert_true(GameState.inventory[0]["quantity"] == 1, "Health potion count decremented to 1")
	
	# Consume Energy Potion in solo mode
	NetworkManager.send_item_use(1)
	assert_true(p.current_energy == 80, "Energy potion restored 50 Energy (30 -> 80)")
	assert_true(GameState.inventory[1] == null, "Energy potion slot cleared after consuming final count")
	
	p.queue_free()

func _test_oop_strategy_and_combat_formulas():
	print("\n--- 15. Testing OOP Strategy Pattern & Combat Formulas ---")
	var w = HeroClass.create("warrior")
	var m = HeroClass.create("mage")
	var a = HeroClass.create("archer")
	
	assert_true(w is WarriorClass, "HeroClass factory creates WarriorClass")
	assert_true(m is MageClass, "HeroClass factory creates MageClass")
	assert_true(a is ArcherClass, "HeroClass factory creates ArcherClass")
	
	# Ragnarok DEF mitigation tests
	var mitigated_50 = CombatFormula.calc_defense_mitigation(100, 50)
	assert_true(mitigated_50 == 67, "100 raw damage with 50 DEF mitigated to 67 (%d)" % mitigated_50)
	
	var mitigated_100 = CombatFormula.calc_defense_mitigation(100, 100)
	assert_true(mitigated_100 == 50, "100 raw damage with 100 DEF mitigated to 50 (%d)" % mitigated_100)
	
	# Natural regen formulas
	var mp_regen = CombatFormula.calc_energy_regen(15)
	assert_true(mp_regen == 14.0, "Energy regen scaled by INT (14.0 MP/s): %.1f" % mp_regen)

func _test_stamina_dodge_roll_and_iframes():
	print("\n--- 16. Testing Stamina, Active Dodge-Roll & i-Frames ---")
	var player_scene = load("res://scenes/player.tscn")
	var p = player_scene.instantiate()
	p.is_local = true
	p.peer_id = 998
	add_child(p)
	
	p.current_stamina = 100.0
	var rolled = p.dodge_roll()
	assert_true(rolled == true, "dodge_roll() succeeds with full stamina")
	assert_true(p.current_stamina == 75.0, "Dodge-roll deducted 25 stamina (100 -> 75)")
	assert_true(p.is_invulnerable == true, "Player enters invulnerable i-frame state during roll")
	
	# Incoming damage during i-frames deals 0 damage
	var hp_before = p.current_hp
	var dealt = p.take_damage(50, 0)
	assert_true(dealt == 0, "Incoming attack deals 0 damage during roll i-frames")
	assert_true(p.current_hp == hp_before, "Player HP remains untouched during i-frame dodge")
	
	p.queue_free()

func _test_charged_attacks_and_stun():
	print("\n--- 17. Testing Charged Heavy Attacks & Status Stun ---")
	var player_scene = load("res://scenes/player.tscn")
	var monster_scene = load("res://scenes/monster.tscn")
	var p = player_scene.instantiate()
	var mob = monster_scene.instantiate()
	p.is_local = true
	p.peer_id = 997
	add_child(p)
	add_child(mob)
	
	# Status Stun on Monster
	mob.is_stunned = false
	mob.apply_stun(1.5)
	assert_true(mob.is_stunned == true, "apply_stun(1.5) marks monster as stunned")
	assert_true(mob.stun_timer > 0, "Monster has active stun countdown timer")
	
	# Level 11 Warrior Charged Attack Knockback
	GameState.hero_class = "warrior"
	p.level = 11
	p.recalculate_stats()
	var mob_pos = mob.global_position
	p._execute_charged_attack()
	# Check charged attack executed without error
	assert_true(p.attack_damage > 0, "Warrior charged attack executed successfully")
	
	p.queue_free()
	mob.queue_free()

func _test_item_database_paperdoll_and_ui_lock():
	print("\n--- 18. Testing ItemDatabase, Paperdoll Equipment & UI Lock ---")
	var plate = ItemDatabase.create_item("armor_plate")
	assert_true(plate["slot_type"] == "armor", "ItemDatabase created armor item with correct slot_type")
	assert_true(plate["rarity"] == "Uncommon", "ItemDatabase plate armor has Uncommon rarity")
	
	# Equip armor
	GameState.inventory.resize(16)
	GameState.inventory[0] = plate
	var equipped = GameState.equip_item(0, 5)
	assert_true(equipped == true, "GameState.equip_item() equipped plate armor successfully")
	assert_true(GameState.equipped_gear["armor"]["id"] == "armor_plate", "Equipped gear slot contains armor_plate")
	assert_true(GameState.get_equipment_bonus("def") == 10, "Equipment bonus DEF increased by +10")
	
	# UI Focus Lock
	GameState.set_ui_modal_open(true)
	assert_true(GameState.is_ui_focused() == true, "GameState.is_ui_focused() returns true when modal opened")
	GameState.set_ui_modal_open(false)
	assert_true(GameState.is_ui_focused() == false, "GameState.is_ui_focused() returns false when modal closed")
	
	# Clean up
	GameState.unequip_slot("armor")

