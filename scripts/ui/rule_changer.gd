extends Node

signal option_selected(valid)

# Delimiters of change types
# All powers of two -1 because increases are odds
const TWO_TIME_CHANGES = 3
const ONE_TIME_CHANGES = 31 

# Other constants
const CHANGE_INFO_PATH = "res://rules/change_info.txt"
const CHANGE_ICON_TEMPLATE = "res://textures/rule_changes/%s.png"
const TEXT_TEMPLATE = "[font_size=20][center]%s[/center][/font_size]"

# Types of rule changes
enum CHANGES {
	# One-shot changes
	FULL_RESET = 0,
	# Applies twice
	SUITS_UP = TWO_TIME_CHANGES, # Increases are odd
	SUITS_DOWN, # Decreases are even
	CARDS_UP,
	CARDS_DOWN,
	COMM_UP,
	COMM_DOWN,
	# Applies once
	HAND_UP = ONE_TIME_CHANGES,
	HAND_DOWN,
	HOLE_UP,
	HOLE_DOWN
	
}

@onready var option_container = $HBoxContainer

var possible_changes = []
var buttons = []

func compute_possible_changes():
	var h = Rules.RULES["HOLE_CARDS"]
	var c = Rules.RULES["COMM_CARDS"]
	var p = Netgame.game_state["active_players"].size()
	var s = Rules.RULES["SUITS"]
	var v = Rules.RULES["VALS_PER_SUIT"]
	var cpr = h * p + c # cards per round
	
	possible_changes.clear()
	for change in CHANGES: 
		possible_changes.append(change)
	
	# Eliminate decreases which would run the deck out
	if cpr > (s - 1) * v: possible_changes.erase(CHANGES.SUITS_DOWN)
	if cpr > s * (v - 1): possible_changes.erase(CHANGES.CARDS_DOWN)
	# Eliminate changes which would make hands unable to be completed
	if (h - 1) + c < Rules.RULES["CARDS_PER_HAND"]: possible_changes.erase(CHANGES.HOLE_DOWN)
	if h + (c - 1) < Rules.RULES["CARDS_PER_HAND"]: possible_changes.erase(CHANGES.COMM_DOWN)
	if h + c < (Rules.RULES["CARDS_PER_HAND"] + 1): possible_changes.erase(CHANGES.HAND_UP)
	
	# Don't offer a full reset if the game isn't spicy enough
	if Rules.RULES.CURRENT_CHANGES.size() < 5: 
		possible_changes.erase("FULL_RESET")
	
	for change in CHANGES:
		# Eliminate changes which already happened twice
		if CHANGES[change] >= TWO_TIME_CHANGES:
			if Rules.RULES.CURRENT_CHANGES.count(change) == 2: 
				possible_changes.erase(change)
			
			# Eliminate one-time options
			if CHANGES[change] >= ONE_TIME_CHANGES:
				if change in Rules.RULES.CURRENT_CHANGES: 
					possible_changes.erase(change)

func get_options():
	compute_possible_changes()
	possible_changes.shuffle()
	return [possible_changes[0], possible_changes[1]]

func setup_menu():
	# Set variables for both options
	var both_options = get_options()
	for i in both_options.size():
		var raw_info = get_option_information(both_options[i])
		var info
		
		if raw_info == null:
			push_error("wait there's no information on this one (%s) chief" % both_options[i])
			return
		else:
			info = {
				"TITLE": raw_info[3],
				"ICON": raw_info[1] if not raw_info[1].is_empty() else raw_info[0],
				"DESC": raw_info[4],
				"FORMATTED": raw_info[2] as int as bool,
				"RULE": raw_info[5],
				"VALUE": Rules.RULES[raw_info[5]] + (raw_info[6] as int) \
					if Rules.RULES.has(raw_info[5]) else (raw_info[6] as int)
			}
		
		var option_box: Node = option_container.get_child(i)
		option_box.get_node("Title").text = TEXT_TEMPLATE % info.TITLE
		option_box.get_node("Image").texture = load(CHANGE_ICON_TEMPLATE % info.ICON)
		option_box.get_node("Description").text = TEXT_TEMPLATE % (info.DESC % info.VALUE) \
			if info.FORMATTED else TEXT_TEMPLATE % info.DESC
		var option_button = option_box.get_node("Select")
		option_button.disabled = false
		if option_button.pressed.is_connected(on_button_pressed):
			option_button.pressed.disconnect(on_button_pressed)
		option_button.pressed.connect(on_button_pressed.bind(info.RULE, info.VALUE, both_options[i]))
		buttons.append(option_button)

func get_option_information(option):
	var change_file = FileAccess.open(CHANGE_INFO_PATH, FileAccess.READ)
	while not change_file.eof_reached():
		var line = change_file.get_csv_line()
		if line[0] == option:
			return line
	return null

func on_button_pressed(rule, value, change):
	for button in buttons: button.disabled = true
	on_receive_button_press.rpc_id(1, rule, value, change)
	option_selected.emit(change != "DISCONNECT")

@rpc("any_peer", "call_local", "reliable")
func on_receive_button_press(rule, value, change):
	if change != "DISCONNECT":
		Rules.add_change(change)
		Rules.set_rule(rule, value)
	
