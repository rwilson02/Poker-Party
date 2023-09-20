extends Node

signal input_received(player_bet)

const name_tooltip_combos =[
	[
		["CHECK", "Do not place a bet just yet."],
		["BET", "Open the betting round with the below number of chips."]
	],
	[
		["CALL", "Match the current bet amount."],
		["RAISE", "Raise the current bet amount to the below number of chips."]
	]
]

@onready var bet_bar = $BetBar
@onready var check_call: Button = bet_bar.get_node("HBoxContainer/CheckCall")
@onready var bet_raise_button = bet_bar.get_node("HBoxContainer/BetRaise/Button")
@onready var bet_raise_input: SpinBox = bet_bar.get_node("HBoxContainer/BetRaise/Input")
@onready var fold = bet_bar.get_node("HBoxContainer/Fold")

var initial_bettor_index = 0
var bet_to_match = 0
var awaiting_player

func _ready():
	check_call.pressed.connect(button_pressed.bind("CALL"))
	bet_raise_button.pressed.connect(button_pressed.bind("RAISE"))
	fold.pressed.connect(button_pressed.bind("FOLD"))
	
	Netgame.player_disconnected.connect(player_disconnected)

func do_betting_round(start_index):
	if Netgame.get_live_players() == 1: return
	
	# Initial round of bets
	print("Begin betting round.")
	for i in Netgame.game_state["active_players"].size():
		if Netgame.get_live_players() == 1: break
		
		var got_bet
		var next_up = (i + start_index) % Netgame.game_state["active_players"].size()
		awaiting_player = Netgame.game_state.active_players[next_up]
		if awaiting_player not in Netgame.game_state.folded_players:
#			prints("paging", awaiting_player)
			get_bet_option.rpc_id(awaiting_player, 0)
			got_bet = await input_received
			Netgame.sync_data.rpc(Netgame.players, Netgame.game_state)
		
		if got_bet: 
			initial_bettor_index = Netgame.game_state["active_players"].find(awaiting_player)
			break
	
	# If nobody bet, leave
	if all_bets_equal():
		print("Everyone checked.")
		return
	
	# Keep it rolling around if people are there
	var index = initial_bettor_index
	while not all_bets_equal() and Netgame.get_live_players() > 1:
		index += 1
		var next_up = index % Netgame.game_state["active_players"].size()
		awaiting_player = Netgame.game_state.active_players[next_up]
		if awaiting_player not in Netgame.game_state.folded_players:
			prints("paging", awaiting_player)
			get_bet_option.rpc_id(awaiting_player, get_max_bet())
			await input_received
			Netgame.sync_data.rpc(Netgame.players, Netgame.game_state)
	
	# End of betting round
	for id in Netgame.game_state.active_players:
		Netgame.game_state.pot += Netgame.players[id].current_bet
		Netgame.players[id].current_bet = 0

@rpc("authority","call_local","reliable")
func get_bet_option(current_bet):
	# Show correct labels/tooltips on buttons
	var bet_stage = 0 if current_bet == 0 else 1
	check_call.text = name_tooltip_combos[bet_stage][0][0]
	check_call.tooltip_text = name_tooltip_combos[bet_stage][0][1]
	bet_raise_button.text = name_tooltip_combos[bet_stage][1][0]
	bet_raise_button.tooltip_text = name_tooltip_combos[bet_stage][1][1]
	
	# Enable/disable buttons as possible based on player chips
	bet_to_match = current_bet
	var bet_difference = bet_to_match - Netgame.me().current_bet
	var check_or_call = true if bet_to_match == 0 else Netgame.me().chips >= bet_difference
	var bet_or_raise = Netgame.me().chips >= Rules.RULES["MIN_BET"] if bet_to_match == 0 \
		else Netgame.me().chips >= (bet_to_match + Rules.RULES["MIN_BET"])
	
	# Those are positive checks, so invert to set disabled status
	check_call.disabled = not check_or_call
	bet_raise_button.disabled = not bet_or_raise
	bet_raise_input.editable = bet_or_raise # should be true when you can bet or raise
	
	# Set the min and max for the input
	bet_raise_input.min_value = Rules.RULES["MIN_BET"] if bet_to_match == 0 \
		else bet_to_match + Rules.RULES["MIN_BET"]
	bet_raise_input.max_value = Netgame.me().chips
	bet_raise_input.value = bet_raise_input.min_value
	
	# Show bet bar now that everything's settled
	bet_bar.visible = true
#	prints("bet bar for", multiplayer.get_unique_id(), "activated:", bet_bar.is_visible())

@rpc("any_peer","call_local","reliable")
func send_option(option, value):
	var sender = multiplayer.get_remote_sender_id()
	bet_to_match = get_max_bet()
	
	match option:
		"CALL":
			if bet_to_match == 0:
				prints(sender, "checks.")
			else:
				Netgame.players[sender].chips -= value
				Netgame.players[sender].current_bet += value
				prints(sender, "calls.")
		"RAISE":
			if bet_to_match == 0:
				Netgame.players[sender].chips -= value
				Netgame.players[sender].current_bet += value
				prints(sender, "opens with %d." % value)
			else:
				var bet_difference = value - Netgame.players[sender].current_bet
				Netgame.players[sender].chips -= bet_difference
				Netgame.players[sender].current_bet += bet_difference
				prints(sender, "raises to %d." % value)
		"FOLD":
			Netgame.game_state["folded_players"].append(sender)
			prints(sender, "folds.")
		"DISCONNECT":
			prints(sender, "disconnected.")
	
	input_received.emit(option == "RAISE")

func button_pressed(option):
	var value = null
	
	match option:
		"CALL":
			value = bet_to_match - Netgame.me().current_bet
		"RAISE":
			value = bet_raise_input.value
	
	bet_bar.visible = false
#	prints("bet bar for", multiplayer.get_unique_id(), "deactivated")
	send_option.rpc_id(1, option, value)

func all_bets_equal():
	var last_num = null
	var is_equal = true
	for id in Netgame.game_state.active_players:
		if id not in Netgame.game_state.folded_players:
			if last_num == null:
				last_num = Netgame.players[id].current_bet
			else:
				is_equal = is_equal and last_num == Netgame.players[id].current_bet
		if not is_equal: break
	return is_equal

func get_max_bet():
	var max_bet = -50
	for id in Netgame.game_state.active_players:
		max_bet = maxi(max_bet, Netgame.players[id].current_bet)
	return max_bet

func player_disconnected(disconnected_id):
	if awaiting_player == disconnected_id:
		send_option.rpc_id(1, "DISCONNECT", null)

func redistribute_wealth(from):
	var free_money = Netgame.players[from].chips
	var redistributed = free_money / Netgame.game_state["active_players"].size()
	
	for id in Netgame.game_state.active_players:
		Netgame.players[id].chips += redistributed
		free_money -= redistributed
	Netgame.game_state.pot += free_money
