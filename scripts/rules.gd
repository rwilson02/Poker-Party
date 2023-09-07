extends Node

var SUITS = 4
var VALS_PER_SUIT = 13
var HOLE_CARDS = 2
var COMM_CARDS = 5

var HAND_RANKS = {
	"5K": 900, # 5-of-a-kind
	"SF": 800, # Straight flush
	"4K": 700, # 4-of-a-kind
	"FH": 600, # Full house
	"FL": 500, # Flush
	"ST": 400, # Straight
	"3K": 300, # 3-of-a-kind
	"2P": 200, # 2 pairs
	"1P": 100, # 1 pair
	"HC": 0 # High card
}

func get_value(card: int): return card % VALS_PER_SUIT
func get_suit(card: int): return (int)(card / VALS_PER_SUIT)
