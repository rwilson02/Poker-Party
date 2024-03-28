extends Node

signal settings_changed

var lobby = preload("res://scenes/Lobby.tscn")
var gameplay = preload("res://scenes/Gameplay.tscn")
var first_boot = true

func _ready():
	var actions = ["check_call", "bet_raise", "fold"]
	var settings = ["check_ctrl", "bet_ctrl", "fold_ctrl"]
	var events = [KEY_V, KEY_B, KEY_N]
	
	var config = ConfigFile.new()
	var err = config.load("user://config.cfg")
	if not err:
		for i in 3:
			InputMap.action_erase_events(actions[i])
			var input = InputEventKey.new()
			input.keycode = config.get_value("settings", settings[i], events[i])
			InputMap.action_add_event(actions[i], input)

func start_game():
	first_boot = false
	goto_scene(gameplay)

func end_game():
	goto_scene(lobby)
	Netgame.reset()

func goto_scene(scene: PackedScene):
	call_deferred("_real_goto_scene", scene)

func _real_goto_scene(scene: PackedScene):
	get_child(0).free()
	var new_scene = scene.instantiate()
	add_child(new_scene, true)
	if scene == gameplay:
		new_scene.MENU.get_out.connect(end_game)

func _exit_tree():
	if multiplayer:
		if multiplayer.is_server():
			multiplayer.server_disconnected.emit()
		else:
			multiplayer.peer_disconnected.emit(multiplayer.get_unique_id())
