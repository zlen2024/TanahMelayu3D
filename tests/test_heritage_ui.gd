extends Node

var failures := 0

func check(condition: bool, message: String):
	if not condition:
		failures += 1
		push_error(message)
	else: print("PASS: " + message)

func _ready():
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var lobby = main.get_node("LobbyLayer/LobbyUI")
	check(lobby.password_input.text.is_empty(), "Online password starts empty")
	lobby._on_connect_failed()
	check(lobby.login_btn.disabled and not lobby.guest_btn.disabled, "Offline state disables online actions but preserves solo entry")
	for i in range(3):
		lobby.class_buttons[i].pressed.emit()
		check(lobby.class_option.selected == i, "Class card selects index %d" % i)
		check(lobby.description.text == lobby.LORE[i], "Class description follows selection")
	lobby.username_input.text = "TestPengembara"
	lobby.guest_btn.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	check(not lobby.visible, "Solo entry dismisses lobby")
	check(NetworkManager.is_solo_mode, "Solo entry starts offline session")
	check(GameState.hero_class == "archer", "Selected class reaches gameplay")
	var hero = main.get_node("World/Players").get_child(0)
	check(hero.sprite.sprite_frames.resource_path.ends_with("tm/pemanah.tres"), "Pemanah sprite is used in game")
	var hud = main.get_node("HUD")
	check(is_instance_valid(hud.local_player_node), "HUD binds to spawned player")
	hero.skill1_cd = 2.0
	hud._process(0.01)
	check(hud.skill1_btn.disabled and "2.0s" in hud.skill1_btn.text, "Skill cooldown shows remaining time")
	hero.skill1_cd = 0.0
	hud._process(0.01)
	check(not hud.skill1_btn.disabled and "Tiga Panah" in hud.skill1_btn.text, "Skill becomes ready after cooldown")
	check(main.get_node("World/Kampung").get_child_count() == 20, "Kampung landmarks exist")
	hud.stats_panel.set_open(true)
	hud.inventory_ui.set_open(true)
	check(not hud.stats_panel.visible and hud.inventory_ui.visible, "Inventory and attributes do not overlap")
	hud.inventory_ui.set_open(false)
	check(not GameState.is_ui_focused(), "Closing the panel restores gameplay input")
	print("Heritage UI test failures: %d" % failures)
	get_tree().quit(1 if failures else 0)
