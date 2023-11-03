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
	var value_sort = func(a,b): return Rules.get_value(a) > Rules.get_value(b)
	
	self.cards.sort_custom(value_sort)
	
	var clean_values = cards.map(Rules.get_value)
	var runs = []
	
	var wild_count = self.cards.reduce(
		func(a,n): 
			if n >= 1000: 
				return a + 1
			else:
				return a
	, 0)
	
	if wild_count == Rules.RULES.CARDS_PER_HAND:
		self.rank = "AW"
		return
	
	var is_straight = sequential(clean_values)
	var is_flush = test_flush(cards.map(Rules.get_suit))
	
	# 5K > SF, always
	if wild_count >= 4 and Rules.RULES.CARDS_PER_HAND >= 5:
		is_straight = false
		is_flush = false
	
	if is_straight:
		for i in self.cards.size():
			if clean_values[i] >= 1000:
				self.cards[i] = clean_values[i]
		self.cards.sort_custom(value_sort)
	
	for value in Rules.RULES["VALS_PER_SUIT"]:
		var val_count = clean_values.count(value)
		if val_count > 1:
			runs.append([val_count, value])
	
	# Wild adjustments
	if wild_count > 0:
		match runs.size():
			0:
				runs.append([1 + wild_count, clean_values.filter(func(c): return c < 1000).max()])
			1:
				runs[0][0] += wild_count
			2:
				match [runs[0][0], runs[1][0]]:
					[2,2], [2,3]:
						runs[1][0] += wild_count
					[3,2]:
						runs[0][0] += wild_count
	runs.sort_custom(func(a,b): return a[0] > b[0])
	
	match [is_straight, is_flush]:
		[true, var also_flush]:
			self.kickerA = self.cards.front()
			if Rules.get_value(self.kickerA) == Rules.RULES["VALS_PER_SUIT"] - 1:
				if Rules.get_value(self.cards[1]) == Rules.RULES["CARDS_PER_HAND"] - 2:
					self.kickerA = self.cards[1]
			self.rank = "SF" if also_flush else "ST"
		[false, true]:
			self.rank = "FL"
		[false, false]:
			match runs.size():
				0: self.rank = "HC"
				1:
					self.kickerA = runs[0][1]
					match runs[0][0]:
						6: self.rank = "6K"
						5: self.rank = "5K"
						4: self.rank = "4K"
						3: self.rank = "3K"
						2: self.rank = "1P"
				2:
					var groups = [runs[1][0], runs[0][0]]
					groups.sort_custom(func(a,b): return a > b)
					self.kickerA = runs[1][1] if runs[1][0] == groups[0] else runs[0][1]
					self.kickerB = runs[0][1] if self.kickerA == runs[1][1] else runs[1][1]
					match groups:
						[2, 2]:
							self.rank = "2P"
						[3, 3]:
							self.rank = "2T"
						[_, _]:
							if groups[0] + groups[1] < cards.size():
								self.rank = "CR"
							else: 
								self.rank = "FH"
				3:
					self.rank = "3P"
					self.kickerA = runs[2][1]
					self.kickerB = runs[1][1]
					self.kickerC = runs[0][1]
				_:
					push_error("wadda hell")

func get_name():
	var hand_name = ""
	var properA = Rules.get_proper_value(kickerA)
	var properB = Rules.get_proper_value(kickerB)
	
	match rank:
		"AW":
			hand_name = "ALL WILD!"
		"6K":
			hand_name = "6-of-a-kind (%ss)"
			return hand_name % properA
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
		"2T":
			hand_name = "Two trips (%ss over %ss)"
			return hand_name % [properA, properB]
		"3P":
			hand_name = "3 pair (%ss over %ss over %ss)"
			return hand_name % [properA, properB, Rules.get_proper_value(kickerC)]
		"CR":
			hand_name = "Crowd (%ss and %ss)"
			return hand_name % [properA, properB]
		"FL":
			hand_name = "Flush"
		"ST":
			hand_name = "Straight (%s-high)"
			return hand_name % properA
		"3K":
			hand_name = "3-of-a-kind (%ss)"
			return hand_name % properA
		"2P":
			hand_name = "2 pair (%ss over %ss)"
			return hand_name % [properA, properB]
		"1P":
			hand_name = "1 pair (%ss)"
			return hand_name % properA
		"HC":
			hand_name = "High card"
		"":
			hand_name = "Invalid hand"
	return hand_name

func sequential(array):
	var full_mask = (1 << Rules.RULES.CARDS_PER_HAND) - 1
	var ace_low_mask = (full_mask >> 1) | (1 << (Rules.RULES.VALS_PER_SUIT - 1))
	var bitmask = 0
	var wilds = 0
	var wild_values = []
#	var edge = false
	
	var straight_match = func(value):
		var value_test = value / full_mask
		return ((value % full_mask == 0) and (value_test & value_test - 1 == 0))\
			or value ^ ace_low_mask == 0
	
	var compute_hamming_weight = func(value):
		var weight = 0
		var _value = value
		while _value > 0:
			_value &= (_value - 1)
			weight += 1
		return weight
	
	for val in array:
		if val == 1000: wilds += 1
		else: 
			if bitmask & 1 << val == 1 << val: return false
			else: bitmask |= 1 << val
	
	if straight_match.call(bitmask):
		return true
	elif wilds == 0:
		return false
	
	# Calculate index of first one in bitmask
	var shifts = bitmask & -bitmask
	
	# Step 1: Patch holes
	var hole_patcher = bitmask
	# XOR holes with nearest PO2 - 1 to highlight the gaps
	hole_patcher ^= (nearest_po2(hole_patcher) - 1) - (shifts - 1)
	# Calculate Hamming weight to see if wilds can even save this
	var hamming_weight = compute_hamming_weight.call(hole_patcher)
	if hamming_weight > wilds: return false
	elif bitmask / shifts in [0b1, 0b11, 0b111, 0b1111, 0b11111]:
		pass # Just an edge straight, skip this step
	else:
		while wilds > 0:
			var NPO2 = nearest_po2(hole_patcher)
			var highest_index = (NPO2 >> 1) if NPO2 > hole_patcher else hole_patcher
			hole_patcher ^= highest_index
			bitmask ^= highest_index
			var new_weight = compute_hamming_weight.call(hole_patcher)
			if new_weight < hamming_weight:
				hamming_weight = new_weight
				wild_values.append(roundi(log(highest_index) / log(2)))
				wilds -= 1
			else: break
	# If straight, clock out
	if straight_match.call(bitmask):
		for i in array.size():
			if array[i] == 1000:
				array[i] += wild_values.pop_front()
		return true
	# Step 2: Build edges
	var post_shifts = 0
	for i in wilds:
		var NPO2 = nearest_po2(bitmask)
		if NPO2 == bitmask: NPO2 = (nearest_po2(bitmask + 1))
		var highest_val = NPO2
		if NPO2 > 2 ** Rules.RULES.VALS_PER_SUIT - 1: 
			highest_val = shifts >> (1 + post_shifts)
			post_shifts += 1
		bitmask |= highest_val
		wild_values.append(roundi(log(highest_val) / log(2)))
	# If straight, clock out, else not a straight
	if straight_match.call(bitmask):
		for i in array.size():
			if array[i] == 1000:
				array[i] += wild_values.pop_front()
		return true
	
	return false

func test_flush(array):
	var good_array = array.filter(func(c): return c < Rules.RULES.SUITS)
	return good_array.all(func(i): return i == good_array[0])

static func sort(a: Hand, b:Hand) -> bool:
	if a.rank != b.rank:
		return Rules.RULES["HAND_RANKS"][a.rank] > Rules.RULES["HAND_RANKS"][b.rank]
	elif Rules.get_value(a.kickerA) != Rules.get_value(b.kickerA):
		return Rules.get_value(a.kickerA) > Rules.get_value(b.kickerA)
	elif Rules.get_value(a.kickerB) != Rules.get_value(b.kickerB):
		return Rules.get_value(a.kickerB) > Rules.get_value(b.kickerB)
	elif Rules.get_value(a.kickerC) != Rules.get_value(b.kickerC):
		return Rules.get_value(a.kickerC) > Rules.get_value(b.kickerC)
	else:
		return a.cards.map(Rules.get_value) > b.cards.map(Rules.get_value)

static func is_equal(a, b) -> bool:
	if typeof(a) == typeof(Hand) and typeof(b) == typeof(Hand):
		return a.cards.map(Rules.get_value) == b.cards.map(Rules.get_value)
	elif typeof(a) == TYPE_ARRAY and typeof(b) == TYPE_ARRAY:
		return a.map(Rules.get_value) == b.map(Rules.get_value)
	else:
		push_error("Type mismatch on parameters")
		return false

static func get_best_hand(given_cards: Array):
	var best_hand: Hand = Hand.new([])
	var possible_hands = get_combinations(given_cards, Rules.RULES["CARDS_PER_HAND"])
	
	for hand in possible_hands:
		var new_hand = Hand.new(hand)
		best_hand = new_hand if Hand.sort(new_hand, best_hand) else best_hand
	
	return best_hand

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

static func hand_to_string(hand: Array):
	var hand_string = "["
	for card in hand:
		hand_string += Rules.get_proper_symbol(card)
		hand_string += " "
	hand_string[-1] = "]"
	
	if Rules.get_value(hand.front()) == Rules.RULES["VALS_PER_SUIT"] - 1 \
		and Rules.get_value(hand[1]) == Rules.RULES["CARDS_PER_HAND"] - 2:
		var slices = hand_string.split(" ", false, 1)
		hand_string = "[%s %s]" % [slices[1].left(-1), slices[0].right(2)]
	
	return hand_string
