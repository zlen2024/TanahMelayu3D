extends Control

# Lobby UI: Direct connect, User Login, Registration with Classic Classes, and Guest Mode.

@onready var username_input: LineEdit = $Panel/VBox/UserInput
@onready var password_input: LineEdit = $Panel/VBox/PassInput
@onready var class_option: OptionButton = $Panel/VBox/ClassOption
@onready var address_input: LineEdit = $Panel/VBox/AddressInput
@onready var login_btn: Button = $Panel/VBox/ButtonsHBox/LoginBtn
@onready var register_btn: Button = $Panel/VBox/ButtonsHBox/RegisterBtn
@onready var guest_btn: Button = $Panel/VBox/GuestBtn
@onready var status_label: Label = $Panel/VBox/StatusLabel

var is_socket_ready: bool = false

func _ready():
	randomize()
	username_input.text = "Hero_%d" % randi_range(100, 999)
	password_input.text = "123456"
	
	class_option.clear()
	class_option.add_item("Warrior (Melee Tank - STR/VIT)", 0)
	class_option.add_item("Mage (Arcane Burst - INT/VIT)", 1)
	class_option.add_item("Archer (Agile Kiter - AGI/STR)", 2)
	class_option.selected = 0
	
	login_btn.pressed.connect(_on_login_pressed)
	register_btn.pressed.connect(_on_register_pressed)
	guest_btn.pressed.connect(_on_guest_pressed)
	
	NetworkManager.connection_succeeded.connect(_on_connected)
	NetworkManager.connection_failed_event.connect(_on_connect_failed)
	NetworkManager.server_disconnected_event.connect(_on_disconnected)
	
	GameState.auth_succeeded.connect(_on_auth_succeeded)
	GameState.auth_failed.connect(_on_auth_failed)

	# Auto-detect web host and protocol
	if OS.has_feature("web"):
		var host = JavaScriptBridge.eval("window.location.host")
		var protocol = JavaScriptBridge.eval("window.location.protocol")
		if host != null and str(host) != "" and str(host) != "null":
			var ws_proto = "wss://" if str(protocol) == "https:" else "ws://"
			address_input.text = ws_proto + str(host)
		else:
			address_input.text = "ws://127.0.0.1:8080"
	else:
		address_input.text = "ws://127.0.0.1:8080"

	# Auto-connect to WebSocket server immediately
	_auto_connect_ws()

func _auto_connect_ws():
	var url = address_input.text.strip_edges()
	if url.is_empty():
		url = "ws://127.0.0.1:8080"
	status_label.text = "Connecting to server..."
	status_label.modulate = Color.YELLOW
	NetworkManager.start_client(url)

func _get_selected_class() -> String:
	match class_option.selected:
		1: return "mage"
		2: return "archer"
		_: return "warrior"

func _on_login_pressed():
	var u = username_input.text.strip_edges()
	var p = password_input.text.strip_edges()
	if u.is_empty() or p.is_empty():
		status_label.text = "Enter username and password."
		status_label.modulate = Color.RED
		return
		
	status_label.text = "Authenticating..."
	status_label.modulate = Color.YELLOW
	NetworkManager.send_login(u, p)

func _on_register_pressed():
	var u = username_input.text.strip_edges()
	var p = password_input.text.strip_edges()
	if u.is_empty() or p.is_empty():
		status_label.text = "Enter username and password."
		status_label.modulate = Color.RED
		return
		
	var c_type = _get_selected_class()
	var skin_idx = class_option.selected
	status_label.text = "Creating %s account..." % c_type.capitalize()
	status_label.modulate = Color.YELLOW
	NetworkManager.send_register(u, p, c_type, skin_idx)

func _on_guest_pressed():
	var c_type = _get_selected_class()
	var p_name = username_input.text.strip_edges()
	if p_name.is_empty():
		p_name = "Guest_%d" % randi_range(100, 999)
	GameState.local_player_name = p_name
	status_label.text = "Entering realm as %s..." % c_type.capitalize()
	status_label.modulate = Color.GREEN
	NetworkManager.start_guest(c_type)

func _on_auth_succeeded(_user_data, _char_data):
	status_label.text = "Welcome, Hero! Entering realm..."
	status_label.modulate = Color.GREEN
	visible = false

func _on_auth_failed(err_msg: String):
	status_label.text = err_msg
	status_label.modulate = Color.RED

func _on_connected():
	is_socket_ready = true
	status_label.text = "Connected! Login or Register below."
	status_label.modulate = Color.GREEN

func _on_connect_failed():
	is_socket_ready = false
	NetworkManager.disconnect_network()
	status_label.text = "Connection failed. Check server or click to retry."
	status_label.modulate = Color.RED

func _on_disconnected():
	is_socket_ready = false
	NetworkManager.disconnect_network()
	status_label.text = "Disconnected from server."
	status_label.modulate = Color.RED
	visible = true
