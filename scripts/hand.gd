class_name Hand

var cards
var rank
var kickerA
var kickerB

func classify(cards: Array):
	pass

func sort(a: Hand, b:Hand) -> bool:
	if a.rank != b.rank:
		return Rules.HAND_RANKS[a.rank] > Rules.HAND_RANKS[b.rank]
	elif a.kickerA != b.kickerA:
		return a.kickerA > b.kickerA
	elif a.kickerB != b.kickerB:
		return a.kickerB > b.kickerB
	else:
		return a.cards > b.cards

func get_best_hand(cards: Array, hand_size: int):
	pass
