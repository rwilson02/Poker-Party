extends ReferenceRect

@onready var icon = $TextureRect
@onready var overlay = $TextureRect/TextureRect
@onready var text = $RichTextLabel

const TEXT_TEMPLATE = "[center]%s\n%s"
const CHIP_TEMPLATE = "[img=24]res://textures/ico_chips.png[/img] %d"
const CHIP_BET_TEMPLATE = "[img=24]res://textures/ico_chips_bet.png[/img] %d"
const AWAIT_TEMPLATE = "[pulse freq=1.0 color=#ffffff40 ease=-2.0]▶[/pulse] %s"
const BET_TEMPLATE = "%s / %s"
const ICON_ATLAS = preload("res://textures/lobby/icon_atlas.png")
const ICON_SIZE = 256

var id: int = -17160

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

func update(state = null):
	if id == -17160: return
	
	var player = Netgame.players[id]
	var top_line: String
	var bottom_line: String
	
	if state != null:
		var flavor = ["CALL", null, "RAISE", "FOLD"].find(state)
		if flavor == 0:
			flavor += int(player.current_bet > 0)
		if id in Netgame.game_state.folded_players:
			flavor = 3
		if id in Netgame.game_state.losers:
			flavor = 4
		
		overlay.texture.region = Rect2i(Vector2i.RIGHT * ICON_SIZE * flavor, Vector2i.ONE * ICON_SIZE)
	
	if id in Netgame.game_state.losers:
		icon.self_modulate = Color.DIM_GRAY
		overlay.self_modulate = player.color.darkened(0.5) if player.color.get_luminance() > 0.5 \
			else player.color.lightened(0.5)
		bottom_line = "ELIMINATED"
	else:
		icon.self_modulate = player.color
		bottom_line = BET_TEMPLATE % [CHIP_TEMPLATE % player.chips, CHIP_BET_TEMPLATE % player.current_bet] \
			if player.current_bet else CHIP_TEMPLATE % player.chips
		overlay.self_modulate = Color.WHITE
	
	top_line = AWAIT_TEMPLATE % player.name if player.awaiting else player.name
	
	text.text = TEXT_TEMPLATE % [top_line, bottom_line]
