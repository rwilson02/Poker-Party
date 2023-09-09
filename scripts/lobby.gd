extends Node

signal player_connected(peer_id, player_info)
signal player_disconnected(peer_id)
signal server_disconnected()

const PORT = 7000
const DEFAULT_IP = "127.0.0.1"
const MAX_CONNECTIONS = 10

var players = {}
var players_loaded = 0

var player_info = {
	"name": "Player",
	"cards": [],
	"chips": 0
}

@onready var player_display = $PlayerDisplay/MarginContainer/RichTextLabel
@onready var address_bar = $Control/HBoxContainer/VBoxContainer/Address
@onready var other_buttons = $Control/HBoxContainer
@onready var start_button = $Control/HostButton
@onready var leave_button = $Control/PlayerButton

func _ready():
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	player_connected.connect(update_player_display)
	player_disconnected.connect(update_player_display)

func join_game(address = ""):
	if address.is_empty():
		address = DEFAULT_IP
	
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, PORT)
	if error: return error
	multiplayer.multiplayer_peer = peer
	
	other_buttons.visible = false
	leave_button.visible = true

func create_game():
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_CONNECTIONS)
	if error: return error
	multiplayer.multiplayer_peer = peer
	
	players[1] = player_info
	player_connected.emit(1, player_info)
	other_buttons.visible = false
	start_button.visible = true

func remove_multiplayer_peer():
	multiplayer.multiplayer_peer = null

func _on_player_connected(id):
	_register_player.rpc_id(id, player_info)

@rpc("any_peer", "reliable")
func _register_player(new_player_info):
	var new_player_id = multiplayer.get_remote_sender_id()
	players[new_player_id] = new_player_info
	player_connected.emit(new_player_id, new_player_info)
	test_start()

func _on_player_disconnected(id):
	players.erase(id)
	player_disconnected.emit(id)
	test_start()

func _on_connected_ok():
	var peer_id = multiplayer.get_unique_id()
	players[peer_id] = player_info
	player_connected.emit(peer_id, player_info)

func _on_connected_fail():
	remove_multiplayer_peer()

func _on_server_disconnected():
	remove_multiplayer_peer()
	server_disconnected.emit()

func test_start():
	start_button.disabled = false if players.keys().size() >= 2 else true

func update_player_display(_id = null, _info = null):
	var template_string = "%s\n"
	
	player_display.clear()
	if not multiplayer.has_multiplayer_peer(): return
	
	player_display.push_font_size(20)
	for player_id in players:
		if player_id == 1:
			player_display.push_color(Color.GOLD)
			player_display.add_text(template_string % players[player_id].name)
			player_display.pop()
		elif player_id == multiplayer.get_unique_id():
			player_display.push_color(Color.LIGHT_BLUE)
			player_display.add_text(template_string % players[player_id].name)
			player_display.pop()
		else:
			player_display.add_text(template_string % players[player_id].name)
	player_display.pop()

func on_join_button():
	join_game(address_bar.text)

func on_leave_button():
	player_disconnected.emit(multiplayer.get_unique_id())
	remove_multiplayer_peer()
	update_player_display()
	
	leave_button.visible = false
	other_buttons.visible = true

func on_start_button():
	start_game.rpc()

@rpc("call_local", "reliable")
func start_game():
	get_parent().start_game()
