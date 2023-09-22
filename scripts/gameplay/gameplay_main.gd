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

func gameplay_loop():
	print("play ball")
	
	for id in Netgame.players:
		Netgame.game_state["active_players"].append(id)
	Netgame.game_state["active_players"].shuffle()
	
	while(Netgame.game_state["active_players"].size() > 1 and round_start_index < Rules.RULES["GAMEPLAY_ROUNDS"]):
		round_start_index += 1
		deck = range(0, Rules.get_deck_size())
		deck.shuffle()
		print("round start")
		
		#get ante
		Netgame.game_state["folded_players"].clear()
		Netgame.game_state["comm_cards"].clear()
		for id in Netgame.game_state.active_players:
			Netgame.players[id]["cards"].clear()
			get_ante(id)
		clear_losers()
		Netgame.sync_data.rpc(Netgame.players, Netgame.game_state)
		
		# do initial deal (player hands and comm cards)
		for i in (Rules.RULES["COMM_CARDS"] - Rules.RULES["HOLE_CARDS"]):
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
				print("new comm card")
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
			winner = winner.pop_back()
		Netgame.players[winner].chips += Netgame.game_state.pot
		Netgame.game_state.pot = 0
		print("round over, %s won" % winner)
		
		# do rule change
	
	print("oh huh the game is over now")

func get_ante(player_id):
	var me = Netgame.players[player_id]
	if me.chips <= 0:
		if player_id not in Netgame.game_state.losers
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
