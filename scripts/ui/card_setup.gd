extends Node

const COLORS = [Color.BLACK, Color.RED, Color.BLACK, Color.RED, Color.GOLD, Color.GOLD]

func setup(card: int):
	var indices = [$TopLeft, $BottomRight]
	var icons = [$TopLeft/Icon, $BottomRight/Icon]
	var texts = [$TopLeft/Text, $BottomRight/Text]
	
	set_meta("card", card)
	var value = Rules.get_proper_value(card)
	var suit = Rules.get_suit(card)
	
	for i in icons:
#		i.texture.region.x = 256 * (suit % 3)
#		i.texture.region.y = 256 * (suit / 3)
		i.texture.region = Rect2i(256 * (suit % 3), 256 * (suit / 3), 256, 256)
	for t in texts:
		t.text = value
	for idx in indices:
		idx.modulate = COLORS[suit]
