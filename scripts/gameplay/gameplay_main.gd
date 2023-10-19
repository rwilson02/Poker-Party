extends Node

signal all_responses_received
signal next_round

@onready var DISPLAY = $Display
@onready var BETTING = $Betting
@onready var MENU = $Menus

var player_responses = 0
var round_start_index = -1
var deck: Array

func _ready():
	rpc_id(1, "player_ready")
	
	Netgame.server_disconnected.connect(MENU.okay_get_out)

@rpc("any_peer", "call_local", "reliable")
func player_ready():
	prints(multiplayer.get_remote_sender_id(), "ready")
	player_responses += 1
	if player_responses == Netgame.players.keys().size():
		player_responses = 0
		start_game()

func start_game():
	for id in Netgame.players:
		Netgame.game_state["active_players"].append(id)
	Netgame.game_state["active_players"].shuffle()
	
	while Netgame.game_state["active_players"].size() > 1 and round_start_index < Rules.RULES["GAMEPLAY_ROUNDS"]:
		await gameplay_loop()
	
	MENU.show_end_screen.rpc()

func gameplay_loop():
	initial_round_tasks()
	Netgame.sync_data.rpc(Netgame.players, Rules.RULES, Netgame.game_state)
	deal_cards()
	Netgame.sync_data.rpc(Netgame.players, Rules.RULES, Netgame.game_state)
	
	# First betting round has to happen no matter what
	await BETTING.do_betting_round(round_start_index)
	# Other betting rounds may be able to be skipped
	# (Live players = Players who are active (haven't lost) and haven't folded)
	if Netgame.get_live_players() > 1:
		while Netgame.game_state["comm_cards"].size() < Rules.RULES["COMM_CARDS"]:
			Netgame.game_state["comm_cards"].append(deck.pop_back())
			Netgame.sync_data.rpc(Netgame.players, Rules.RULES, Netgame.game_state)
			# Another betting round
			await BETTING.do_betting_round(round_start_index)
			# Don't do more if there's one live player
			if Netgame.get_live_players() == 1: break
	
	var winners = get_winners()
	if winners.size() > 1:
		display_showdown()
	credit_winners(winners)
	Netgame.sync_data.rpc(Netgame.players, Rules.RULES, Netgame.game_state)
	
	# Anyone with no chips by now has lost the game
	# Also remove player cards because we're going to the next round
	for id in Netgame.game_state.active_players:
		Netgame.players[id]["cards"].clear()
		if Netgame.players[id]["chips"] <= 0:
			Netgame.game_state["losers"].append(id)
	clear_losers()
	
	await do_rule_change()
	
	Netgame.sync_data.rpc(Netgame.players, Rules.RULES, Netgame.game_state)
	next_round.emit()

func initial_round_tasks():
	round_start_index += 1
	deck = range(0, Rules.get_deck_size())
	deck.shuffle()
	
	Netgame.game_state["folded_players"].clear()
	Netgame.game_state["comm_cards"].clear()
	for id in Netgame.game_state.active_players:
		get_ante(id)

func deal_cards():
	for i in (Rules.RULES["CARDS_PER_HAND"] - Rules.RULES["HOLE_CARDS"]):
		if i >= Rules.RULES["COMM_CARDS"]: break
		Netgame.game_state["comm_cards"].append(deck.pop_back())
#		print("given comm card")
	for i in Rules.RULES["HOLE_CARDS"]:
		for id in Netgame.game_state.active_players:
#			prints("given hole card to", id)
			Netgame.players[id].cards.append(deck.pop_back())

# Returns array of [winner id, winning hand] from best to worst
func get_winners() -> Array:
	var winners = []
	
	for id in Netgame.game_state.active_players:
		if id not in Netgame.game_state.folded_players:
			winners.append([id, \
			Hand.get_best_hand(Netgame.players[id].cards + Netgame.game_state.comm_cards)])
	winners.sort_custom(func(a,b): return Hand.sort(a[1], b[1]))
	
	return winners

func credit_winners(winners: Array):
	var winning_players = Rules.RULES.CURRENT_CHANGES.count("TRICKLE_DOWN") + 1
	var winning_divisions = {
		1: [1],
		2: [0.7, 0.3],
		3: [0.6, 0.3, 0.1]
	}
	var divisions = winning_divisions[winning_players]
	var original_pot = Netgame.game_state.pot
	
	# Give everyone their share
	for idx in divisions.size():
		var winner = winners[idx][0]
		var value = roundi(original_pot * divisions[idx])
		Netgame.players[winner].chips += value
		Netgame.game_state.pot -= value
	# What to do with leftovers
	if Netgame.game_state.pot > 0:
		Netgame.players[winners[divisions.size() - 1][0]] += Netgame.game_state.pot
	elif Netgame.game_state.pot < 0:
		Netgame.players[winners[0][0]] += Netgame.game_state.pot
	
	Netgame.game_state.pot = 0

func display_showdown():
	pass

func get_players_by_chips() -> Array:
	var players = []
	for id in Netgame.game_state.active_players:
		players.append([id, Netgame.players[id].chips])
	players.sort_custom(func(a,b): return a[1] > b[1])
	return players

func do_rule_change():
	var player_chips = get_players_by_chips()
	var valid = false
	while not valid and Netgame.game_state.active_players.size() > 1:
		var potential_player = player_chips.pop_back()
		if potential_player != null:
			var losingest_player = potential_player[0]
			if losingest_player in Netgame.game_state["active_players"]:
				MENU.show_rule_changer.rpc_id(losingest_player)
				valid = await MENU.okay_continue
		else: break

#func gameplay_loop():
#	print("play ball")
#
#	for id in Netgame.players:
#		Netgame.game_state["active_players"].append(id)
#	Netgame.game_state["active_players"].shuffle()
#
#	while(Netgame.game_state["active_players"].size() > 1 and round_start_index < Rules.RULES["GAMEPLAY_ROUNDS"]):
#		round_start_index += 1
#		print(Rules.RULES.CURRENT_CHANGES) # TODO: Add list of changes in icon form somewhere onscreen
#		print("%dx%d" % [Rules.RULES["SUITS"], Rules.RULES["VALS_PER_SUIT"]])
#		deck = range(0, Rules.get_deck_size())
#		deck.shuffle()
#		print("round start")
#
		#get ante
#		Netgame.game_state["folded_players"].clear()
#		Netgame.game_state["comm_cards"].clear()
#		for id in Netgame.game_state.active_players:
#			get_ante(id)
#		Netgame.sync_data.rpc(Netgame.players, Rules.RULES, Netgame.game_state)
#
		# do initial deal (player hands and comm cards)
#		for i in (Rules.RULES["CARDS_PER_HAND"] - Rules.RULES["HOLE_CARDS"]):
#			if i >= Rules.RULES["COMM_CARDS"]: break
#			Netgame.game_state["comm_cards"].append(deck.pop_back())
#			print("given comm card")
#		for i in Rules.RULES["HOLE_CARDS"]:
#			for id in Netgame.game_state.active_players:
#				prints("given hole card to", id)
#				Netgame.players[id].cards.append(deck.pop_back())
#		Netgame.sync_data.rpc(Netgame.players, Rules.RULES, Netgame.game_state)
#
		# do first betting round
#		await BETTING.do_betting_round(round_start_index)
#
		# Don't need the rest of the comm cards if everyone else folded
#		if Netgame.get_live_players() > 1:
#			# while current comm cards < rules comm cards
#			while Netgame.game_state["comm_cards"].size() < Rules.RULES["COMM_CARDS"]:
#				# show comm card
#				print("new comm card")
#				Netgame.game_state["comm_cards"].append(deck.pop_back())
#				Netgame.sync_data.rpc(Netgame.players, Rules.RULES, Netgame.game_state)
#				# do betting round
#				await BETTING.do_betting_round(round_start_index)
#				if Netgame.get_live_players() == 1: break
#
#		var winner
#		# if there are still players
#		if Netgame.get_live_players() > 1:
#			winner = do_showdown()
#		else:
#			winner = Netgame.game_state["active_players"].filter(func(c): \
#				return c not in Netgame.game_state.folded_players)
#			winner = winner.pop_back()
#		Netgame.players[winner].chips += Netgame.game_state.pot
#		Netgame.game_state.pot = 0
#		print("round over, %s won" % winner)
#		Netgame.sync_data.rpc(Netgame.players, Rules.RULES, Netgame.game_state)
#
		# do rule change
#		for id in Netgame.game_state.active_players:
#			Netgame.players[id]["cards"].clear()
#			if Netgame.players[id]["chips"] == 0:
#				Netgame.game_state["losers"].append(id)
#		clear_losers()
#
#		var player_chips = []
#		for id in Netgame.game_state.active_players:
#			player_chips.append([id, Netgame.players[id].chips])
#		player_chips.sort_custom(func(a,b): return a[1] > b[1])
#		var is_good = false
#
#		while not is_good and Netgame.game_state["active_players"].size() > 1:
#			var potential_player = player_chips.pop_back()
#			if potential_player == null: 
#				break
#			else:
#				var losingest_player = potential_player[0]
#				if losingest_player in Netgame.game_state["active_players"]:
#					MENU.show_rule_changer.rpc_id(losingest_player)
#					is_good = await MENU.okay_continue
#
#		Netgame.sync_data.rpc(Netgame.players, Rules.RULES, Netgame.game_state)
#		print("alright next round")
#
#	print("oh huh the game is over now")
#	MENU.show_end_screen.rpc()

func get_ante(player_id):
	var me = Netgame.players[player_id]
	if me.chips <= 0:
		if player_id not in Netgame.game_state.losers:
			Netgame.game_state["losers"].append(player_id)
	else:
		var ante = mini(me.chips, Rules.RULES["ANTE"])
		me.chips -= ante
		Netgame.game_state.pot += ante
		prints("took", ante, "chips from", player_id)

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
