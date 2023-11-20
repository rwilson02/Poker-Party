extends Node

const TEMPLATE = "[center][font_size=24]%s[/font_size]\n%s"
const CARD = preload("res://scenes/ui/ui_card.tscn")
const NUM_TO_WORD = {
#	1: "One",
#	2: "Two",
	3: "Three",
	4: "Four",
	5: "Five",
	6: "Six",
}
var DESCS = JSON.parse_string(FileAccess.get_file_as_string("res://rules/hand_descriptions.json"))

@export var auto = false
@export_range(4,6) var hand_size = 5
@export var hand_type = ""

@export var scale = 0.35

@onready var label = $RichTextLabel
@onready var hand = $Hand

var ranks: Array
var suits: Array
var extra_suits: Array
var combo_suits: Array

func _ready():
	ranks = range(Rules.RULES.VALS_PER_SUIT)
	suits = range(Rules.RULES.SUITS).map(func(c): return c * Rules.RULES.VALS_PER_SUIT)
	ranks.shuffle()
	suits.shuffle()
	while suits.size() + extra_suits.size() < 6:
		extra_suits.append((suits.size() + extra_suits.size()) * Rules.RULES.VALS_PER_SUIT)
	combo_suits = suits.duplicate()
	combo_suits.append_array(extra_suits.duplicate())
	
	if auto: 
		setup()

func setup():
	if hand_type in ["3P", "2T", "6K", "CR"]: hand_size = 6 if hand_size <= 5 else hand_size
	if hand_type in ["5K", "FH"]: hand_size = 5 if hand_size <= 4 else hand_size
	
	var h = Hand.new([])
	h.rank = hand_type
	var full_name = h.get_name().get_slice(" (", 0)
	
	label.text = TEMPLATE % [full_name, DESCS[hand_type]]
	
	self.size = Vector2(84 * hand_size, 180)
	
	while hand.get_child_count() != hand_size:
		if hand.get_child_count() > hand_size:
			hand.get_children()[-1].free()
		elif hand.get_child_count() < hand_size:
			hand.add_child(hand.get_child(0).duplicate())
	
	var cards = get_needed_cards(hand_type)
	cards.sort_custom(func(a,b): return Rules.get_value(a) > Rules.get_value(b))
	if Rules.get_value(cards[0]) == Rules.RULES.VALS_PER_SUIT - 1 \
		and Rules.get_value(cards[1]) == hand_size - 2:
			cards.append(cards.pop_front())
	
	for marker in hand.get_children():
		var carp = CARD.instantiate()
		carp.setup(cards.pop_front())
		carp.scale = Vector2.ONE * scale
		marker.add_child(carp)

func get_needed_cards(type):
	var cards = []
	
	# Of-a-kinds
	if type.ends_with("K"):
		var of_a = int(type[0])
		var kind = ranks.pop_back()
		for i in of_a:
			cards.append(kind + combo_suits[i])
	# Pairs
	elif type.ends_with("P"):
		var pairs = int(type[0])
		for i in pairs:
			var p_rank = ranks.pop_back()
			var two_suits = [suits.pick_random(), suits.pick_random()]
			while two_suits[0] == two_suits[1]: two_suits[1] = suits.pick_random()
			
			for j in 2:
				cards.append(p_rank + two_suits[j])
	# Straights/Wheels
	elif type.begins_with("S") or type.contains("W"):
		var also_flush = type.contains("F") or type == "SW"
		var ace_low = range(hand_size - 1)
		ace_low.reverse()
		ace_low.append(Rules.RULES.VALS_PER_SUIT - 1)
		
		label.text = label.text % NUM_TO_WORD[hand_size]
		
		var possible_ranks = range(hand_size, Rules.RULES.VALS_PER_SUIT)
		possible_ranks.append(-1)
		possible_ranks.shuffle()
		var starter = possible_ranks.pop_back()
		var card_ranks = []
		var flush_suit = -1
		
		if starter < 0 or type.contains("W"):
			card_ranks = ace_low
		else: 
			card_ranks = range(starter, starter - hand_size, -1)
		if also_flush:
			flush_suit = suits.pop_back()
		
		for r in card_ranks:
			if flush_suit < 0:
				cards.append(r + suits.pick_random())
			else:
				cards.append(r + flush_suit)
	# Like, the rest
	else:
		match type:
			"FH", "CR":
				if hand_size < 5:
					push_error("you can't full house with %d cards idiot" % hand_size)
					return
				
				var higher_size = hand_size - 2
				if type == "CR": higher_size = 3
				if label.text.contains("%s"):
					label.text = label.text % NUM_TO_WORD[higher_size]
				
				var two_ranks = [ranks.pop_back(), ranks.pop_back()]
				var two_suits = [suits.pick_random(), suits.pick_random()]
				while two_suits[0] == two_suits[1]: two_suits[1] = suits.pick_random()
				var higher_suits = suits.slice(0, higher_size)
				
				for i in higher_size:
					cards.append(two_ranks[0] + higher_suits[i])
				for i in 2:
					cards.append(two_ranks[1] + two_suits[i])
			"HC":
				for i in hand_size:
					cards.append(ranks.pop_back() + suits.pick_random())
			"FL":
				label.text = label.text % NUM_TO_WORD[hand_size]
				var flush_rank = suits.pop_back()
				for i in hand_size:
					cards.append(ranks.pop_back() + flush_rank)
			"2T":
				for i in 2:
					var p_rank = ranks.pop_back()
					var three_suits = suits.slice(0,3)
					suits.shuffle()
					
					for j in 3:
						cards.append(p_rank + three_suits[j])
	
	while cards.size() < hand_size:
		cards.append(ranks.pop_back() + suits.pick_random())
	
	return cards
