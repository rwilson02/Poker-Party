extends Node

var RULES

func _ready():
	reset()

func get_value(card: int): return card % RULES["VALS_PER_SUIT"]
func get_suit(card: int): return card / RULES["VALS_PER_SUIT"]
func get_deck_size(): return RULES["SUITS"] * RULES["VALS_PER_SUIT"]

func get_proper_value(card):
	var values = "JQKA"
	var card_value = get_value(card) if card != null else -1
	var end_diff = card_value - RULES["VALS_PER_SUIT"]
	
	if end_diff > -5:
		return values[end_diff]
	else:
		return str(card_value + 2)

func get_proper_symbol(card: int):
	if card == null:
		return null
	
	var suits = "\u2660\u2665\u2663\u2666\u2605\U01F6E1"
	var card_suit = suits[get_suit(card)]
	
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
