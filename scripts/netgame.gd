extends Node

signal player_connected(peer_id, player_info)
signal player_disconnected(peer_id)
signal server_disconnected()
signal test_player_conditions(players_remaining)
signal state_updated()

const DEFAULT_PORT = 17160 # 13! / 9!, AKQJ
const DEFAULT_IP = "127.0.0.1"
const MAX_CONNECTIONS = 10

@export var players = {}
var player_info = {
	"name": "Player",
	"cards": [],
	"chips": 0,
	"current_bet": 0,
	"awaiting": false,
	
	"icon": 0,
	"color": Color.BLACK
}
@export var game_state = {
	"pot": 0,
	"comm_cards": [],
	"active_players": [],
	"folded_players": [],
	"losers": []
}
var discovery_thread: Thread = null

func _ready():
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func join_game(address = "", port = ""):
	if address.is_empty():
		address = DEFAULT_IP
	if port.is_empty():
		port = DEFAULT_PORT
	
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, int(port))
	if error: return error
	multiplayer.multiplayer_peer = peer

func create_game(port = ""):
	if typeof(port) == TYPE_STRING:
		port = DEFAULT_PORT if port.is_empty() else int(port)
	elif typeof(port) != TYPE_INT:
		port = DEFAULT_PORT
	
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, MAX_CONNECTIONS)
	if error: return error
	multiplayer.multiplayer_peer = peer
	
	players[1] = player_info
	player_connected.emit(1, player_info)
	test_player_conditions.emit(1)

func _on_player_connected(id):
	if multiplayer.is_server() and game_state.active_players.size() > 0:
		multiplayer.multiplayer_peer.get_peer(id).peer_disconnect_now()
	else:
		_register_player.rpc_id(id, player_info)

@rpc("any_peer", "reliable")
func _register_player(new_player_info):
	var new_player_id = multiplayer.get_remote_sender_id()
	players[new_player_id] = new_player_info
	player_connected.emit(new_player_id, new_player_info)
	test_player_conditions.emit(players.keys().size())

func _on_player_disconnected(id):
	if id in players:
		if game_state.active_players.size() > 0:
			game_state.losers.append(id)
			game_state.folded_players.append(id)
			game_state.pot += players[id].chips
#			if multiplayer.is_server():
#				sync_data.rpc(Netgame.players, Rules.RULES, Netgame.game_state)
		else:
			players.erase(id)
		
		player_disconnected.emit(id)
		test_player_conditions.emit(players.keys().size())

func _on_connected_ok():
	var peer_id = multiplayer.get_unique_id()
	players[peer_id] = player_info
	player_connected.emit(peer_id, player_info)

func _on_connected_fail():
	multiplayer.multiplayer_peer = null

func _on_server_disconnected():
	multiplayer.multiplayer_peer = null
	server_disconnected.emit()

func me():
	return players[multiplayer.get_unique_id()]

func get_live_players():
	return game_state.active_players.size() - game_state.folded_players.size()

#@rpc("authority", "call_local", "reliable", 2)
#func sync_data(player_data, rules, state):
#	Netgame.players = player_data
#	Rules.RULES = rules
#	Netgame.game_state = state
#	state_updated.emit()

func reset():
	game_state = {
		"pot": 0,
		"comm_cards": [],
		"active_players": [],
		"folded_players": [],
		"losers": []
	}
	players.clear()
