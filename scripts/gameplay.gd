extends Node

@onready var players: Dictionary = Netgame.players
var ready_players = 0

enum STAGE {AWAITING, ANTE, PREBETTING, BETTING}

var active_player_order: Array
var folded_players: Array
var losers: Array
var round_start_index = -1
var pot = 0
var deck = range(0, Rules.get_deck_size())
var round_state = STAGE.AWAITING
var rounds_remaining = Rules.RULES["GAMEPLAY_ROUNDS"]

func _ready():
	rpc_id(1, "player_ready")

@rpc("any_peer", "call_local", "reliable")
func player_ready():
	prints(multiplayer.get_remote_sender_id(), "ready")
	ready_players += 1
	if ready_players == players.keys().size():
		gameplay_loop()

# Server-side function to get values back from players
@rpc("any_peer", "reliable", "call_local")
func receive_value(value: Variant):
	match round_state:
		STAGE.ANTE:
			if value == null:
				losers.append(multiplayer.get_remote_sender_id())
			else:
				players[multiplayer.get_remote_sender_id()].chips -= value
				pot += value

# Corresponding client-side function to send those values
func send_to_server(value: Variant):
	receive_value.rpc_id(1, value)

func gameplay_loop():
	print("play ball")
	
	for player_id in players:
		active_player_order.append(player_id)
	active_player_order.shuffle()
	
	while(active_player_order.size() > 1 or rounds_remaining > 0):
		round_start_index += 1
		rounds_remaining -= 1
		active_player_order.map(func(c): return absi(c))
		
		round_state = STAGE.ANTE
		for player_id in active_player_order.size():
			get_ante.rpc_id(player_id)
		
		# do initial deal (player hands and comm cards)
		# do first betting round
		# while current comm cards < rules comm cards
		#	 show comm card
		#	 do betting round
		# if there are still players
		#	 do showdown
		# award pot to winner
		# do rule change

@rpc("any_peer", "call_local", "reliable")
func get_ante():
	var me = Netgame.players[multiplayer.get_unique_id()]
	if me.chips <= 0:
		send_to_server(null)
	else:
		var ante = mini(me.chips, Rules.RULES["ANTE"])
		send_to_server(ante)
