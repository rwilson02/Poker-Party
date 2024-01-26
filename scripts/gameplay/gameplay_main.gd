extends Node

signal all_responses_received
signal next_round

@onready var DISPLAY = $Display
@onready var BETTING = $Betting
@onready var MENU = $Menus
@onready var TIMER = $Timer

var player_responses = 0
var round_start_index = -1
var restart_requested = false
var deck: Array

func _ready():
	Netgame.server_disconnected.connect(MENU.okay_get_out)
	MENU.do_it_again.connect(start_game)
	MENU.request_restart.connect(func(): restart_requested = true)
	BETTING.DISPLAY = DISPLAY
	
	rpc_id(1, "player_ready")

@rpc("any_peer", "call_local", "reliable")
func player_ready():
	prints(multiplayer.get_remote_sender_id(), "ready")
	player_responses += 1
	if player_responses == Netgame.players.keys().size():
		player_responses = 0
		
		DISPLAY.get_node("MultiplayerSynchronizer").set_visibility_for(0, true)
		
		start_game(false)

func start_game(restart):
	MENU.hide_end_screen.rpc()
	if restart:
		Rules.reset()
		
		MENU.get_node("Pause/VBoxContainer/Restart").text = "RESTART"
		MENU.get_node("Pause/VBoxContainer/Restart").disabled = false
	
	Netgame.game_state = {
		"pot": 0,
		"comm_cards": [],
		"active_players": [],
		"folded_players": [],
		"losers": []
	}
	
	for id in Netgame.players:
		Netgame.game_state.active_players.append(id)
		Netgame.players[id].chips = Rules.RULES.INITIAL_CHIPS
	Netgame.game_state.active_players.shuffle()
	
	DISPLAY.setup_icons(Netgame.game_state.active_players)
	
	while Netgame.game_state.active_players.size() > 1 and round_start_index < Rules.RULES.GAMEPLAY_ROUNDS:
		await gameplay_loop()
		if restart_requested: break
	
	if not restart_requested:
		MENU.show_end_screen.rpc()
	else:
		start_game(true)

func gameplay_loop():
	initial_round_tasks()
	deal_cards()
	TIMER.start(1)
	await TIMER.timeout
	
	# First betting round has to happen no matter what
	await BETTING.do_betting_round(round_start_index)
	# Other betting rounds may be able to be skipped
	# (Live players = Players who are active (haven't lost) and haven't folded)
	if Netgame.get_live_players() > 1 and not restart_requested:
		while Netgame.game_state.comm_cards.size() < Rules.RULES.COMM_CARDS:
			Netgame.game_state.comm_cards.append(deck.pop_back() | Rules.HIDDEN * int(Rules.odds(Rules.RULES.BLINDING)))
			TIMER.start(1)
			await TIMER.timeout
			# Another betting round
			await BETTING.do_betting_round(round_start_index)
			# Don't do more if there's one live player
			if Netgame.get_live_players() == 1 or restart_requested: break
	
	if not restart_requested:
		var winners = get_winners()
		if winners.size() > 1:
			DISPLAY.display_showdown.rpc(winners)
			TIMER.start(3 + winners.size())
			await TIMER.timeout
		credit_winners(winners)
		
		# Anyone with no chips by now has lost the game
		# Also remove player cards because we're going to the next round
		for id in Netgame.game_state.active_players:
			Netgame.players[id].cards.clear()
			if Netgame.players[id].chips <= 0:
				Netgame.game_state.losers.append(id)
		clear_losers()
		
		await do_rule_change()
	
	TIMER.start(1)
	await TIMER.timeout
	clear_losers() # Just to make sure
	Netgame.state_updated.emit()
	next_round.emit()

func initial_round_tasks():
	round_start_index += 1
	DISPLAY.log_to_chat("Round %d beginning." % (round_start_index + 1))
	deck = range(0, Rules.get_deck_size())
	for i in (Rules.RULES.SUITS * Rules.RULES.WILDS):
		deck.append(Rules.FREE_WILD)
	deck.shuffle()
	
	Netgame.game_state.folded_players.clear()
	Netgame.game_state.comm_cards.clear()
	for id in Netgame.game_state.active_players:
		get_ante(id)

func deal_cards():
	for i in (Rules.RULES.CARDS_PER_HAND - Rules.RULES.HOLE_CARDS):
		if i >= Rules.RULES.COMM_CARDS: break
		
		var card = deck.pop_back()
		if Rules.odds(Rules.RULES.BLINDING):
			card |= Rules.HIDDEN
		
		Netgame.game_state.comm_cards.append(card)
#		print("given comm card")
	var player_card_probs = []
	for i in Rules.RULES.HOLE_CARDS:
		player_card_probs.append(Rules.odds(Rules.RULES.BLINDING))
	for i in player_card_probs:
		for id in Netgame.game_state.active_players:
#			prints("given hole card to", id)
			Netgame.players[id].cards.append(deck.pop_back() | (Rules.HIDDEN * int(i)))

# Returns array of [winner id, winning hand] from best to worst
func get_winners() -> Array:
	var winners = []
	
	for id in Netgame.game_state.active_players:
		if id not in Netgame.game_state.folded_players:
#			prints("All possible hands from", id)
			var combined_cards = Netgame.players[id].cards.duplicate() + Netgame.game_state.comm_cards.duplicate()
#			print(Hand.hand_to_string(combined_cards))
			var best = Hand.get_best_hand(combined_cards)
#			prints("Best hand:", Hand.hand_to_string(best.cards))
			winners.append([id, best])
	winners.sort_custom(func(a,b): return Hand.sort(a[1], b[1]))
	
	# All wild should still win in lowball
	if Rules.RULES.BALL == -1:
		while winners.back()[1].rank == "AW":
			var back = winners.pop_back()
			winners.push_front(back)
	
	winners = winners.map(func(c): return [c[0], c[1].cards])
	
	return winners

func credit_winners(winners: Array):
	var players = winners.map(func(c): return c[0])
	var hands = winners.map(func(c): return c[1])
	
	var winning_players = Rules.RULES.WINNERS
	var winning_divisions = {
		1: [1],
		2: [0.7, 0.3],
		3: [0.55, 0.3, 0.15],
		4: [0.5, 0.25, 0.15, 0.1],
		5: [0.3, 0.25, 0.2, 0.15, 0.1]
	}
	var divisions = winning_divisions[winning_players]
	var original_pot = Netgame.game_state.pot
	
	var winner_groups = []
	var current_group = []
	for idx in players.size():
		if current_group.is_empty() or Hand.is_equal(hands[idx], hands[players.find(current_group[0])]):
			current_group.append(players[idx])
		else:
			winner_groups.append(current_group.duplicate())
			current_group.clear()
			current_group.append(players[idx])
	winner_groups.append(current_group.duplicate())
	current_group.clear()
	
	# Give everyone their share
	for idx in divisions.size():
		var group = winner_groups[idx] if idx < winner_groups.size() else null
		if group != null:
			for winner in group:
				var value = roundi(original_pot * divisions[idx] * (1.0 / group.size()))
				Netgame.players[winner].chips += value
				Netgame.game_state.pot -= value
				DISPLAY.chip_zoom_anim.rpc_id(winner, false)
	# What to do with leftovers
	if Netgame.game_state.pot > 0:
		Netgame.players[players[-1]].chips += Netgame.game_state.pot
	elif Netgame.game_state.pot < 0:
		Netgame.players[players[0]].chips += Netgame.game_state.pot
	
	Netgame.game_state.pot = 0
	
	# Print to chat
	var printed_group = winner_groups[0]
	var print_this = "Round %d over! " % (round_start_index + 1)
	match printed_group.size():
		1:
			print_this += ("player(%d) won." % printed_group[0])
		2:
			print_this += ("player(%d) and player(%d) won." % [printed_group[0], printed_group[1]])
		_:
			if printed_group.size() == Netgame.players.size():
				print_this += ("Everyone won.")
			else:
				var name_str = ""
				for id in printed_group:
					name_str += ("player(%d), " % id)
				var halves = name_str.rsplit(", ", false, 2)
				print_this += ", and ".join(halves)
	DISPLAY.log_to_chat(print_this)

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
			if losingest_player in Netgame.game_state.active_players \
			and not losingest_player in Netgame.game_state.losers:
				Netgame.players[losingest_player].awaiting = true
				MENU.show_rule_changer.rpc_id(losingest_player)
				valid = await MENU.okay_continue
				
				if valid: Netgame.players[losingest_player].awaiting = false
		else: break

func get_ante(player_id):
	var me = Netgame.players[player_id]
	if me.chips <= 0:
		if player_id not in Netgame.game_state.losers:
			Netgame.game_state.losers.append(player_id)
	else:
		var ante = mini(me.chips, Rules.RULES.ANTE)
		me.chips -= ante
		Netgame.game_state.pot += ante
#		prints("took", ante, "chips from", player_id)

func clear_losers():
	for id in Netgame.game_state.losers:
		Netgame.game_state.active_players.erase(id)
