extends Control

# In-game real-time chat box with toggleable Chat Tab and Send button.

@onready var panel: PanelContainer = $PanelContainer
@onready var chat_log: RichTextLabel = $PanelContainer/VBoxContainer/ChatLog
@onready var message_input: LineEdit = $PanelContainer/VBoxContainer/InputHBox/MessageInput
@onready var send_btn: Button = $PanelContainer/VBoxContainer/InputHBox/SendBtn
@onready var tab_toggle_btn: Button = $TabToggleBtn

var is_minimized: bool = false

func _ready():
	GameState.chat_received.connect(_on_chat_received)
	message_input.text_submitted.connect(_on_text_submitted)
	send_btn.pressed.connect(_on_send_pressed)
	tab_toggle_btn.pressed.connect(_on_tab_toggle_pressed)
	
	# Initial welcome in chat
	chat_log.append_text("[color=#85c1e9][i]Welcome to the Realm! Press Enter or type below to chat.[/i][/color]\n")
	
	# Lock gameplay WASD and attacks while typing in chat
	message_input.focus_entered.connect(func(): GameState.set_ui_modal_open(true))
	message_input.focus_exited.connect(func(): GameState.set_ui_modal_open(false))

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("chat_toggle"):
		if is_minimized:
			_set_minimized(false)
		if message_input.has_focus():
			message_input.release_focus()
		else:
			message_input.grab_focus()
			get_viewport().set_input_as_handled()

func _on_tab_toggle_pressed():
	_set_minimized(not is_minimized)

func _set_minimized(minimized: bool):
	is_minimized = minimized
	panel.visible = not is_minimized
	if is_minimized:
		tab_toggle_btn.text = "[+] Chat"
	else:
		tab_toggle_btn.text = "[-] Chat"
		message_input.grab_focus()

func _on_send_pressed():
	_on_text_submitted(message_input.text)

func _on_text_submitted(text: String):
	text = text.strip_edges()
	if text.length() > 0:
		var sender = GameState.local_player_name
		NetworkManager.send_packet({
			"type": "chat",
			"sender": sender,
			"text": text,
			"is_sys": false
		})
		if NetworkManager.is_solo_mode:
			GameState.emit_signal("chat_received", sender, text, false)
		message_input.clear()
	message_input.release_focus()

func _on_chat_received(sender: String, message: String, is_system: bool):
	SoundManager.play("chat", -6.0)
	if is_system:
		chat_log.append_text("[color=#f39c12]* [b]%s[/b]: %s[/color]\n" % [sender, message])
	elif sender == GameState.local_player_name:
		chat_log.append_text("[color=#5dade2][b]%s[/b]:[/color] %s\n" % [sender, message])
	else:
		chat_log.append_text("[color=#aed6f1][b]%s[/b]:[/color] %s\n" % [sender, message])
		
	# Un-minimize if a new message arrives
	if is_minimized:
		tab_toggle_btn.text = "[*] Chat (New!)"
