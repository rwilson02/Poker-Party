class_name RuleChanger
extends Node

signal option_selected(valid)

# Delimiters of change types
# All powers of two -1 because increases are odds
const ONE_TIME_CHANGES = 2 ** 2 - 1 # 3
const TWO_TIME_CHANGES = 2 ** 5 - 1 # 31, toggles also go here
const DEPENDENT_CHANGES = 2 ** 8 - 1 # 255
const DEPENDENT_MAX_LIMIT = 3

# Other constants
const CHANGE_INFO_PATH = "res://rules/change_info.txt"
const CHANGE_ICON_TEMPLATE = "res://textures/rule_changes/%s.png"
const TEXT_TEMPLATE = "[center][font_size=20]%s[/font_size]"

# Types of rule changes
enum CHANGES {
	# One-shot changes
	FULL_RESET = 0,
	# Applies once
	HAND_UP = ONE_TIME_CHANGES,
	HAND_DOWN,
	HOLE_UP,
	HOLE_DOWN,
	# Applies twice
	SUITS_UP = TWO_TIME_CHANGES, # Increases are odd
	SUITS_DOWN, # Decreases are even
	CARDS_UP,
	CARDS_DOWN,
	COMM_UP,
	COMM_DOWN,
	BALL_FLIP,
	# Dependent changes, in which you can only have increases first
	WINNERS_UP = DEPENDENT_CHANGES,
	WINNERS_DOWN,
	WILD_UP,
	WILD_DOWN,
	BLINDING_UP,
	BLINDING_DOWN,
	SPEED_UP,
	SPEED_DOWN,
}

const CHANGE_WEIGHTS = {
	# Higher weight = higher chance to appear
	# One-shot changes
	FULL_RESET = 75,
	# Applies once
	HAND_UP = 40,
	HAND_DOWN = 40,
	HOLE_UP = 60,
	HOLE_DOWN = 60,
	# Applies twice
	SUITS_UP = 100,
	SUITS_DOWN = 100,
	CARDS_UP = 100,
	CARDS_DOWN = 100,
	COMM_UP = 75,
	COMM_DOWN = 75,
	BALL_FLIP = 20,
	# Dependent changes
	# Deliberately imbalanced
	WINNERS_UP = 30,
	WINNERS_DOWN = 45,
	WILD_UP = 65,
	WILD_DOWN = 55,
	BLINDING_UP = 30,
	BLINDING_DOWN = 40,
	SPEED_UP = 35,
	SPEED_DOWN = 45,
}
@onready var option_container = $HBoxContainer

var possible_changes = []
var buttons = []

func compute_possible_changes():
	var h = Rules.RULES.HOLE_CARDS
	var c = Rules.RULES.COMM_CARDS
	var p = Netgame.game_state.active_players.size()
	var s = Rules.RULES.SUITS
	var v = Rules.RULES.VALS_PER_SUIT + Rules.RULES.WILDS # 1 wild per suit, per addition of wilds
	var cpr = h * p + c # cards per round
	
	possible_changes.clear()
	for change in CHANGES: 
		possible_changes.append(change)
	
	# Eliminate decreases which would run the deck out
	if cpr > (s - 1) * v: possible_changes.erase("SUITS_DOWN")
	if cpr > s * (v - 3): possible_changes.erase("CARDS_DOWN")
	# Eliminate changes which would make hands unable to be completed
	if (h - 1) + c < Rules.RULES.CARDS_PER_HAND: possible_changes.erase("HOLE_DOWN")
	if h + (c - 1) < Rules.RULES.CARDS_PER_HAND: possible_changes.erase("COMM_DOWN")
	if h + c < (Rules.RULES.CARDS_PER_HAND + 1): possible_changes.erase("HAND_UP")
	
	# Don't offer a full reset if the game isn't spicy enough
	if Rules.RULES.CURRENT_CHANGES.size() < 5: 
		possible_changes.erase("FULL_RESET")
	
	# Don't offer trickle down if there aren't enough players to benefit
	if Netgame.players.keys().size() - 2 <= Rules.RULES.CURRENT_CHANGES.count("WINNERS_UP"):
		possible_changes.erase("WINNERS_UP")
	
	for change in CHANGES:
#		# Eliminate one-time options
		if CHANGES[change] < TWO_TIME_CHANGES:
			if change in Rules.RULES.CURRENT_CHANGES:
				possible_changes.erase(change)
		# Eliminate changes which already happened twice
		elif CHANGES[change] < DEPENDENT_CHANGES:
			if Rules.RULES.CURRENT_CHANGES.count(change) == 2: 
				possible_changes.erase(change)
		# Handle dependent changes
		else:
			if CHANGES[change] & 1 == 0:
				if not (change.replace("DOWN", "UP") in Rules.RULES.CURRENT_CHANGES):
					possible_changes.erase(change)
			else:
				if Rules.RULES.CURRENT_CHANGES.count(change) == DEPENDENT_MAX_LIMIT: 
					possible_changes.erase(change)
	
	var min_weight = randi_range(0, 100)
	possible_changes = possible_changes.filter(func(ch): return CHANGE_WEIGHTS[ch] >= min_weight)

func get_options():
	compute_possible_changes()
	possible_changes.shuffle()
	return [possible_changes[0], possible_changes[1]]

func setup_menu():
	# Set variables for both options
	var both_options = get_options()
	for i in both_options.size():
		var raw_info = RuleChanger.get_option_information(both_options[i])
		var info = RuleChanger.get_info_dict(raw_info)
		var has_counter = int(both_options[i].ends_with("UP")) - int(both_options[i].ends_with("DOWN"))
		
		var option_box: Node = option_container.get_child(i)
		option_box.get_node("Title").text = TEXT_TEMPLATE % info.TITLE
		option_box.get_node("Image").texture = load(CHANGE_ICON_TEMPLATE % info.ICON)
		
		option_box.get_node("Description").text = TEXT_TEMPLATE % (info.DESC % info.VALUE) \
			if info.FORMATTED else TEXT_TEMPLATE % info.DESC
		if has_counter != 0:
			var repeal_template = "\n[font_size=12](Reverses [b]%s[/b])[/font_size]"
			var counter_change = both_options[i].left(-2) + "DOWN"\
				if has_counter > 0 else both_options[i].left(-4) + "UP"
			
			if counter_change in Rules.RULES.CURRENT_CHANGES:
				option_box.get_node("Description").text += repeal_template % \
					RuleChanger.get_option_information(counter_change)[3]
		
		var option_button = option_box.get_node("Select")
		option_button.disabled = false
		if option_button.pressed.is_connected(on_button_pressed):
			option_button.pressed.disconnect(on_button_pressed)
		if not info.VALUE is int: info.VALUE = 0
		option_button.pressed.connect(on_button_pressed.bind(info.RULE, info.VALUE, both_options[i]))
		buttons.append(option_button)

static func get_option_information(option):
	var change_file = FileAccess.open(CHANGE_INFO_PATH, FileAccess.READ)
	while not change_file.eof_reached():
		var line = change_file.get_csv_line()
		if line[0] == option:
			return line
	return []

static func get_info_dict(raw_info):
	var info
		
	if raw_info.is_empty():
		push_error("wait there's no information on this one (%s) chief" % raw_info[0])
		return
	else:
		info = {
			"TITLE": raw_info[3],
			"ICON": raw_info[1] if (not raw_info[1].is_empty() and Rules.RULES[raw_info[5]] < 0) else raw_info[0],
			"DESC": raw_info[4],
			"FORMATTED": raw_info[2] as int as bool,
			"RULE": raw_info[5],
		}
		if raw_info[6].is_valid_int():
			info.VALUE = Rules.RULES[raw_info[5]] + (raw_info[6] as int) \
				if Rules.RULES.has(raw_info[5]) else (raw_info[6] as int)
		elif raw_info[6] is String: # Presume this is a toggle
			info.VALUE = Array(raw_info[6].split("|"))
			if Rules.RULES[raw_info[5]] < 0:
				info.VALUE.reverse()
		else: info.VALUE = 0
	
	return info

func on_button_pressed(rule, value, change):
	for button in buttons: button.disabled = true
	on_receive_button_press.rpc_id(1, rule, value, change)
	option_selected.emit(change != "DISCONNECT")

@rpc("any_peer", "call_local", "reliable")
func on_receive_button_press(rule, value, change):
	if change != "DISCONNECT":
		# really hacky, but good enough
		var change_title = RuleChanger.get_option_information(change)
		if not change_title.is_empty():
			change_title = change_title[3]
			$"../../Display".log_to_chat("player(%d) chose %s." % [multiplayer.get_remote_sender_id(), change_title])
		
		Rules.add_change(change)
		Rules.set_rule(rule, value)
	
