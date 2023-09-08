extends Node

@onready var hole_selection = $Config/Deck/Hole/SpinBox.get_line_edit()
@onready var comm_selection = $Config/Deck/Comm/SpinBox.get_line_edit()
@onready var hand_selection = $Config/Deck/Hand/SpinBox.get_line_edit()
@onready var suit_selection = $Config/Deck/Suits/SpinBox.get_line_edit()
@onready var vals_selection = $Config/Deck/Values/SpinBox.get_line_edit()
@onready var hand_explainer = $Config/Hand/Label
@onready var hand_input = $Config/Hand/HandInput
@onready var output_box = $Output/TextEdit
var explanation

func _ready():
	explanation = hand_explainer.text

func do_generation_test():
	output_box.clear()
	set_rules()
	
	var deck = range(0, Rules.SUITS * Rules.VALS_PER_SUIT)
	deck.shuffle()
	var pull = Rules.HOLE_CARDS + Rules.COMM_CARDS
	
	var current_line = 0
	while deck.size() >= pull:
		var start_time = Time.get_ticks_msec()
		
		var cards = []
		for i in pull:
			cards.append(deck.pop_back())
		
		var best_hand = Hand.get_best_hand(cards, Rules.CARDS_PER_HAND)
		var end_time = Time.get_ticks_msec() - start_time
		
		if best_hand.rank != "":
			output_box.set_line(current_line, "%s\n" % Rules.hand_to_string(cards))
			output_box.set_line(current_line + 1, "%s\n" % Rules.hand_to_string(best_hand.cards))
			output_box.set_line(current_line + 2, best_hand.get_name() + "\n")
			output_box.set_line(current_line + 3, ("%dms" % end_time) + "\n\n")
	#		output_box.grab_focus()
			current_line += 5
		else:
			output_box.set_line(current_line, "Error (Not enough cards to make a hand)")
	
	Rules.reset()

func do_hand_test():
	output_box.clear()
	
	var invalid = false
	
	var input_cards = hand_input.text.split(" ", false) as Array
	for i in input_cards.size():
		if input_cards[i].is_valid_int():
			input_cards[i] = input_cards[i].to_int()
		else: 
			invalid = true # Something isn't an integer
			break
	
	if invalid:
		output_box.set_line(0, "Error (Noninteger or nonspace in text box)")
		return
	elif input_cards.size() < Rules.CARDS_PER_HAND:
		output_box.set_line(0, "Error (Too few cards to make a hand)")
		return
	elif input_cards.any(func(c): return c >= Rules.SUITS * Rules.VALS_PER_SUIT):
		output_box.set_line(0, "Error (Card index out of range of deck size)")
		return
	
	var best_hand = Hand.get_best_hand(input_cards, Rules.CARDS_PER_HAND)
	
	if best_hand.rank != "":
		output_box.set_line(0, "%s\n" % Rules.hand_to_string(input_cards))
		output_box.set_line(1, "%s\n" % Rules.hand_to_string(best_hand.cards))
		output_box.set_line(2, best_hand.get_name() + "\n")
	
	Rules.reset()

func set_rules():
	Rules.SUITS = suit_selection.text.to_int()
	Rules.VALS_PER_SUIT = vals_selection.text.to_int()
	Rules.HOLE_CARDS = hole_selection.text.to_int()
	Rules.COMM_CARDS = comm_selection.text.to_int()
	Rules.CARDS_PER_HAND = hand_selection.text.to_int()

func on_tab_changed(tab):
	if tab == 1:
		set_rules()
		hand_explainer.text = explanation % (Rules.SUITS * Rules.VALS_PER_SUIT)

func on_quit():
	get_tree().quit()
