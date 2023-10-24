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
	
	for value in Rules.RULES["VALS_PER_SUIT"]:
		var val_count = clean_values.count(value)
		if val_count > 1:
			runs.append([val_count, value])
	
	runs.sort_custom(func(a,b): return a[0] > b[0])
	
	match [is_straight, is_flush]:
		[true, var also_flush]:
			self.kickerA = self.cards.front()
			if Rules.get_value(self.kickerA) == Rules.RULES["VALS_PER_SUIT"] - 1:
				if Rules.get_value(self.cards[1]) == 3:
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
			return hand_name
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
			return hand_name
		"":
			hand_name = "Invalid hand"
	return hand_name

func sequential(array):
	var is_sequential = true
	for i in array.size() - 1:
		is_sequential = is_sequential and (array[i] - 1 == array[i+1])
		if not is_sequential: break
	
	var ace_low_test = range(array.size() - 1)
	ace_low_test.append(Rules.RULES["VALS_PER_SUIT"] - 1)
	ace_low_test.reverse()
	
	return is_sequential or (array == ace_low_test)

func all_equal(array):
	var equal = true
	for i in array.size() - 1:
		equal = equal and (array[i] == array[i+1])
		if not equal: break
	return equal

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
	return hand_string
