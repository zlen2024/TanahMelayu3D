extends Node

# Visual verification harness. Loads main.tscn, arranges a deliberate scene,
# and writes PNGs so UI/rendering changes can be checked rather than assumed.
#
#   godot --path . tools/screenshot_harness.tscn -- --out=<dir>
#
# Not part of the test suite: it needs a real renderer, so it cannot run under
# --headless (the dummy driver renders nothing and the capture comes out blank).

var out_dir: String = "user://"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)

	var main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	await get_tree().process_frame

	# 1. Lobby — checks the Theme: panels, buttons, inputs, fonts.
	await _shoot("01_lobby.png")
	var lobby = main.get_node("LobbyLayer/LobbyUI")
	lobby.account_box.show()
	for _i in range(3): await get_tree().process_frame
	await _shoot("01b_online.png")
	lobby.account_box.hide()

	# 2. Enter the world as a guest (no server needed).
	lobby._on_guest_pressed()
	for _i in range(10):
		await get_tree().process_frame

	var world = get_tree().root.find_child("World", true, false)
	var players = world.find_child("Players", true, false)
	var monsters = world.find_child("Monsters", true, false)

	# Park the hero just below the pillar at (-300, -250). Anything with a
	# greater Y must draw in front of it, anything lesser behind.
	var hero = players.get_child(0)
	hero.global_position = Vector2(-300, -210)

	# One slime above the pillar (must be occluded), one below (must occlude).
	if monsters.get_child_count() >= 2:
		monsters.get_child(0).global_position = Vector2(-300, -300)
		monsters.get_child(1).global_position = Vector2(-260, -170)

	# Keep the camera on the arrangement.
	var cam = hero.get_node_or_null("Camera2D")
	if cam:
		cam.position_smoothing_enabled = false
		# Optional wide shot for map work: pass --wide.
		if "--wide" in OS.get_cmdline_user_args():
			cam.zoom = Vector2(0.35, 0.35)

	for _i in range(10):
		await get_tree().process_frame

	# 3. In-world — Y-sort, HUD theme, and the walk animation.
	# Force the walk clip so the capture shows an animated frame rather than idle.
	var hs = hero.get_node_or_null("Sprite2D")
	if hs and hs is AnimatedSprite2D:
		hs.play("walk")
	for _i in range(4):
		await get_tree().process_frame
	await _shoot("02_world_ysort.png")
	hero.global_position = Vector2(-460, 280)
	for _i in range(4): await get_tree().process_frame
	await _shoot("02b_kampung.png")

	# 4. Open both panels to check themed panels/buttons over the world.
	var hud = get_tree().root.find_child("HUD", true, false)
	if hud:
		var stats = hud.find_child("StatsPanel", true, false)
		var inv = hud.find_child("InventoryUI", true, false)
		if stats:
			stats.set_open(true)
			for _i in range(3): await get_tree().process_frame
			await _shoot("03a_attributes.png")
		if inv: inv.set_open(true)
	for _i in range(6):
		await get_tree().process_frame
	await _shoot("03_panels.png")

	get_tree().quit(0)


func _shoot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := out_dir.path_join(name)
	var err := img.save_png(path)
	print("[shot] %s -> %s (err %d)" % [name, path, err])
