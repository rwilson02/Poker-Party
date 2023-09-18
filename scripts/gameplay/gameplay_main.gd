extends Node

signal all_responses_received

@onready var DISPLAY = $Display
@onready var BETTING = $Betting

var player_responses = 0
var round_start_index = -1
var deck: Array

func _ready():
	rpc_id(1, "player_ready")

@rpc("any_peer", "call_local", "reliable")
func player_ready():
	prints(multiplayer.get_remote_sender_id(), "ready")
	player_responses += 1
	if player_responses == Netgame.players.keys().size():
		player_responses = 0
		gameplay_loop()

## Server-side function to get values back from players
#@rpc("any_peer", "reliable", "call_local")
#func receive_from_all(value: Variant):
#	player_responses += 1
#	if player_responses == Netgame.game_state["active_players"].size():
#		player_responses = 0
#		all_responses_received.emit()
#
#@rpc("any_peer", "reliable", "call_local")
#func receive_from_one(value: Variant):
#	all_responses_received.emit()
#
## Corresponding client-side function to send those values
#func send_to_server(value: Variant, needs_everyone: bool = true):
#	if needs_everyone:
#		receive_from_all.rpc_id(1, value)
#	else:
#		receive_from_one.rpc_id(1, value)

func gameplay_loop():
	print("play ball")
	
	for id in Netgame.players:
		Netgame.game_state["active_players"].append(id)
	Netgame.game_state["active_players"].shuffle()
	
	while(Netgame.game_state["active_players"].size() > 1 or round_start_index < Rules.RULES["GAMEPLAY_ROUNDS"]):
		round_start_index += 1
		deck = range(0, Rules.get_deck_size())
		deck.shuffle()
		
		#get ante
		Netgame.game_state["folded_players"].clear()
		for id in Netgame.game_state.active_players:
			get_ante(id)
		clear_losers()
		Netgame.sync_data.rpc(Netgame.players, Netgame.game_state)
		
		# do initial deal (player hands and comm cards)
		for i in Rules.RULES["COMM_CARDS"]:
			Netgame.game_state["comm_cards"].append(deck.pop_back())
			print("given comm card")
		for i in Rules.RULES["HOLE_CARDS"]:
			for id in Netgame.game_state.active_players:
				prints("given hole card to", id)
				Netgame.players[id].cards.append(deck.pop_back())
		Netgame.sync_data.rpc(Netgame.players, Netgame.game_state)
		
		# do first betting round
		await BETTING.do_betting_round(round_start_index)
		
		# Don't need the rest of the comm cards if everyone else folded
		if Netgame.get_live_players() > 1:
			# while current comm cards < rules comm cards
			while Netgame.game_state["comm_cards"].size() < Rules.RULES["COMM_CARDS"]:
				# show comm card
				Netgame.game_state["comm_cards"].append(deck.pop_back())
				Netgame.sync_data.rpc(Netgame.players, Netgame.game_state)
				# do betting round
				await BETTING.do_betting_round(round_start_index)
				if Netgame.get_live_players() == 1: break
		
		var winner
		# if there are still players
		if Netgame.get_live_players() > 1:
			winner = do_showdown()
		else:
			winner = Netgame.game_state["active_players"].filter(func(c): \
				return c not in Netgame.game_state.folded_players)
		Netgame.players[winner].chips += Netgame.game_state.pot
		Netgame.game_state.pot = 0
		
		# do rule change

func get_ante(player_id):
	var me = Netgame.players[player_id]
	if me.chips <= 0:
		Netgame.game_state["losers"].append(player_id)
	else:
		var ante = mini(me.chips, Rules.RULES["ANTE"])
		me.chips -= ante
		Netgame.game_state.pot += ante

func clear_losers():
	for id in Netgame.game_state.losers:
		Netgame.game_state["active_players"].erase(id)

func do_showdown():
	var player_bests = []
	
	for id in Netgame.game_state.active_players:
		if id not in Netgame.game_state.folded_players:
			player_bests.append([id, \
			Hand.get_best_hand(Netgame.players[id].cards + Netgame.game_state.comm_cards)])
	player_bests.sort_custom(func(a,b): return Hand.sort(a[1], b[1]))
	
	for combi in player_bests:
		prints(combi[0], "had", combi[1].get_name())
	
	return player_bests[0][0]
