extends Node

var SUITS = 4
var VALS_PER_SUIT = 13
var HOLE_CARDS = 2
var COMM_CARDS = 5
var CARDS_PER_HAND = 5

var HAND_RANKS = {
	# Base hands
	"5K": 900, # 5-of-a-kind
	"SF": 800, # Straight flush
	"4K": 700, # 4-of-a-kind
	"FH": 600, # Full house
	"FL": 500, # Flush
	"ST": 400, # Straight
	"3K": 300, # 3-of-a-kind
	"2P": 200, # 2 pair
	"1P": 100, # 1 pair
	"HC": 000, # High card
	"": -9999, # Junk value
	# 6-card exclusives (values estimated)
	"CR": 550, # Crowd (not-quite-full house)
	"3P": 570, # 3 pair
	"2T": 590, # 2 trips
	"6K": 999  # 6-of-a-kind
}

func get_value(card: int): return card % VALS_PER_SUIT
func get_suit(card: int): return card / VALS_PER_SUIT

func get_proper_value(card):
	var values = "JQKA"
	var card_value = get_value(card) if card != null else -1
	var end_diff = card_value - VALS_PER_SUIT
	
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

func hand_to_string(hand: Array):
	var hand_string = "["
	for card in hand:
		hand_string += Rules.get_proper_symbol(card)
		hand_string += " "
	hand_string[-1] = "]"
	return hand_string

func reset():
	SUITS = 4
	VALS_PER_SUIT = 13
	HOLE_CARDS = 2
	COMM_CARDS = 5
	CARDS_PER_HAND = 5
	
	HAND_RANKS = {
		"5K": 900,
		"SF": 800,
		"4K": 700,
		"FH": 600,
		"FL": 500,
		"ST": 400,
		"3K": 300,
		"2P": 200,
		"1P": 100,
		"HC": 000,
		"": -9999,
		"CR": 550,
		"3P": 570,
		"2T": 590,
		"6K": 999 
	}
