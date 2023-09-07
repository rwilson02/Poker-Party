extends Node

@onready var hole_selection = $"Config/VBoxContainer/Hole/SpinBox".get_line_edit()
@onready var comm_selection = $"Config/VBoxContainer/Comm/SpinBox".get_line_edit()
@onready var hand_selection = $"Config/VBoxContainer/Hand/SpinBox".get_line_edit()
@onready var suit_selection = $"Config/VBoxContainer/Suits/SpinBox".get_line_edit()
@onready var vals_selection = $"Config/VBoxContainer/Values/SpinBox".get_line_edit()
@onready var output_box = $Output/TextEdit

func do_generation_test():
	output_box.clear()
	
	Rules.SUITS = suit_selection.text.to_int()
	Rules.VALS_PER_SUIT = vals_selection.text.to_int()
	Rules.HOLE_CARDS = hole_selection.text.to_int()
	Rules.COMM_CARDS = comm_selection.text.to_int()
	Rules.CARDS_PER_HAND = hand_selection.text.to_int()
	
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
