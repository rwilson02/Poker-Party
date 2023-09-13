extends Node

signal all_responses_received

@onready var DISPLAY = $Display
@onready var BETTING = $Betting

var player_responses = 0

enum STAGE {AWAITING, ANTE, PREBETTING, BETTING, SHOWDOWN, RULE_CHANGE}

var active_player_order: Array
var saved_player_order: Array
var folded_players: Array
var losers: Array
var round_start_index = -1
var pot = 0
var deck: Array
var round_state = STAGE.AWAITING
var rounds_remaining = Rules.RULES["GAMEPLAY_ROUNDS"]

var community_cards: Array

func _ready():
	rpc_id(1, "player_ready")

@rpc("any_peer", "call_local", "reliable")
func player_ready():
	prints(multiplayer.get_remote_sender_id(), "ready")
	player_responses += 1
	if player_responses == Netgame.players.keys().size():
		player_responses = 0
		gameplay_loop()

# Server-side function to get values back from players
@rpc("any_peer", "reliable", "call_local")
func receive_from_all(value: Variant):
	player_responses += 1
	
	match round_state:
		STAGE.ANTE:
			if value == null:
				losers.append(multiplayer.get_remote_sender_id())
			else:
				Netgame.players[multiplayer.get_remote_sender_id()].chips -= value
				pot += value
	
	if player_responses == active_player_order.size():
		player_responses = 0
		all_responses_received.emit()

@rpc("any_peer", "reliable", "call_local")
func receive_from_one(value: Variant):
	all_responses_received.emit()

# Corresponding client-side function to send those values
func send_to_server(value: Variant, needs_everyone: bool = true):
	if needs_everyone:
		receive_from_all.rpc_id(1, value)
	else:
		receive_from_one.rpc_id(1, value)

@rpc("authority", "call_local", "reliable")
func sync_data(data: Variant):
	Netgame.players = data
	DISPLAY.update_display()

func gameplay_loop():
	print("play ball")
	
	for id in Netgame.players:
		if not id in losers:
			active_player_order.append(id)
	active_player_order.shuffle()
	saved_player_order = active_player_order.duplicate()
	
	while(active_player_order.size() > 1 or rounds_remaining > 0):
		round_start_index += 1
		rounds_remaining -= 1
		active_player_order.map(func(c): return absi(c))
		deck = range(0, Rules.get_deck_size())
		deck.shuffle()
		
		#get ante
		round_state = STAGE.ANTE
		for id in active_player_order:
			get_ante.rpc_id(id)
		await all_responses_received
		sync_data.rpc(Netgame.players)
		
#		print("should be done then")
#		print(pot)
		
		# do initial deal (player hands and comm cards)
		for i in Rules.RULES["COMM_CARDS"]:
			community_cards.append(deck.pop_back())
		for id in active_player_order:
			for i in Rules.RULES["HOLE_CARDS"]:
				Netgame.players[id].cards.append(deck.pop_back())
		sync_data.rpc(Netgame.players)
		
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
	var me = Netgame.me()
	if me.chips <= 0:
		send_to_server(null)
	else:
		var ante = mini(me.chips, Rules.RULES["ANTE"])
		send_to_server(ante)
