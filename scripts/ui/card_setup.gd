extends Node

# Spades, Hearts, Clubs, Diamonds, Stars, Moons
#const COLORS = [Color.BLACK, Color.RED, Color.BLACK, Color.RED, Color.DARK_MAGENTA, Color.DARK_MAGENTA]
const SUITS_PER_ROW = 4
const ROWS = 2
const SUIT_SIZE = 256

@export var auto: bool

func _ready():
	if auto:
		var value = get_meta("card")
		if value < Rules.RULES.SUITS * Rules.RULES.VALS_PER_SUIT: setup(value)

func _make_custom_tooltip(for_text: String):
	var tooltip = RichTextLabel.new()
	tooltip.text = "[color=WHITE]%s[/color]" % for_text
	tooltip.bbcode_enabled = true
	tooltip.fit_content = true
	tooltip.autowrap_mode = TextServer.AUTOWRAP_OFF
	return tooltip

func setup(card: int):
	var indices = [$TopLeft, $BottomRight]
	var icons = [$TopLeft/Icon, $BottomRight/Icon]
	var texts = [$TopLeft/Text, $BottomRight/Text]
	
	set_meta("card", card)
	var value = Rules.get_proper_value(card)
	var suit = Rules.get_suit(card)
	var wild = value == "??"
	
#	var POS = Vector2(suit % SUITS_PER_ROW, suit / SUITS_PER_ROW) \
#		if not wild else Vector2(SUITS_PER_ROW - 1, ROWS - 1)
#	var SIZE = Vector2.ONE * SUIT_SIZE
	
	for i in icons:
		i.texture.region = Rules.get_suit_loc(suit)
	for t in texts:
		t.text = value
	for idx in indices:
		idx.modulate = Rules.SUIT_COLORS[suit] if not wild else Color.BLACK
		
	self.tooltip_text = Rules.get_card_string(card)
