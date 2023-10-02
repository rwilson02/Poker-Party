extends Node

signal player_connected(peer_id, player_info)
signal player_disconnected(peer_id)
signal server_disconnected()
signal test_player_conditions(players_remaining)
signal state_updated()
signal upnp_complete(possible_error)

const PORT = 17160 # 13! / 9!, AKQJ
const DEFAULT_IP = "127.0.0.1"
const MAX_CONNECTIONS = 10

var players = {}
var player_info = {
	"name": "Player",
	"cards": [],
	"chips": 200,
	"current_bet": 0
}
var game_state = {
	"pot": 0,
	"comm_cards": [],
	"active_players": [],
	"folded_players": [],
	"losers": []
}
var discovery_thread: Thread = null
var upnp: UPNP = null

func _ready():
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	discovery_thread = Thread.new()
	discovery_thread.start(attempt_upnp.bind(PORT))

func join_game(address = ""):
	if address.is_empty():
		address = DEFAULT_IP
	
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, PORT)
	if error: return error
	multiplayer.multiplayer_peer = peer

func create_game():
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_CONNECTIONS)
	if error: return error
	multiplayer.multiplayer_peer = peer
	
	players[1] = player_info
	player_connected.emit(1, player_info)
	test_player_conditions.emit(1)

func _on_player_connected(id):
	_register_player.rpc_id(id, player_info)

@rpc("any_peer", "reliable")
func _register_player(new_player_info):
	var new_player_id = multiplayer.get_remote_sender_id()
	players[new_player_id] = new_player_info
	player_connected.emit(new_player_id, new_player_info)
	test_player_conditions.emit(players.keys().size())

func _on_player_disconnected(id):
#	players.erase(id)
	player_disconnected.emit(id)
	test_player_conditions.emit(players.keys().size())
	
	if game_state["active_players"].size() > 0:
		game_state["losers"].append(id)
		game_state["folded_players"].append(id)
		game_state.pot += players[id].chips

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
	return game_state["active_players"].size() - game_state["folded_players"].size()

@rpc("authority", "call_local", "reliable", 2)
func sync_data(player_data, rules, state):
	Netgame.players = player_data
	Rules.RULES = rules
	Netgame.game_state = state
#	prints(multiplayer.get_unique_id(), "data received")
	state_updated.emit()

func attempt_upnp(port: int):
	upnp = UPNP.new()
	print(IP.get_local_interfaces())
	var err = upnp.discover()
	
	if err != OK:
		push_error("UPNP error: %s" % str(err))
		upnp_complete.emit(err)
		return
	
	var gateway = upnp.get_gateway()
	if gateway and gateway.is_valid_gateway():
		upnp.add_port_mapping(port, port, ProjectSettings.get_setting("application/config/name"), "UDP", 60*60*12) # 12 hours
		upnp_complete.emit(OK)

func _exit_tree():
	if discovery_thread:
		discovery_thread.wait_to_finish()
	upnp.delete_port_mapping(PORT, "UDP")
