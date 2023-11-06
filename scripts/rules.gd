extends Node

var RULES
var FREE_WILD = 0x2_0000
var WILD = 0x1_0000

func _ready():
	reset()

func get_value(card): 
	if card is int:
		if card == FREE_WILD:
			return FREE_WILD
		elif card & WILD:
			if card & FREE_WILD:
				return card ^ (WILD | FREE_WILD)
			else:
				return card ^ WILD
		else:
			return card % RULES["VALS_PER_SUIT"]
	else:
		return -1
func get_suit(card): return card / RULES["VALS_PER_SUIT"] if card is int else -1
func get_deck_size(): return RULES["SUITS"] * RULES["VALS_PER_SUIT"]

func get_proper_value(card):
	var values = "JQKA"
	var card_value = get_value(card) if card != null else -1
	var end_diff = card_value - RULES["VALS_PER_SUIT"]
	
	if card == FREE_WILD:
		return "??"
	elif end_diff > -5:
		return values[end_diff]
	else:
		return str(card_value + 2)

func get_proper_symbol(card: int):
	if card == null:
		return null
	elif card == FREE_WILD:
		return "??\U01F0CF"
	
	# Spades, Hearts, Clubs, Diamonds
	const suits = "\u2660\u2665\u2663\u2666\u2605\U01F319"
	var card_suit = suits[get_suit(card)] if card < WILD else "\U01F0CF"
	
	return get_proper_value(card) + card_suit

func reset():
	RULES = load_json_at("res://rules/base_rules.json")
	integerize(RULES)

func set_rule(rule: String, value: Variant):
	if RULES.has(rule) and typeof(RULES[rule]) == typeof(value):
		RULES[rule] = value
	
	# Special considerations for other rules
	# e.g. setting/resetting certain hand ranks for certain hand sizes
	match rule:
		"RESET":
			reset()
		"CARDS_PER_HAND":
			var card_rules
			var path = "res://rules/%s.json"
			
			match value:
				4:
					card_rules = load_json_at(path % "four_cards")
					RULES["HAND_RANKS"].merge(card_rules, true)
				5:
					card_rules = load_json_at(path % "base_rules")
					RULES["HAND_RANKS"] = card_rules["HAND_RANKS"]
				6:
					card_rules = load_json_at(path % "six_cards")
					RULES["HAND_RANKS"].merge(card_rules, true)
				_: 
					push_error("wait you can't have that many")
			integerize(RULES)

func add_change(change: String):
	var counter_change
	if change.ends_with("UP"):
		counter_change = change.left(-2) + "DOWN"
	elif change.ends_with("DOWN"):
		counter_change = change.left(-4) + "UP"
	if RULES.CURRENT_CHANGES.has(counter_change):
		RULES.CURRENT_CHANGES.erase(counter_change)
	else:
		RULES.CURRENT_CHANGES.append(change)

func load_json_at(path: String):
	var it = JSON.parse_string(FileAccess.get_file_as_string(path))
	if it: return it

func integerize(dict: Dictionary):
	for key in dict:
		match typeof(dict[key]):
			TYPE_FLOAT:
				dict[key] = int(dict[key])
			TYPE_DICTIONARY:
				integerize(dict[key])
			_: pass

func get_changes():
	var change_array = []
	
	for change in RULES.CURRENT_CHANGES:
		var template = "%screase %s by %d."
		var mod = "In" if "UP" in change else "De"
		var type = change.get_slice("_", 0)
		var rule = ""
		var value = RULES.CURRENT_CHANGES.count(change)
		var dependent = false
		
		match type:
			"SUITS":
				rule = "suits in the deck"
			"CARDS": 
				rule = "cards in each suit"
				value *= 3
			"COMM":
				rule = "community cards"
			"HOLE":
				rule = "hole cards"
			"HAND":
				rule = "cards in a hand"
			"WINNERS":
				template = "%d additional players can win."
				dependent = true
			"WILD":
				template = "There are %d wild cards in the deck."
				value *= Rules.RULES.SUITS
				dependent = true
			_:
				push_error("you fucked it")
		if dependent:
			change_array.append(template % value)
		else:
			change_array.append(template % [mod, rule, value])
	
	return change_array
