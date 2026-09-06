extends Node

# SoundManager Autoload
# Plays lightweight sound effects globally

var sounds = {}

func _ready():
	_load_sound("slash", "res://assets/sounds/slash.wav")
	_load_sound("hit", "res://assets/sounds/hit.wav")
	_load_sound("pickup", "res://assets/sounds/pickup.wav")
	_load_sound("levelup", "res://assets/sounds/levelup.wav")
	_load_sound("chat", "res://assets/sounds/chat.wav")

func _load_sound(sound_name: String, path: String) -> void:
	if ResourceLoader.exists(path):
		var stream = load(path)
		if stream:
			sounds[sound_name] = stream

func play(sound_name: String, volume_db: float = 0.0) -> void:
	if not sounds.has(sound_name):
		return
	var player = AudioStreamPlayer.new()
	player.stream = sounds[sound_name]
	player.volume_db = volume_db
	player.autoplay = true
	add_child(player)
	player.finished.connect(func(): player.queue_free())
