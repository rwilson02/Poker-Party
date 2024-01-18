extends Node

@export var auto: bool
@export var flipped: bool

const FLIP_TIME: float = 0.8
const JACKS = preload("res://textures/cards/jack_atlas.png")
const QUEENS = preload("res://textures/cards/queen_atlas.png")
const KINGS = preload("res://textures/cards/king_atlas.png")
const FACE_ART_SIZE = Vector2i(210, 322)

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
#	var icons = [$TopLeft/Icon, $BottomRight/Icon]
#	var texts = [$TopLeft/Text, $BottomRight/Text]
	var face = $FaceArt
	
	set_meta("card", card)
	var value = Rules.get_proper_value(card)
	var suit = Rules.get_suit(card)
	var wild = value == "??"
	var color = Rules.SUIT_COLORS[suit] if not wild else Color.BLACK
	
#	for i in icons:
#		i.texture.region = Rules.get_suit_loc(suit)
#	for t in texts:
#		t.text = value
	for idx in indices:
		idx.modulate = color
		idx.get_node("Icon").texture.region = Rules.get_suit_loc(suit)
		idx.get_node("Text").text = value
	face.modulate = color
	
	var face_card = "JQK".find(value)
	if face_card > -1:
#		var atlas = [JACKS, QUEENS, KINGS]
		face.texture.atlas = [JACKS, QUEENS, KINGS][face_card]
		face.texture.region = Rect2(Vector2.RIGHT * FACE_ART_SIZE.x * (suit + 1), FACE_ART_SIZE)
	
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
