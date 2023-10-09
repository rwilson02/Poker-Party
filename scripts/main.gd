extends Node

var lobby = preload("res://scenes/Lobby.tscn")
var gameplay = preload("res://scenes/Gameplay.tscn")

func _ready():
	pass

func start_game():
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
	if multiplayer.is_server():
		multiplayer.server_disconnected.emit()
	else:
		multiplayer.peer_disconnected.emit(multiplayer.get_unique_id())
