class_name PokerPartyAI
extends Node

signal answered(option: String, value: int)
signal done

const MIN_THINK_TIME = 7.5
const ANSWER_MARGIN = 3.0
const MAX_MONTE_CARLO_TESTS = 5000
const AVERAGE_SCORES = [0, 0, 0, 0, 46.8, 61.7, 85.0]

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
var combo_base: Array
var remaining_cards: Array
var current_max_bet: int
var high_ball = true

var thread_BF: Thread
var thread_MC: Thread
var sem_MC: Semaphore
var sem_BF: Semaphore
var mutex: Mutex
var run_threads = true
var result = [0, 0]

var optimism: float

func setup():
	player_info.name = "AI Player"
	optimism = randf()
	
	think_timer = Timer.new()
	think_timer.timeout.connect(answer)
	add_child(think_timer)
	
	thread_BF = Thread.new()
	thread_MC = Thread.new()
	sem_MC = Semaphore.new()
	sem_BF = Semaphore.new()
	mutex = Mutex.new()
	
	thread_BF.start(think_brute_force)
	thread_MC.start(think_monte_carlo)
	
	done.connect(answer)

func think(bet):
	keep_thinking = true
	current_max_bet = bet
	high_ball = Rules.RULES.BALL == 1
	think_timer.start(get_think_time())
	
	var all_cards = range(Rules.get_deck_size())
	for i in (Rules.RULES.SUITS * Rules.RULES.WILDS):
		all_cards.append(Rules.FREE_WILD)
	var comm_cards = Netgame.game_state.comm_cards
	combo_base = player_info.cards.duplicate() 
	combo_base.append_array(comm_cards)
	remaining_cards = array_subtract(all_cards, combo_base)
	var cards_to_guess = Rules.RULES.COMM_CARDS - comm_cards.size()
	
	var combinations = 1
	for n in range(remaining_cards.size(), remaining_cards.size() - cards_to_guess, -1):
		combinations *= n
	for n in (cards_to_guess + 1):
		combinations /= maxi(1, n)
	
	if combinations >= MAX_MONTE_CARLO_TESTS:
		print("Running Monte Carlo simulation...")
		sem_MC.post()
	else:
		print("Running brute force algorithm...")
		sem_BF.post()

func answer():
	think_timer.stop()
	
	mutex.lock()
	keep_thinking = false
	mutex.unlock()
	
	await get_tree().create_timer(0.5).timeout
	
	mutex.lock()
	var thread_result = result
	mutex.unlock()
	
	var cards_guessed = Rules.RULES.COMM_CARDS - Netgame.game_state.comm_cards.size()
	cards_guessed += combo_base.filter(func(c): return c & Rules.HIDDEN).size()
	var certainty = clampf((5 - cards_guessed) / 3.0, 0.125, 1)
	
	# If thread found better average score than overall average
	if (high_ball and thread_result[0] > AVERAGE_SCORES[Rules.RULES.CARDS_PER_HAND]) \
	or (not high_ball and thread_result[0] < AVERAGE_SCORES[Rules.RULES.CARDS_PER_HAND]):
		# find place between ovr.avg and max
		var b = inverse_lerp(AVERAGE_SCORES[Rules.RULES.CARDS_PER_HAND], thread_result[1], thread_result[0])
		
		if randf() * certainty < optimism:
			var value = mini(maxi(
				snappedi(Netgame.game_state.pot * (b / 3.0), 5) + player_info.current_bet, 
				Rules.RULES.MIN_BET
			), player_info.chips)
			value += current_max_bet
			
			if value > 0 and player_info.chips > 0:
				answered.emit("RAISE", value)
			else:
				answered.emit("CALL", maxi(current_max_bet - player_info.current_bet, 0))
		else:
			answered.emit("CALL", maxi(current_max_bet - player_info.current_bet, 0))
	# If it didn't
	else:
		if randf() * certainty < optimism:
			answered.emit("CALL", maxi(current_max_bet - player_info.current_bet, 0))
		else:
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
				print("#%d: %s: %.4f (%.4f)" % [combos_evaluated, trial_combo, combo_score, avg_score])
				
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
		
		print("Brute Force complete")
		print(str(result))
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
			print("#%d: %s: %.4f (%.4f)" % [combos_evaluated, combo, combo_score, avg_score])
			
			idx += (cards_to_guess + i)
		
		mutex.lock()
		result = [avg_score, max_score]
		mutex.unlock()
		
		print("Performed %d Monte Carlo iterations" % combos_evaluated)
		print(str(result))
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
		score = -INF
	
	
	for i in hand.cards.size():
		score += float(Rules.get_value(hand.cards[i])) / (i + 1)
	return score

func _exit_tree():
	mutex.lock()
	run_threads = false
	mutex.unlock()
	
	sem_BF.post()
	thread_BF.wait_to_finish()
	
	sem_MC.post()
	thread_MC.wait_to_finish()
