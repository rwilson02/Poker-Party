class_name Hand

var cards = []
var rank = ""
var kickerA = null
var kickerB = null
var kickerC = null

func _init(given_cards: Array):
	cards = given_cards
	classify()

func classify():
	var is_straight = true
	var is_flush = all_equal(cards.map(func(c): return Rules.get_suit(c)))
	var clean = cards.map(func(c): return Rules.get_value(c))
	var runs = []
	var test: Array
	
	for i in cards.size() - 1:
		is_straight = is_straight and (clean[i] - 1 == clean[i+1])
		# TODO: Aces can be high or low for straights
	
	for value in Rules.VALS_PER_SUIT:
		var val_count = clean.count(value)
		if val_count > 1:
			runs.append([val_count, value])
	
	runs.sort_custom(func(a,b): a[0] > b[0])
	
	match [is_straight, is_flush]:
		[true, true]:
			rank = "SF"
			kickerA = cards.front()
		[true, false]:
			rank = "ST"
			kickerA = cards.front()
		[false, true]:
			rank = "FL"
		[false, false]:
			match runs.size():
				0: rank = "HC"
				1:
					kickerA = runs[0][1]
					match runs[0][0]:
						2: rank = "1P"
						3: rank = "3K"
						4: rank = "4K"
						5: rank = "5K"
				2:
					kickerA = runs[0][1]
					kickerB = runs[1][1]
					var groups = [runs[0][0], runs[1][0]]
					match groups:
						[2, 2]:
							rank = "2P"
						[3, 3]:
							rank = "2T"
						_:
							rank = "CR" if groups[0] + groups[1] < cards.size() \
							else "FH"
				3:
					rank = "3P"
					kickerA = runs[0][1]
					kickerB = runs[1][1]
					kickerC = runs[2][1]
				_:
					push_error("wadda hell")

func sort(a: Hand, b:Hand) -> bool:
	if a.rank != b.rank:
		return Rules.HAND_RANKS[a.rank] > Rules.HAND_RANKS[b.rank]
	elif a.kickerA != b.kickerA:
		return a.kickerA > b.kickerA
	elif a.kickerB != b.kickerB:
		return a.kickerB > b.kickerB
	elif a.kickerC != b.kickerC:
		return a.kickerC > b.kickerC
	else:
		return a.cards > b.cards

func get_best_hand(cards: Array, hand_size: int):
#	var spans = cards.size() - hand_size
#
#	var best_straight = null
#	var best_flush = null
#	var best_combo = null
#
#	cards.sort()
#
#	# Determine best flush
#	var flushes: Array
#	for suit in Rules.SUITS:
#		var possible_flush = cards.filter(func(val): Rules.get_suit(val) == suit)
#		if possible_flush.size() >= hand_size:
#			flushes.append(possible_flush.slice(0, hand_size))
#
#	flushes.sort()
#	best_flush = flushes.front()
#
#	# Determine best straight
#	for i in spans + 1:
#		var cut = cards.slice(i, hand_size + i)
#		if best_straight == null \
#		and cut.reduce(func(accum, num): return accum + num, 0)/hand_size == cut[2]:
#			best_straight = cut
	var best_hand: Hand = null
	
	for hand in get_combinations(cards, hand_size):
		var new_hand = Hand.new(hand)
		best_hand = new_hand if new_hand > best_hand else best_hand
	
	return best_hand

func all_equal(array):
	return array.all(func(v): v == array.front())

func get_combinations(n: Array, k: int):
	var returned = []
	var sub: Array
	var next: Array
	
	for i in n.size():
		if k == 0:
			returned.append([n[i]])
		else:
			sub = get_combinations(n.slice(i+1, n.size()), k-1)
			for ii in sub.size():
				next = sub[i]
				next.push_front(n[i])
				returned.append(next)
