class_name Hand

var cards = []
var rank = ""
var kickerA = -1
var kickerB = -1
var kickerC = -1

func _init(given_cards: Array):
	if not given_cards.is_empty():
		self.cards = given_cards
		classify()

func classify():
	var clean_values = self.cards.map(Rules.get_value)
	clean_values.sort();
	var runs = []
	
	var wild_count = self.cards.count(Rules.FREE_WILD)
	if wild_count == Rules.RULES.CARDS_PER_HAND:
		self.rank = "AW"
		return
	
	var is_straight = sequential(clean_values)
	var is_flush = test_flush(self.cards.map(Rules.get_suit))
	
	if not is_straight.is_empty():
		for i in is_straight:
			if (i & Rules.WILD):
				set_wild(i)
	
	# Lowball poker ignores flushes and straights except in the case of wheels
	if Rules.RULES.BALL == -1:
		if not is_straight.is_empty():
			if is_straight[0] == Rules.RULES.VALS_PER_SUIT - 1 and \
			is_straight[1] == Rules.RULES.CARDS_PER_HAND - 2:
				self.rank = "SW" if is_flush else "WH"
				return
		# If it hasn't returned by now, clear it all
		is_straight.clear()
		is_flush = false
	# 5K > SF, always
	# 4K > FL and 4K > ST, always
	elif (wild_count >= 4 and Rules.RULES.CARDS_PER_HAND >= 5) or wild_count >= 3:
			is_straight.clear()
			is_flush = false
	
	for value in Rules.RULES.VALS_PER_SUIT:
		var val_count = clean_values.count(value)
		if val_count > 1:
			runs.append([val_count, value])
			# Lowest value runs first
	
	# Wild adjustments
	wild_count = self.cards.count(Rules.FREE_WILD)
	if wild_count > 0:
		if Rules.RULES.BALL == 1:
			# Highball: Focus on improving runs of cards
			match runs.size():
				0:
					var highest_card = clean_values.filter(func(c): return c < Rules.WILD).max()
					runs.append([1 + wild_count, highest_card])
					set_wild(highest_card, true)
				1:
					runs[0][0] += wild_count
					set_wild(runs[0][1], true)
				2:
					match [runs[0][0], runs[1][0]]:
						[2,2], [2,3]:
							runs[1][0] += wild_count
							set_wild(runs[1][1], true)
						[3,2]:
							runs[0][0] += wild_count
							set_wild(runs[0][1], true)
		else:
			# Lowball: Just add the lowest values that aren't already in the hand
			for i in Rules.RULES.VALS_PER_SUIT:
				if wild_count > 0 and not i in clean_values:
					set_wild(i)
					wild_count -= 1
	runs.sort_custom(func(a,b): return a[0] > b[0])
	
	#assert(runs.all(func(c): return c[0] <= self.cards.size()))
	
	for i in clean_values.size():
		if clean_values[i] == Rules.FREE_WILD:
			clean_values[i] = Rules.get_value(self.cards[i])
	clean_values.sort()
	
	match [not is_straight.is_empty(), is_flush]:
		[true, var also_flush]:
			if Rules.get_value(clean_values[-1]) == Rules.RULES.VALS_PER_SUIT - 1 and \
				Rules.get_value(clean_values[-2]) == Rules.RULES.CARDS_PER_HAND - 2:
					self.kickerA = clean_values[-2]
			else:
				self.kickerA = clean_values.back()
			
			self.rank = "SF" if also_flush else "ST"
		[false, true]:
			self.rank = "FL"
			self.kickerA = clean_values[-1]
			self.kickerB = clean_values[-2]
			self.kickerC = clean_values[-3]
		[false, false]:
			match runs.size():
				0: 
					self.rank = "HC"
					self.kickerA = clean_values[-1]
					self.kickerB = clean_values[-2]
					self.kickerC = clean_values[-3]
				1:
					self.kickerA = runs[0][1]
					var rest = clean_values.duplicate()
					for i in runs[0][0]:
						rest.erase(runs[0][1])
					
					if rest.size() > 0: self.kickerB = rest[-1]
					if rest.size() > 1: self.kickerC = rest[-2]
					
					match runs[0][0]:
						6: self.rank = "6K"
						5: self.rank = "5K"
						4: self.rank = "4K"
						3: self.rank = "3K"
						2: self.rank = "1P"
				2:
					var groups = [runs[1][0], runs[0][0]]
					var full = groups[0] + groups[1] == clean_values.size()
					
					if groups[0] == groups[1]:
						self.kickerA = maxi(runs[1][1], runs[0][1])
						self.kickerB = mini(runs[0][1], runs[1][1])
					else:
						self.kickerA = runs[1][1] if groups[0] > groups[1] else runs[0][1]
						self.kickerB = runs[1][1] if groups[0] < groups[1] else runs[0][1]
					
					if not full:
						self.kickerC = clean_values.reduce(func(a, n): 
							return n if not (n in [self.kickerA, self.kickerB]) else a, -1)
					
					match groups:
						[2, 2]:
							self.rank = "2P"
						[3, 3]:
							self.rank = "2T"
						[_, _]:
							if full:
								self.rank = "FH"
							else: 
								self.rank = "CR"
				3:
					self.rank = "3P"
					self.kickerA = runs[2][1]
					self.kickerB = runs[1][1]
					self.kickerC = runs[0][1]
				_:
					push_error("wadda hell")
	
	#print("%s: %s | [%d, %d, %d]" % [self.rank, clean_values, self.kickerA, self.kickerB, self.kickerC])

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
		"SW":
			hand_name = "Steel wheel"
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
		"WH":
			hand_name = "Wheel"
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
			hand_name = "High card" if Rules.RULES.BALL > 0 else "Low card"
		"":
			hand_name = "Invalid hand"
	return hand_name

func sequential(array) -> Array:
	# Main variables
	var full_mask = (1 << Rules.RULES.CARDS_PER_HAND) - 1
	var ace_low_mask = (full_mask >> 1) | (1 << (Rules.RULES.VALS_PER_SUIT - 1))
	var bitmask = 0
	var wilds = 0
	var wild_values = []
	var wild_toggle = Rules.WILD | Rules.FREE_WILD
	var do_lowball_test = false
	# Functions
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
	var clean_up_and_return = func():
		var results = []
		for i in array:
			if i & Rules.FREE_WILD:
				results.append(i ^ wild_values.pop_front())
			else:
				results.append(i)
		return results
	
	# Step 1: Index all the cards in the hand by value
	for val in array:
		if val & Rules.FREE_WILD: wilds += 1
		else: 
			if bitmask & 1 << val == 1 << val: return []
			else: bitmask |= 1 << val
	
	if straight_match.call(bitmask):
		return array # This is already a straight! Nice
	elif wilds == 0:
		return [] # We can't fix this one chief
	elif Rules.RULES.BALL == -1:
		if compute_hamming_weight.call(ace_low_mask ^ bitmask) <= wilds:
			do_lowball_test = true
		else:
			return [] # Don't even bother.
	
	# Calculate index of first one in bitmask
	var shifts = bitmask & -bitmask
	var had_two = bool(bitmask & 1)
	
	# Step 2: Patch holes
	var hole_patcher = bitmask
	# Set the ace aside
	var ace_holder = 0
	var ace_test = 1 << (Rules.RULES.VALS_PER_SUIT - 1)
	if hole_patcher & ace_test: 
		hole_patcher ^= ace_test
		bitmask ^= ace_test
		ace_holder ^= ace_test
	# XOR holes with nearest PO2 - 1 to highlight the gaps
	hole_patcher ^= (nearest_po2(hole_patcher) - 1) - (shifts - 1)
	
	# Calculate Hamming weight to see if wilds can even save this
	var hamming_weight = compute_hamming_weight.call(hole_patcher)
	if hamming_weight > wilds: return []
	elif not do_lowball_test:
		if bitmask / shifts in [0b1, 0b11, 0b111, 0b1111, 0b11111]:
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
					wild_values.append(wild_toggle | roundi(log(highest_index) / log(2)))
					wilds -= 1
				else: break
			# If straight, clock out
		if straight_match.call(bitmask | ace_holder): return clean_up_and_return.call()
	
	# Step 2.5: If this is a lowball game, specifically try to build an ace-low straight
	else:
		var lowball_mask = ace_low_mask ^ (bitmask | ace_holder)
		if not ace_holder:
			wild_values.append(wild_toggle | (Rules.RULES.VALS_PER_SUIT - 1))
			wilds -= 1
			ace_holder ^= ace_test
			lowball_mask ^= ace_test # Since I have it
		
		hamming_weight = compute_hamming_weight.call(lowball_mask)
		while wilds > 0:
			var NPO2 = nearest_po2(lowball_mask)
			var highest_index = (NPO2 >> 1) if NPO2 > lowball_mask else lowball_mask
			lowball_mask ^= highest_index
			bitmask ^= highest_index
			var new_weight = compute_hamming_weight.call(lowball_mask)
			if new_weight < hamming_weight:
				hamming_weight = new_weight
				wild_values.append(wild_toggle | roundi(log(highest_index) / log(2)))
				wilds -= 1
			else: break
		
		if straight_match.call(bitmask | ace_holder): 
			return clean_up_and_return.call()
		else:
			return [] # If you can't wheel, you can't deal
	
	# Step 3: Build edges
	var post_shifts = 0
	for i in wilds:
		var NPO2 = nearest_po2(bitmask)
		if NPO2 == bitmask: NPO2 = (nearest_po2(bitmask + 1))
		var highest_val = NPO2
		if NPO2 > 2 ** Rules.RULES.VALS_PER_SUIT - 1: 
			highest_val = shifts >> (1 + post_shifts)
			post_shifts += 1
		bitmask |= highest_val
		wild_values.append(wild_toggle | roundi(log(highest_val) / log(2)))
	# If straight, clock out, else not a straight
	if straight_match.call(bitmask | ace_holder): return clean_up_and_return.call()
	# Or maybe it was low?
	if not had_two and straight_match.call((bitmask >> 1) | ace_holder):
		# But was it really?
		var results = []
		for i in array:
			if i & Rules.FREE_WILD:
				results.append(i ^ wild_values.pop_front())
			else:
				results.append(i)
		# If highest non-ace is wild, replace it with a wild 2
		results.sort_custom(func(a,b): return Rules.get_value(a) > Rules.get_value(b))
		if results[1] & Rules.WILD:
			results[1] = Rules.WILD
		
		var true_test = 0
		for i in results:
			true_test |= 1 << Rules.get_value(i)

		if true_test ^ ace_low_mask:
			# Sike
			return []
		else:
			# We gottem
			return results
	
	return []

func test_flush(array):
	var good_array = array.filter(func(c): return c < Rules.RULES.SUITS)
	return good_array.all(func(i): return i == good_array[0])

func set_wild(value: int, set_all: bool = false):
	for i in self.cards.size():
		if self.cards[i] & Rules.FREE_WILD:
			self.cards[i] = (self.cards[i] >> 1) | value
			if not set_all: return

static func sort(a: Hand, b:Hand) -> bool:
	if a == null or a.rank.is_empty(): return false
	if b == null or b.rank.is_empty(): return true
	
	# A != B -> A - B <> 0
	# * BALL (1 or -1) flips result, compared to 0
	if a.rank != b.rank:
		return ((Rules.RULES.HAND_RANKS[a.rank] - Rules.RULES.HAND_RANKS[b.rank]) * Rules.RULES.BALL) > 0
	elif a.kickerA != b.kickerA:
		return ((a.kickerA - b.kickerA) * Rules.RULES.BALL) > 0
	elif a.kickerB != b.kickerB:
		return ((a.kickerB - b.kickerB) * Rules.RULES.BALL) > 0
	elif a.kickerC != b.kickerC:
		return ((a.kickerC - b.kickerC) * Rules.RULES.BALL) > 0
	else:
		return (a.cards.map(Rules.get_value) > b.cards.map(Rules.get_value)) != (Rules.RULES.BALL != 1)

static func is_equal(a, b) -> bool:
	if typeof(a) != typeof(Hand): a = Hand.new(a)
	if typeof(b) != typeof(Hand): b = Hand.new(b)
	return Hand.sort(a, b) == Hand.sort(b, a)

static func get_best_hand(given_cards: Array):
	var best_hand: Hand = Hand.new([])
	var test_hand: Hand
	var possible_hands = get_combinations(given_cards, Rules.RULES.CARDS_PER_HAND)
	
	for hand in possible_hands:
		test_hand = Hand.new(hand)
		
		if test_hand.rank not in Rules.RULES.HAND_RANKS: 
			continue
		
		best_hand = test_hand if Hand.sort(test_hand, best_hand) else best_hand
	
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

static func hand_to_string(hand, unicode = false):
	if hand is Hand:
		hand = hand.cards
	hand.sort_custom(func(a,b): return Rules.get_value(a) > Rules.get_value(b))
	
	var hand_string = "["
	if not unicode:
		for card in hand:
			hand_string += Rules.get_card_string(card)
			hand_string += " "
		hand_string[-1] = "]"
	else:
		for card in hand:
			hand_string += Rules.get_proper_value(card)
			var suit = Rules.get_suit(card)
			hand_string += "\u2660\u2665\u2663\u2666\u2605\u263E"[suit] if suit < Rules.RULES.SUITS else "\U01F0CF"
			hand_string += " "
		hand_string[-1] = "]"
	
	return hand_string
