extends ReferenceRect

@onready var icon = $TextureRect
@onready var text = $RichTextLabel

const TEXT_TEMPLATE = "[center]%s\n%s"
const CHIP_TEMPLATE = "[img=24]res://textures/ico_chips.png[/img] %d"
const AWAIT_TEMPLATE = "[pulse freq=1.0 color=#ffffff40 ease=-2.0]▶[/pulse] %s"
const BET_TEMPLATE = "%s / %s"
const ICON_ATLAS = preload("res://textures/lobby/icon_atlas.png")
const ICON_SIZE = 256

var id: int = -1

func setup(this_player: int):
	id = this_player
	
	var icons_per_row = ICON_ATLAS.get_width() / ICON_SIZE
	var pos = Vector2(Netgame.players[id].icon % icons_per_row, Netgame.players[id].icon / icons_per_row)
	var new_region = Rect2(pos * ICON_SIZE, Vector2.ONE * ICON_SIZE)
	if icon.texture.region != new_region:
		icon.texture.region = new_region
	
	if position.y >= get_viewport().get_visible_rect().size.y / 2:
		text.position = Vector2.ZERO
		icon.position = Vector2.DOWN * text.size.y
	
	update()

func update():
	var player = Netgame.players[id]
	icon.modulate = player.color if not id in Netgame.game_state.losers else Color.DIM_GRAY
	var top_line = AWAIT_TEMPLATE % player.name if player.awaiting else player.name
	var bottom_line = BET_TEMPLATE % [CHIP_TEMPLATE % player.chips, CHIP_TEMPLATE % player.current_bet] \
		if player.current_bet else CHIP_TEMPLATE % player.chips
	
	text.text = TEXT_TEMPLATE % [top_line, bottom_line]
