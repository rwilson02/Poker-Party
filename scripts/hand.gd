class_name Hand

var cards = []
var rank = ""
var kickerA = null
var kickerB = null
var kickerC = null

func _init(given_cards: Array):
	if not given_cards.is_empty():
		self.cards = given_cards
		classify()

func classify():
	self.cards.sort_custom(func(a,b): return Rules.get_value(a) > Rules.get_value(b))
	
	var is_straight = true
	var is_flush = false
	
	var clean_values = cards.map(Rules.get_value)
	var clean_suits = cards.map(Rules.get_suit)
	var runs = []

	is_straight = sequential(clean_values)
	is_flush = all_equal(clean_suits)
	
	for value in Rules.VALS_PER_SUIT:
		var val_count = clean_values.count(value)
		if val_count > 1:
			runs.append([val_count, value])
	
	runs.sort_custom(func(a,b): return a[0] > b[0])
	
	match [is_straight, is_flush]:
		[true, true]:
			self.rank = "SF"
			self.kickerA = self.cards.front()
		[true, false]:
			self.rank = "ST"
			self.kickerA = self.cards.front()
		[false, true]:
			self.rank = "FL"
		[false, false]:
			match runs.size():
				0: self.rank = "HC"
				1:
					self.kickerA = runs[0][1]
					match runs[0][0]:
						2: self.rank = "1P"
						3: self.rank = "3K"
						4: self.rank = "4K"
						5: self.rank = "5K"
				2:
					self.kickerA = runs[0][1]
					self.kickerB = runs[1][1]
					var groups = [runs[0][0], runs[1][0]]
					match groups:
						[2, 2]:
							self.rank = "2P"
						[3, 3]:
							self.rank = "2T"
						_:
							self.rank = "CR" if groups[0] + groups[1] < cards.size() \
							else "FH"
				3:
					self.rank = "3P"
					self.kickerA = runs[0][1]
					self.kickerB = runs[1][1]
					self.kickerC = runs[2][1]
				_:
					push_error("wadda hell")

func get_name():
	var hand_name = ""
	var properA = Rules.get_proper_value(kickerA)
	var properB = Rules.get_proper_value(kickerB)
	
	match rank:
		"5K":
			hand_name = "5-of-a-kind (%ss)"
			return hand_name % properA
		"SF":
			hand_name = "Straight flush (%s-high)"
			return hand_name % properA
		"4K":
			hand_name = "4-of-a-kind (%ss)"
			return hand_name % properA
		"FH":
			hand_name = "Full house (%ss over %ss)"
			return hand_name % [properA, properB]
		"FL":
			hand_name = "Flush"
			return hand_name
		"ST":
			hand_name = "Straight (%s-high)"
			return hand_name % properA
		"3K":
			hand_name = "3-of-a-kind (%ss)"
			return hand_name % properA
		"2P":
			hand_name = "2 pair (%ss over %ss)"
			return hand_name % [properB, properA]
		"1P":
			hand_name = "1 pair (%ss)"
			return hand_name % properA
		"HC":
			hand_name = "High card"
			return hand_name
		"":
			hand_name = "Invalid hand"

static func sort(a: Hand, b:Hand) -> bool:
	if a.rank != b.rank:
		return Rules.HAND_RANKS[a.rank] > Rules.HAND_RANKS[b.rank]
	elif a.kickerA != b.kickerA:
		return a.kickerA > b.kickerA
	elif a.kickerB != b.kickerB:
		return a.kickerB > b.kickerB
	elif a.kickerC != b.kickerC:
		return a.kickerC > b.kickerC
	else:
		return a.cards.map(Rules.get_value) > b.cards.map(Rules.get_value)

static func get_best_hand(given_cards: Array, hand_size: int):
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
	var best_hand: Hand = Hand.new([])
	var possible_hands = get_combinations(given_cards, hand_size)
	
	for hand in possible_hands:
		var new_hand = Hand.new(hand)
		best_hand = new_hand if Hand.sort(new_hand, best_hand) else best_hand
	
	return best_hand

func sequential(array):
	var is_sequential = true
	for i in array.size() - 1:
		is_sequential = is_sequential and (array[i] - 1 == array[i+1])
		if not is_sequential: break
	
	var ace_low_test = range(array.size() - 1)
	ace_low_test.reverse()
	ace_low_test.append(Rules.VALS_PER_SUIT - 1)
	
	return is_sequential or (array == ace_low_test)

func all_equal(array):
	var equal = true
	for i in array.size() - 1:
		equal = equal and (array[i] == array[i+1])
		if not equal: break
	return equal

static func get_combinations(n: Array, k: int):
	var returned = []
	var sub: Array
	var next: Array
	
	for i in n.size():
		if k == 1:
			returned.append([n[i]])
		else:
			sub = get_combinations(n.slice(i+1, n.size()), k-1)
			for ii in sub.size():
				next = sub[ii]
				next.push_front(n[i])
				returned.append(next)
	return returned
