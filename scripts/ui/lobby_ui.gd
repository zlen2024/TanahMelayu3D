extends Control

const Style = preload("res://scripts/ui/heritage_style.gd")
const CLASSES := ["Pendekar", "Pawang", "Pemanah"]
const ROLES := ["KERIS • MELEE", "MYSTIC • MAGIC", "BOW • RANGED"]
const LORE := [
	"A guardian of the kampung. Stand your ground with powerful strikes and unyielding resolve.",
	"A keeper of hidden knowledge. Command elemental magic and turn the tide from afar.",
	"A hunter of the forest paths. Strike at a distance, evade danger, and choose your moment."
]
var username_input: LineEdit
var password_input: LineEdit
var address_input: LineEdit
var login_btn: Button
var register_btn: Button
var guest_btn: Button
var status_label: Label
var class_option: OptionButton
var is_socket_ready := false
var class_buttons: Array[Button] = []
var description: Label
var account_box: VBoxContainer
var content: HBoxContainer
var hero_copy: VBoxContainer
var scroll: ScrollContainer

func _ready():
	_build_interface()
	username_input.text = "Pengembara_%d" % randi_range(100, 999)
	NetworkManager.connection_succeeded.connect(_on_connected)
	NetworkManager.connection_failed_event.connect(_on_connect_failed)
	NetworkManager.server_disconnected_event.connect(_on_disconnected)
	GameState.auth_succeeded.connect(_on_auth_succeeded)
	GameState.auth_failed.connect(_on_auth_failed)
	if OS.has_feature("web"):
		var host = JavaScriptBridge.eval("window.location.host")
		var protocol = JavaScriptBridge.eval("window.location.protocol")
		if host != null and str(host) != "" and str(host) != "null":
			address_input.text = ("wss://" if str(protocol) == "https:" else "ws://") + str(host)
	resized.connect(_layout)
	_layout()
	_auto_connect_ws()

func _build_interface():
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var art := TextureRect.new()
	art.texture = preload("res://assets/ui/kampung_dusk.png")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.04, 0.035, 0.23)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var frame := Panel.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 18
	frame.offset_top = 18
	frame.offset_right = -18
	frame.offset_bottom = -18
	frame.add_theme_stylebox_override("panel", Style.panel(Color.TRANSPARENT, Color(0.83, 0.71, 0.47, 0.3), 0))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	content = HBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 64
	content.offset_top = 52
	content.offset_right = -64
	content.offset_bottom = -52
	content.add_theme_constant_override("separation", 48)
	add_child(content)
	hero_copy = VBoxContainer.new()
	hero_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_copy.add_theme_constant_override("separation", 8)
	content.add_child(hero_copy)
	hero_copy.add_child(Style.label("A   T A N A H   M E L A Y U   A D V E N T U R E", 12, Style.GOLD))
	var title := Style.label("HIKAYAT", 76)
	title.add_theme_font_override("font", Style.display_font())
	hero_copy.add_child(title)
	hero_copy.add_child(Style.label("T A N A H   M E L A Y U", 21, Style.GOLD))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero_copy.add_child(spacer)
	hero_copy.add_child(Style.label("WHERE LEGENDS TAKE ROOT", 12, Style.GOLD))
	var tagline := Style.label("The forest remembers.\nYour legend begins here.", 33)
	tagline.add_theme_font_override("font", Style.display_font())
	hero_copy.add_child(tagline)
	var intro := Style.label("Beyond the lamplit kampung, old spirits stir.\nTake up your calling and venture into the unknown.", 16)
	hero_copy.add_child(intro)
	hero_copy.add_child(Style.label("FOLKLORE FANTASY     /     SOLO & ONLINE", 11, Style.MUTED))
	scroll = ScrollContainer.new()
	scroll.custom_minimum_size.x = 402
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.add_theme_stylebox_override("panel", Style.panel(Color(0.025, 0.075, 0.065, 0.95), Color("736345"), 24))
	scroll.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)
	box.add_child(Style.label("01  /  THE CALLING", 11, Style.GOLD))
	var heading := Style.label("Choose your path", 28)
	heading.add_theme_font_override("font", Style.display_font())
	box.add_child(heading)
	box.add_child(Style.label("Three traditions. One unwritten hikayat.", 14, Style.MUTED))
	class_option = OptionButton.new()
	class_option.hide()
	box.add_child(class_option)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 8)
	box.add_child(cards)
	for i in range(3):
		class_option.add_item(CLASSES[i], i)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(108, 122)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.toggle_mode = true
		btn.tooltip_text = LORE[i]
		btn.pressed.connect(_select_class.bind(i))
		cards.add_child(btn)
		class_buttons.append(btn)
		var stack := VBoxContainer.new()
		stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.offset_top = 6
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(stack)
		var portrait := TextureRect.new()
		var frames: SpriteFrames = load("res://assets/spriteframes/tm/%s.tres" % CLASSES[i].to_lower())
		portrait.texture = frames.get_frame_texture("idle", 0)
		portrait.custom_minimum_size = Vector2(64, 64)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(portrait)
		var name_tag := Style.label(CLASSES[i], 15)
		name_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stack.add_child(name_tag)
		var role := Style.label(ROLES[i], 9, Style.GOLD)
		role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stack.add_child(role)
	description = Style.label("", 14, Style.MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.y = 58
	box.add_child(description)
	box.add_child(Style.label("02  /  YOUR NAME", 11, Style.GOLD))
	username_input = LineEdit.new()
	username_input.placeholder_text = "Name your adventurer"
	username_input.max_length = 24
	username_input.custom_minimum_size.y = 42
	box.add_child(username_input)
	guest_btn = Button.new()
	guest_btn.text = "Begin your journey    →"
	guest_btn.custom_minimum_size.y = 48
	guest_btn.add_theme_stylebox_override("normal", Style.panel(Style.GOLD, Style.GOLD, 10))
	guest_btn.add_theme_stylebox_override("hover", Style.panel(Color("edcf94"), Color("edcf94"), 10))
	guest_btn.add_theme_stylebox_override("pressed", Style.panel(Color("a78a54"), Style.GOLD, 10))
	guest_btn.add_theme_color_override("font_color", Style.INK)
	guest_btn.add_theme_color_override("font_hover_color", Style.INK)
	guest_btn.add_theme_color_override("font_pressed_color", Style.INK)
	guest_btn.pressed.connect(_on_guest_pressed)
	box.add_child(guest_btn)
	var solo_note := Style.label("PLAY SOLO  •  NO ACCOUNT NEEDED", 10, Style.MUTED)
	solo_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(solo_note)
	var account_toggle := Button.new()
	account_toggle.text = "Online play / saved adventurer   +"
	account_toggle.toggle_mode = true
	box.add_child(account_toggle)
	account_box = VBoxContainer.new()
	account_box.add_theme_constant_override("separation", 8)
	account_box.hide()
	box.add_child(account_box)
	account_toggle.toggled.connect(func(open: bool):
		account_box.visible = open
		account_toggle.text = "Online play / saved adventurer   −" if open else "Online play / saved adventurer   +"
		if open: scroll.ensure_control_visible.call_deferred(account_box)
	)
	password_input = LineEdit.new()
	password_input.secret = true
	password_input.placeholder_text = "Password for online account"
	account_box.add_child(password_input)
	var actions := HBoxContainer.new()
	account_box.add_child(actions)
	login_btn = Button.new()
	login_btn.text = "Continue"
	login_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	login_btn.pressed.connect(_on_login_pressed)
	actions.add_child(login_btn)
	register_btn = Button.new()
	register_btn.text = "Create adventurer"
	register_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	register_btn.pressed.connect(_on_register_pressed)
	actions.add_child(register_btn)
	address_input = LineEdit.new()
	address_input.text = "ws://127.0.0.1:8080"
	address_input.placeholder_text = "Server address (ws:// or wss://)"
	account_box.add_child(address_input)
	var retry := Button.new()
	retry.text = "Connect to server"
	retry.pressed.connect(_auto_connect_ws)
	account_box.add_child(retry)
	status_label = Style.label("", 12, Style.MUTED)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status_label)
	_select_class(0)

func _layout():
	if not is_instance_valid(hero_copy): return
	hero_copy.visible = size.x >= 1050
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.offset_left = 48 if size.x >= 1050 else 24
	content.offset_right = -content.offset_left
	content.offset_top = 40 if size.y >= 640 else 24
	content.offset_bottom = -content.offset_top
	scroll.custom_minimum_size.x = minf(402, size.x - 48)

func _select_class(index: int):
	class_option.select(index)
	for i in range(class_buttons.size()):
		class_buttons[i].set_pressed_no_signal(i == index)
		class_buttons[i].add_theme_stylebox_override("normal", Style.panel(Color("112a23"), Color("425449"), 4))
		class_buttons[i].add_theme_stylebox_override("pressed", Style.panel(Color("253b2b"), Style.GOLD, 4))
	description.text = LORE[index]

func _auto_connect_ws():
	is_socket_ready = false
	login_btn.disabled = true
	register_btn.disabled = true
	NetworkManager.disconnect_network()
	var url := address_input.text.strip_edges()
	if url.is_empty(): url = "ws://127.0.0.1:8080"
	status_label.text = "Connecting… Solo play is always available."
	status_label.modulate = Color.WHITE
	NetworkManager.start_client(url)

func _get_selected_class() -> String:
	return ["warrior", "mage", "archer"][class_option.selected]

func _valid_account() -> bool:
	if not is_socket_ready:
		status_label.text = "Connect to a server first, or begin a solo journey."
		return false
	if username_input.text.strip_edges().is_empty() or password_input.text.is_empty():
		status_label.text = "Enter your adventurer name and password."
		return false
	return true

func _on_login_pressed():
	if not _valid_account(): return
	status_label.text = "Finding your adventurer…"
	NetworkManager.send_login(username_input.text.strip_edges(), password_input.text)

func _on_register_pressed():
	if not _valid_account(): return
	status_label.text = "Creating your adventurer…"
	NetworkManager.send_register(username_input.text.strip_edges(), password_input.text, _get_selected_class(), class_option.selected)

func _on_guest_pressed():
	GameState.local_player_name = username_input.text.strip_edges()
	if GameState.local_player_name.is_empty(): GameState.local_player_name = "Pengembara"
	NetworkManager.disconnect_network()
	NetworkManager.start_guest(_get_selected_class())

func _on_auth_succeeded(_user_data, _char_data):
	get_viewport().gui_release_focus()
	visible = false

func _on_auth_failed(err_msg: String):
	status_label.text = err_msg
	status_label.modulate = Color("edac91")

func _on_connected():
	is_socket_ready = true
	login_btn.disabled = false
	register_btn.disabled = false
	status_label.text = "●  Connected · Your online adventure awaits."
	status_label.modulate = Color("a6cfb0")

func _on_connect_failed():
	is_socket_ready = false
	login_btn.disabled = true
	register_btn.disabled = true
	status_label.text = "Offline · Begin a solo journey, or reconnect below."
	status_label.modulate = Color.WHITE

func _on_disconnected():
	if NetworkManager.is_solo_mode: return
	_on_connect_failed()
	visible = true
