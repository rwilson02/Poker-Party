extends Node

@export var RULES: Dictionary
var FREE_WILD = 0x2_0000
var WILD = 0x1_0000
# Spades, Hearts, Clubs, Diamonds, Stars, Moons
var SUIT_COLORS = [Color.SLATE_BLUE.darkened(0.2), Color.RED, Color.SLATE_BLUE.darkened(0.2), Color.RED, \
	Color.GOLDENROD, Color.GOLDENROD]

var regex

func _ready():
	regex = RegEx.new()
	regex.compile("[() ]")
	
	reset(true)

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
			return card % RULES.VALS_PER_SUIT
	else:
		return -1
func get_suit(card): return card / RULES.VALS_PER_SUIT if card is int else -1
func get_suit_loc(suit):
	const SUITS_PER_ROW = 4
	const ROWS = 2
	const SUIT_SIZE = 256
	
	var pos: Vector2
	if suit > SUITS_PER_ROW * ROWS: pos = Vector2(SUITS_PER_ROW - 1, ROWS - 1)
	else: pos = Vector2(suit % SUITS_PER_ROW, suit / SUITS_PER_ROW)
	
	return Rect2(pos * SUIT_SIZE, Vector2.ONE * SUIT_SIZE)

func get_deck_size(): return RULES.SUITS * RULES.VALS_PER_SUIT

func get_proper_value(card):
	var values = "JQKA"
	var card_value = get_value(card) if card != null else -1
	var end_diff = card_value - RULES.VALS_PER_SUIT
	
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
	
	# Spades, Hearts, Clubs, Diamonds, Stars, Moons
	const suits = "\u2660\u2665\u2663\u2666\u2605\U01F319"
	var card_suit = suits[get_suit(card)] if card < WILD else "\U01F0CF"
	
	return get_proper_value(card) + card_suit

func get_card_string(card):
	const TEMPLATE = "%s[img=16 region=%s color=%s]%s[/img]"
	const SUITS_PATH = "res://textures/cards/suit_atlas.png"
	
	var value = get_proper_value(card)
	var suit = get_suit(card)
	var icon_loc = get_suit_loc(suit)
	var loc_str = regex.sub("%s,%s" % [str(icon_loc.position), str(icon_loc.size)], "", true)
	
	if suit > RULES.SUITS:
		return value + "\U01F0CF"
	else:
		var color = SUIT_COLORS[suit]
		return TEMPLATE % [value, loc_str, color.to_html(false), SUITS_PATH]

func reset(full: bool = false):
	var holdover
	
	if RULES:
		holdover = [RULES.INITIAL_CHIPS, RULES.ANTE, RULES.GAMEPLAY_ROUNDS]
	
	RULES = load_json_at("res://rules/base_rules.json")
	integerize(RULES)
	
	if not full:
		RULES.INITIAL_CHIPS = holdover[0]
		RULES.ANTE = holdover[1]
		RULES.GAMEPLAY_ROUNDS = holdover[2]

func set_rule(rule: String, value: Variant):
	if rule == "BALL" and value == 0:
		RULES.BALL *= -1
		return
	
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
					RULES.HAND_RANKS.merge(card_rules, true)
				5:
					card_rules = load_json_at(path % "base_rules")
					RULES.HAND_RANKS = card_rules.HAND_RANKS
				6:
					card_rules = load_json_at(path % "six_cards")
					RULES.HAND_RANKS.merge(card_rules, true)
				_: 
					push_error("wait you can't have that many")
			integerize(RULES)

func add_change(change: String):
	var counter_change
	if change.ends_with("UP"):
		counter_change = change.left(-2) + "DOWN"
	elif change.ends_with("DOWN"):
		counter_change = change.left(-4) + "UP"
	else:
		counter_change = change
	
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
			"BALL":
				template = "Play by %sball poker rules."
				value = "low"
				dependent = true
			_:
				push_error("you fucked it")
		if dependent:
			change_array.append(template % value)
		else:
			change_array.append(template % [mod, rule, value])
	
	return change_array
