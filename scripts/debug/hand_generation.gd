extends Node

@onready var game_selection = $Config/Deck/Gametype/SpinBox
@onready var hole_selection = $Config/Deck/Hole/SpinBox.get_line_edit()
@onready var comm_selection = $Config/Deck/Comm/SpinBox.get_line_edit()
@onready var hand_selection = $Config/Deck/Hand/SpinBox.get_line_edit()
@onready var suit_selection = $Config/Deck/Suits/SpinBox.get_line_edit()
@onready var vals_selection = $Config/Deck/Values/SpinBox.get_line_edit()
@onready var wilds_selection = $Config/Deck/Wilds/SpinBox.get_line_edit()
@onready var hand_explainer = $Config/Hand/Label
@onready var hand_input = $Config/Hand/HandInput
@onready var output_box = $Output/TextEdit
var explanation

func _ready():
	explanation = hand_explainer.text

func do_generation_test():
	output_box.clear()
	set_rules()
	
	var deck = range(0, Rules.get_deck_size())
	for i in Rules.RULES.SUITS * Rules.RULES.WILDS:
		deck.append(Rules.FREE_WILD)
	deck.shuffle()
	var pull = Rules.RULES.HOLE_CARDS + Rules.RULES.COMM_CARDS
	
	var current_line = 0
	while deck.size() >= pull:
		var start_time = Time.get_ticks_msec()
		
		var cards = []
		for i in pull:
			cards.append(deck.pop_back())
		
		var best_hand = Hand.get_best_hand(cards)
		var end_time = Time.get_ticks_msec() - start_time
		
		if best_hand.rank != "":
			output_box.append_text("%s\n" % Hand.hand_to_string(cards))
			output_box.append_text("%s\n" % Hand.hand_to_string(best_hand.cards))
			output_box.append_text(best_hand.get_name() + "\n")
			output_box.append_text(("%dms" % end_time) + "\n\n")
	#		output_box.grab_focus()
			current_line += 5
		else:
			output_box.append_text("Error (Not enough cards to make a hand)")
	
#	output_box.scroll_vertical = 0
	Rules.reset(true)

func do_hand_test():
	output_box.clear()
	set_rules()
	
	var invalid = false
	
	var input_cards = hand_input.text.split(" ", false) as Array
	for i in input_cards.size():
		if input_cards[i].is_valid_int():
			input_cards[i] = input_cards[i].to_int()
		elif input_cards[i] == "?":
			input_cards[i] = Rules.FREE_WILD
		else:
			invalid = true # Something isn't an integer
			break
	
	if invalid:
		output_box.append_text("Error (Noninteger or nonspace in text box)")
		return
	elif input_cards.size() < Rules.RULES.CARDS_PER_HAND:
		output_box.append_text("Error (Too few cards to make a hand)")
		return
	elif input_cards.any(func(c): return c >= Rules.get_deck_size() and not c & Rules.FREE_WILD):
		output_box.append_text("Error (Card index out of range of deck size)")
		return
	
	var best_hand = Hand.get_best_hand(input_cards)
	
	if best_hand.rank != "":
		output_box.append_text("%s\n" % Hand.hand_to_string(input_cards))
		output_box.append_text("%s\n" % Hand.hand_to_string(best_hand.cards))
		output_box.append_text(best_hand.get_name() + "\n")
	
	Rules.reset(true)

func set_rules():
	Rules.set_rule("BALL", 1 - game_selection.get_selected_id())
	Rules.set_rule("SUITS", suit_selection.text.to_int())
	Rules.set_rule("VALS_PER_SUIT", vals_selection.text.to_int())
	Rules.set_rule("HOLE_CARDS", hole_selection.text.to_int())
	Rules.set_rule("COMM_CARDS", comm_selection.text.to_int())
	Rules.set_rule("CARDS_PER_HAND", hand_selection.text.to_int())
	Rules.set_rule("WILDS", wilds_selection.text.to_int())

func on_tab_changed(tab):
	if tab == 1:
		set_rules()
		hand_explainer.text = explanation % (Rules.get_deck_size())

func on_quit():
	get_tree().quit()
