extends Node

@export var auto: bool
@export var flipped: bool

const FLIP_TIME: float = 0.8

func _ready():
	if auto:
		var value = get_meta("card")
		if value < Rules.RULES.SUITS * Rules.RULES.VALS_PER_SUIT: setup(value)

func _make_custom_tooltip(for_text: String):
	var tooltip = RichTextLabel.new()
	tooltip.text = "[color=WHITE]%s[/color]" % for_text if not flipped else "???"
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
	
	for i in icons:
		i.texture.region = Rules.get_suit_loc(suit)
	for t in texts:
		t.text = value
	for idx in indices:
		idx.modulate = Rules.SUIT_COLORS[suit] if not wild else Color.BLACK
		
	self.tooltip_text = Rules.get_card_string(card)
	
	if flipped: $Back.visible = true

func flip(instant = false):
	if instant:
		flipped = not flipped
		$Back.visible = flipped
	else:
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2(0, 1), FLIP_TIME / 2)\
			.set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN)
		tween.tween_property(self, "flipped", not flipped, 0)
		tween.tween_property($Back, "visible", not flipped, 0)
		tween.tween_property(self, "scale", Vector2.ONE, FLIP_TIME / 2)\
			.set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
