class_name PokerPartyAI
extends Node

signal answered(option: String, value: int)
signal done

#region Constansts
const MIN_THINK_TIME = 7.5
const ANSWER_MARGIN = 3.0
const MAX_MONTE_CARLO_TESTS = 5000
const AVERAGE_SCORES = [0, 0, 0, 0, 46.8, 61.7, 85.0]

const NAMES = ["Pique", "Jessie", "Andy", "Hans", "Chippy", "Luna", "Sol", "Ruby", "Clover", "Cardia"]
const COLORS = ["1C1469", "8C008C", "FF7A38", "B0B0B0", "FF3232", "BA6B04", "FFE559", "FF420D", "257312", "FF458C"]
const ICONS = [0, 6, -1, 7, -1, 5, 4, 3, 2, 1]

const HAND_EVOLUTION = {
	"HC": ["1P", "1P", "1P"],
	"1P": ["3K", "2P", "2P"],
	"2P": ["FH", "FH", "3P"],
	"3P": ["FH", "FH", "FH"],
	"3K": ["4K", "FH", null],
	"FH": ["4K", null, "5K"],
	"CR": ["FH", "2T", null],
	"2T": ["FH", "FH", null],
	"4K": ["5K", "FH", null],
	"5K": ["6K", null, null]
}
#endregion

#region Variables
var player_info = {
	"name": "Player",
	"cards": [],
	"chips": 0,
	"current_bet": 0,
	"awaiting": false,
	
	"icon": 0,
	"color": Color.BLACK
}
var think_timer: Timer
var keep_thinking: bool
var combo_base: Array # Player's hole cards + all community cards
var remaining_cards: Array # The deck, minus the above cards
var current_max_bet: int
var high_ball = true
var use_outs = false

var thread_BF: Thread
var thread_MC: Thread
var thread_OUTS: Thread
var sem_MC: Semaphore
var sem_BF: Semaphore
var sem_OUTS: Semaphore
var mutex: Mutex
var run_threads = true
var result = [0, 0]
var previous_answers = [null, null]

var optimism: float # Expectation that things will go in your favor
var confidence: float # A measure of risk-taking, really; higher confidence -> bigger bets
var last_active: int # The number of active players last time you were asked. For boosting attributes later in the game
#endregion

# ID parameter really just for indexing into names array; from 0 to -9
func setup(id, style = 0):
	player_info.name = NAMES[id]
	player_info.color = Color.html(COLORS[id])
	player_info.icon = ICONS[id] if ICONS[id] >= 0 else randi_range(0, 7)
	optimism = randf()
	confidence = randf() + 0.5 # [0.50, 1.50]
	
	use_outs = (style != 0)
	
	think_timer = Timer.new()
	add_child(think_timer)
	mutex = Mutex.new()
	
	if not use_outs:
		thread_BF = Thread.new()
		thread_MC = Thread.new()
		sem_MC = Semaphore.new()
		sem_BF = Semaphore.new()
		
		thread_BF.start(think_brute_force)
		thread_MC.start(think_monte_carlo)
		
		think_timer.timeout.connect(answer)
		done.connect(answer)
	else:
		thread_OUTS = Thread.new()
		sem_OUTS = Semaphore.new()
		
		thread_OUTS.start(think_with_outs)
		
		think_timer.timeout.connect(answer_outs)
		done.connect(answer_outs)

func think(bet):
	keep_thinking = true
	current_max_bet = bet
	high_ball = Rules.RULES.BALL == 1
	think_timer.start(get_think_time())
	
	# Small boosts to make lategame more fun
	confidence += 0.2 * (last_active - Netgame.game_state.active_players.size()) if last_active > 0 else 0
	optimism += 0.1 if (last_active - Netgame.game_state.active_players.size()) > 0 else 0
	last_active = Netgame.game_state.active_players.size()
	
	if bet >= player_info.chips + player_info.current_bet:
		if use_outs:
			answer_outs()
		else:
			answer()
		return
	
	var all_cards = range(Rules.get_deck_size())
	for i in (Rules.RULES.SUITS * Rules.RULES.WILDS):
		all_cards.append(Rules.FREE_WILD)
	var comm_cards = Netgame.game_state.comm_cards
	combo_base = player_info.cards.duplicate() 
	combo_base.append_array(comm_cards)
	remaining_cards = array_subtract(all_cards, combo_base)
	var cards_to_guess = Rules.RULES.COMM_CARDS - comm_cards.size()
	
	if not use_outs:
		var combinations = combi(remaining_cards.size(), cards_to_guess)
		
		if previous_answers[0] == null:
			if combinations >= MAX_MONTE_CARLO_TESTS:
				#print("Running Monte Carlo simulation...")
				sem_MC.post()
			else:
				#print("Running brute force algorithm...")
				sem_BF.post()
		else:
			await get_tree().create_timer(3.0 - (1.2 * confidence)).timeout
			answer()
	else:
		if previous_answers[0] == null:
			sem_OUTS.post()
		else:
			await get_tree().create_timer(3.0 - (1.2 * confidence)).timeout
			answer_outs()

func answer():
	think_timer.stop()
	
	mutex.lock()
	keep_thinking = false
	mutex.unlock()
	
	await get_tree().create_timer(0.5).timeout
	
	mutex.lock()
	var thread_result = result
	mutex.unlock()
	
	if thread_result != previous_answers:
		previous_answers = thread_result.duplicate()
	
	var cards_guessed = Rules.RULES.COMM_CARDS - Netgame.game_state.comm_cards.size()
	cards_guessed += combo_base.filter(func(c): return c & Rules.HIDDEN).size()
	var certainty = clampf((5 - cards_guessed) / 3.0, 0.125, 1)
	var all_player_chips = player_info.chips + player_info.current_bet
	
	# If thread found better average score than overall average
	if (high_ball and thread_result[0] > AVERAGE_SCORES[Rules.RULES.CARDS_PER_HAND]) \
	or (not high_ball and thread_result[0] < AVERAGE_SCORES[Rules.RULES.CARDS_PER_HAND]):
		# find place between ovr.avg and max
		var b = inverse_lerp(AVERAGE_SCORES[Rules.RULES.CARDS_PER_HAND], thread_result[1], thread_result[0])
		
		if randf() * certainty < optimism:
			# Sure I want to bet
			var value = mini(maxi(
				snappedi(Netgame.game_state.pot * (b / 3.0), 5) + player_info.current_bet, 
				Rules.RULES.MIN_BET
			), player_info.chips)
			value += current_max_bet
			
			if value > 0 and player_info.chips > 0:
				# Definitely can bet
				if value <= Netgame.game_state.pot * confidence:
					# Take my chips
					answered.emit("RAISE", mini(value, all_player_chips))
					print("%d <= %.2f: Raise to %d" % [value, Netgame.game_state.pot * confidence, mini(value, all_player_chips)])
					return
				else:
					# ... but not that much
					answered.emit("FOLD", 0)
					print("%d > %.2f: Fold" % [value, Netgame.game_state.pot * confidence])
					return
		
		# Fallthrough call
		answered.emit("CALL", maxi(current_max_bet - player_info.current_bet, 0))
		print("Not betting yet: Check" if current_max_bet == 0 else "Can meet that bet: Call")
	# If it didn't
	else:
		if randf() * certainty < optimism:
			# Sure I'll stick around
			if current_max_bet - player_info.current_bet <= Netgame.game_state.pot * confidence:
				# Not much more to stake, so
				answered.emit("CALL", maxi(current_max_bet - player_info.current_bet, 0))
				print("Staying in the round: Call")
				return
		
		# Fallthrough fold
		answered.emit("FOLD", 0)
		print("Fold")
func answer_outs():
	think_timer.stop()
	
	mutex.lock()
	keep_thinking = false
	mutex.unlock()
	
	await get_tree().create_timer(0.5).timeout
	
	mutex.lock()
	var thread_result = result
	# In the form of [chance to improve hand, approx. equity]
	mutex.unlock()
	
	if thread_result != previous_answers:
		previous_answers = thread_result.duplicate()
	
	var certainty = 1 - (0.6 * combo_base.filter(func(c): return c & Rules.HIDDEN).size() / float(Rules.RULES.CARDS_PER_HAND))
	var pot_odds = current_max_bet / float(current_max_bet + Netgame.game_state.pot)
	
	#prints(thread_result, pot_odds)
	
	var call_amt = maxi(current_max_bet - player_info.current_bet, 0)
	# Positive net value on calls with equity better than pot odds
	prints(snappedf(thread_result[1] * certainty * confidence, 0.001), snappedf(pot_odds, 0.001))
	if thread_result[1] * certainty * confidence > pot_odds + (randf() * 0.7):
		if thread_result[1] * optimism * confidence > randf():
			# Even raise a little bit
			var all_player_chips = player_info.chips + player_info.current_bet
			var extra_amt = 1 + (confidence * optimism)
			var new_bet = snappedi(current_max_bet * extra_amt, Rules.RULES.MIN_BET) if current_max_bet > 0 \
			else snappedi(confidence * extra_amt * Rules.RULES.MIN_BET, Rules.RULES.MIN_BET)
			
			#print("%d ? %d" % [new_bet, current_max_bet])
			if new_bet > current_max_bet and new_bet <= all_player_chips:
				print("Absolutely, raising %.2f%%" % ((extra_amt - 1) * 100))
				answered.emit("RAISE", mini(all_player_chips, new_bet))
			else:
				print("Totally want to raise, but unsure: Call")
				answered.emit("CALL", call_amt)
		else:
			# Just stay in the round, you're doing great
			print("Nice position, staying in the round: Call")
			answered.emit("CALL", call_amt)
	else:
		# Still stay if you can keep building, or if the hand is still decent
		if thread_result[0] * optimism > randf() or thread_result[1] > 0.5:
			if thread_result[1] > 0.5:
				print("Hand still good: Call")
			else:
				print("Looking to keep building: Call")
			answered.emit("CALL", call_amt)
		else:
			# Game over, man
			print("Bad hand: Fold")
			answered.emit("FOLD", 0)

func get_think_time():
	var max_move_time = Rules.RULES.SPEED - ANSWER_MARGIN
	var estimated_think_time = MIN_THINK_TIME
	for change in Rules.RULES.CURRENT_CHANGES:
		if change.ends_with("UP"):
			estimated_think_time += 1.5
		else:
			estimated_think_time += 0.5
	if not high_ball:
		estimated_think_time += 1.0
	
	return minf(max_move_time, estimated_think_time)

#region AI think types
func think_brute_force():
	while run_threads:
		sem_BF.wait()
		
		var avg_score = 0.0
		var max_score = 0.0
		var combos_evaluated = 0
		var cards_to_guess = Rules.RULES.COMM_CARDS - Netgame.game_state.comm_cards.size()
		var card_tests = range(cards_to_guess)
		
		if cards_to_guess > 0:
			while keep_thinking and card_tests[0] <= (remaining_cards.size() - cards_to_guess):
				var trial_combo = combo_base.duplicate()
				for idx in card_tests:
					trial_combo.append(remaining_cards[idx])
				for i in trial_combo.size():
					if trial_combo[i] & Rules.HIDDEN:
						trial_combo[i] = randi_range(0, Rules.get_deck_size())
				
				var combo_score = evaluate(Hand.get_best_hand(trial_combo))
				
				avg_score = (combo_score + combos_evaluated * avg_score) / (combos_evaluated + 1)
				max_score = maxf(max_score, combo_score) if high_ball else minf(max_score, avg_score)
				combos_evaluated += 1
				#print("#%d: %s: %.4f (%.4f)" % [combos_evaluated, trial_combo, combo_score, avg_score])
				
				card_tests[-1] += 1
				for i in range(-1, -cards_to_guess, -1):
					if card_tests[i] % (remaining_cards.size() + i + 1) == 0:
						card_tests[i - 1] += 1
						for j in range(i, 0):
							card_tests[j] = card_tests[j - 1] + 1
		else:
			avg_score = evaluate(Hand.new(combo_base))
			max_score = avg_score
		
		mutex.lock()
		result = [avg_score, max_score]
		mutex.unlock()
		
		#print("Brute Force complete")
		#print(str(result))
		if keep_thinking:
			think_timer.call_thread_safe("stop")
			call_thread_safe("emit_signal", "done")
func think_monte_carlo():
	while run_threads:
		sem_MC.wait()
		
		var avg_score = 0.0
		var max_score = 0.0
		var combos_evaluated = 0
		var idx = 0
		var cards_to_guess = Rules.RULES.COMM_CARDS - Netgame.game_state.comm_cards.size()
		remaining_cards.shuffle()
		
		while keep_thinking and combos_evaluated < MAX_MONTE_CARLO_TESTS:
			if idx + cards_to_guess > remaining_cards.size():
				idx = 0
				remaining_cards.shuffle()
			var extras = remaining_cards.slice(idx, idx + cards_to_guess)
			
			var combo = combo_base.duplicate()
			combo.append_array(extras)
			
			var i = 0
			for ix in combo.size():
				if combo[ix] & Rules.HIDDEN:
					combo[ix] = remaining_cards[idx + cards_to_guess + i]
					i += 1
			
			var combo_score = evaluate(Hand.get_best_hand(combo))
			
			avg_score = (combo_score + combos_evaluated * avg_score) / (combos_evaluated + 1)
			max_score = maxf(max_score, combo_score) if high_ball else minf(max_score, avg_score)
			combos_evaluated += 1
			#print("#%d: %s: %.4f (%.4f)" % [combos_evaluated, combo, combo_score, avg_score])
			
			idx += (cards_to_guess + i)
		
		mutex.lock()
		result = [avg_score, max_score]
		mutex.unlock()
		
		#print("Performed %d Monte Carlo iterations" % combos_evaluated)
		#print(str(result))
		if keep_thinking:
			think_timer.call_thread_safe("stop")
			call_thread_safe("emit_signal", "done")
func think_with_outs():
	while run_threads:
		sem_OUTS.wait()
		
		for c in combo_base.size():
			if combo_base[c] & Rules.HIDDEN:
				combo_base[c] = randi() % Rules.get_deck_size()
		
		var current_best = Hand.get_best_hand(combo_base)
		#print("HAND: %s" % Hand.hand_to_string(current_best, true))
		var wilds = combo_base.count(Rules.FREE_WILD)
		var remaining_wilds = (Rules.RULES.SUITS * Rules.RULES.WILDS) - wilds
		var possible_improvements = HAND_EVOLUTION.get(current_best.rank, [null, null, null])
		# Surprise tool that'll help us later
		var rounds_remaining = Rules.RULES.COMM_CARDS - Netgame.game_state.comm_cards.size()
		var total_outs = remaining_wilds # All wilds are outs by default
		#print("Outs so far: %d" % total_outs)
		
		# Flush counting
		var besuited = combo_base.map(func(c): return Rules.get_suit(c))
		for i in Rules.RULES.SUITS:
			var ct = besuited.count(i)
			# Add every other card of suit if close to a flush
			if ct + wilds >= Rules.RULES.CARDS_PER_HAND - 1:
				total_outs += Rules.RULES.VALS_PER_SUIT - ct
				#print("Outs so far: %d (Remaining cards of suit %d)" % [total_outs, i])
		
		# Straight checking
		var has_value = []
		var double_check = []
		var bevalued = combo_base.map(func(c): return Rules.get_value(c))
		for i in Rules.RULES.VALS_PER_SUIT:
			has_value.append(int(bevalued.has(i)))
		has_value.push_front(has_value.back())
		
		for i in (Rules.RULES.VALS_PER_SUIT - Rules.RULES.CARDS_PER_HAND + 1):
			var window = has_value.slice(i, Rules.RULES.CARDS_PER_HAND + i)
			var num = window.reduce(func(a, n): return a+n, 0) + wilds # Add wilds to not calculate on made straights
			# Add all missing cards to straights as outs
			if num < Rules.RULES.CARDS_PER_HAND \
			and Rules.RULES.CARDS_PER_HAND - num <= rounds_remaining:
				for v in window.size():
					if window[v] == 0 and not (i+v-1) in double_check: 
						total_outs += (Rules.RULES.SUITS - bevalued.count(i+v-1)) # Hope this is the right thing to count
						#print("Outs so far: %d (%ss for a straight)" % [total_outs, Rules.get_proper_value(i+v-1)])
						double_check.append(i+v-1)
		
		# Moved under flush/straight counting to make use of bevalued
		match Rules.RULES.CARDS_PER_HAND:
			4, 5:
				# Add remaining cards of kickers to outs
				# Only tracking the three best kickers
				var sub = [current_best.kickerA, current_best.kickerB, current_best.kickerC]
				for i in 3:
					if i == 2 and current_best.rank == "FH":
						continue
					
					if possible_improvements[i] != null and Rules.RULES.HAND_RANKS.has(possible_improvements[i]):
						total_outs += (Rules.RULES.SUITS - bevalued.count(sub[i]))
						#print("Outs so far: %d (Remaining %ss)" % [total_outs, Rules.get_proper_value(sub[i])])
			6:
				# The same as above but more complicated
				var sub = [current_best.kickerA, current_best.kickerB, current_best.kickerC]
				for i in 3:
					if possible_improvements[i] == "FH":
						if i == 0:
							continue
						if Rules.RULES.HAND_RANKS[current_best.rank] < Rules.RULES.HAND_RANKS["4K"]:
							possible_improvements[i] = "CR"
					
					if possible_improvements[i] != null and Rules.RULES.HAND_RANKS.has(possible_improvements[i]):
						total_outs += (Rules.RULES.SUITS - bevalued.count(sub[i]))
						#print("Outs so far: %d (Remaining %ss)" % [total_outs, Rules.get_proper_value(sub[i])])
		
		# 2x rounds remaining, x1% to put between 0 and 1
		var chance_to_improve = minf(total_outs * 0.02 * rounds_remaining, 1.0)
		
		# Chance of a better hand of the same type, REGARDLESS of if it's possible
		var p_better_same = 0.0
		var val_pow = 0
		for x in [current_best.kickerA, current_best.kickerB, current_best.kickerC]:
			if x != null:
				p_better_same *= Rules.RULES.VALS_PER_SUIT
				p_better_same += (Rules.RULES.VALS_PER_SUIT - x - 1)
				val_pow += 1
		p_better_same /= (Rules.RULES.VALS_PER_SUIT ** val_pow)
		
		# Chance of a better type of hand at all
		var all_hands = 0
		var better_hands = 0
		for hand in Rules.RULES.HAND_RANKS:
			if hand == "AW" or hand == "": continue # Probably not gonna happen
			if Rules.RULES.BALL == 1 and hand in ["WH", "SW"]: continue # Lowball hands; ignore
			if Rules.RULES.BALL == -1 and hand in ["ST", "FL", "SF"]: continue # Highball hands; ignore
			
			var total = get_total_hands(hand)
			if (Rules.RULES.HAND_RANKS[hand] > Rules.RULES.HAND_RANKS[current_best.rank]) != (Rules.RULES.BALL != 1):
				better_hands += total
			all_hands += total
		var p_better_type = float(better_hands) / all_hands
		
		var approx_equity = 1 - (p_better_type + p_better_same - (p_better_type * p_better_same))
		
		mutex.lock()
		result = [chance_to_improve, approx_equity]
		print("Thinking done: Chance to improve %.2f%%, approximate equity %.2f%%" % [result[0] * 100, result[1] * 100])
		mutex.unlock()
		
		if keep_thinking:
			think_timer.call_thread_safe("stop")
			call_thread_safe("emit_signal", "done")
#endregion

# AI rule change decision making
func do_rule_change(option_a, option_b):
	var choice = [option_a, option_b].pick_random()
	var info_dict = RuleChanger.get_info_dict(RuleChanger.get_option_information(choice))
	
	var rule = info_dict.RULE
	var value = info_dict.VALUE if typeof(info_dict.VALUE) == TYPE_INT else 0
	
	await get_tree().create_timer(randf_range(0.8, 2.4)).timeout
	return [rule, value, choice]

func array_subtract(A: Array, B: Array):
	var AA = A.duplicate()
	for b in B:
		AA.erase(b)
	return AA

func evaluate(hand: Hand):
	var score: float
	
	if hand.rank in Rules.RULES.HAND_RANKS:
		score = Rules.RULES.HAND_RANKS[hand.rank]
	else:
		return -INF
	
	for i in hand.cards.size():
		score += float(Rules.get_value(hand.cards[i])) / (i + 1)
	return score

func round_reset():
	current_max_bet = 0
	previous_answers = [null, null]

#region Combinatorics
func combi(n: int, r: int) -> int:
	if r == n or r == 0: return 1
	if r == 1 or r == n - 1: return n
	if r > n: return 0
	
	var combinations = 1
	for x in range(n, n - r, -1):
		combinations *= x
	for x in (r + 1):
		combinations /= maxi(1, x)
	return combinations

func get_total_hands(rank: String) -> int:
	var S = Rules.RULES.SUITS
	var V = Rules.RULES.VALS_PER_SUIT
	var H = Rules.RULES.CARDS_PER_HAND
	# Number of unique straights, by value
	var T = V - H + 2
	
	match rank:
		"1P", "3K", "4K", "5K", "6K":
			return x_of_a_kind(maxi(2, int(rank[0])), S, V, H)
		"2P", "3P":
			return x_pair(int(rank[0]), S, V, H)
		"FH":
			return (V * combi(S, 2)) * ((V - 1) * combi(S, H - 2))
		"CR":
			return (V * combi(S, 3)) * ((V - 1) * combi(S, 2)) * ((V - 2) * S)
		"ST", "WH":
			return T * ((S ** H) - S)
		"FL":
			return S * (combi(V, H) - T)
		"SF", "SW":
			return S * T
		"2T":
			return combi(V, 2) * (combi(S, 3) ** 2)
		"HC":
			return (combi(V, H) - T) * ((S ** H) - S)
		_:
			return 0

func x_of_a_kind(x: int, s: int, v: int, h: int) -> int:
	var not_of_a_kind = h - x
	return (v * combi(s, x)) * (combi(v - 1, not_of_a_kind) * (s ** not_of_a_kind))

func x_pair(x: int, s: int, v: int, h: int) -> int:
	var not_pairs = h - (2 * x)
	return combi(v, x) * (combi(s, 2) ** x) * (combi(v - x, not_pairs) * (s ** not_pairs))
#endregion

func _exit_tree():
	mutex.lock()
	run_threads = false
	keep_thinking = false
	mutex.unlock()
	
	if not use_outs:
		sem_BF.post()
		thread_BF.wait_to_finish()
		
		sem_MC.post()
		thread_MC.wait_to_finish()
	else:
		sem_OUTS.post()
		thread_OUTS.wait_to_finish()
