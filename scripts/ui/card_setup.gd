extends Node

const COLORS = [Color.BLACK, Color.RED, Color.BLACK, Color.RED, Color.GOLD, Color.GOLD]
const SUITS_PER_ROW = 3
const SUIT_SIZE = 256

func setup(card: int):
	var indices = [$TopLeft, $BottomRight]
	var icons = [$TopLeft/Icon, $BottomRight/Icon]
	var texts = [$TopLeft/Text, $BottomRight/Text]
	
	set_meta("card", card)
	var value = Rules.get_proper_value(card)
	var suit = Rules.get_suit(card)
	
	for i in icons:
		i.texture.region = Rect2i(\
			SUIT_SIZE * (suit % SUITS_PER_ROW), \
			SUIT_SIZE * (suit / SUITS_PER_ROW), \
			SUIT_SIZE, SUIT_SIZE)
	for t in texts:
		t.text = value
	for idx in indices:
		idx.modulate = COLORS[suit]
		
	self.tooltip_text = Rules.get_proper_symbol(card)
