extends Node

@onready var hud_text = $Scorebug/HUDText
@onready var wager_text = $Scorebug/WagerText
@onready var hole_card_holder = $Scorebug/ClipMask/HoleCards
@onready var comm_card_holder = $CommCards
@onready var card_marker = $CommCards/Marker1

const CHIP_TEMPLATE = "[img=24]res://textures/ico_chips.png[/img] %d"
const UI_CARD = preload("res://scenes/ui/ui_card.tscn")
const CARD_SCALE = Vector2.ONE * 0.4
const HOLDER_BASE_WIDTH = 600

func _ready():
	Netgame.state_updated.connect(update_display)

#@rpc("authority", "call_local", "unreliable", 2)
func update_display():
	# Handle scorebug
	hud_text.text = "[center]%s\n%s[/center]" % [Netgame.me().name, CHIP_TEMPLATE % Netgame.me().chips]
	var betted = Netgame.me().current_bet
	if betted > 0:
		wager_text.visible = true
		wager_text.text = "[center]%s[/center]" % (CHIP_TEMPLATE % betted)
	else: wager_text.visible = false
	
	# Handle pot
	$PotText.text = CHIP_TEMPLATE % Netgame.game_state.pot
	
	# Handle community and hole cards
	adjust_cards()
	adjust_comm_holder()
#	prints(multiplayer.get_unique_id(), "has", Netgame.game_state.comm_cards)

func adjust_cards():
	var comm_difference = comm_card_holder.get_child_count() - Rules.RULES["COMM_CARDS"]
	var hole_difference = hole_card_holder.get_child_count() - Rules.RULES["HOLE_CARDS"]
	
	while comm_difference != 0:
		if comm_difference > 0:
			comm_card_holder.get_children()[-1].get_child(0).free()
		elif comm_difference < 0:
#			comm_card_holder.add_child(card_marker.duplicate())
			comm_card_holder.add_child(comm_card_holder.get_child(0).duplicate())
	while hole_difference != 0:
		if hole_difference > 0:
			hole_card_holder.get_children()[-1].get_child(0).free()
		elif hole_difference < 0:
#			hole_card_holder.add_child(card_marker.duplicate())
			hole_card_holder.add_child(hole_card_holder.get_child(0).duplicate())
	
	if Netgame.game_state["comm_cards"].size() == 0: return
	
	for id in comm_card_holder.get_child_count():
		determine_card("comm", comm_card_holder, id)
	for id in hole_card_holder.get_child_count():
		determine_card("hole", hole_card_holder, id)

func adjust_comm_holder():
	var viewport_size = get_viewport().get_visible_rect().size
	
	comm_card_holder.size.x = HOLDER_BASE_WIDTH + (75 * (Rules.RULES["COMM_CARDS"] - 5))
	
	comm_card_holder.position = Vector2i(
		(viewport_size.x - comm_card_holder.size.x) / 2,
		(viewport_size.y - comm_card_holder.size.y) / 2
	)

func determine_card(flavor: String, holder: Node, id: int):
	var known_cards
	var corresponding_card
	var marker = holder.get_child(id)
	var card_exists = marker.get_child_count() == 1
	
	match flavor:
		"comm":
			known_cards = Netgame.game_state["comm_cards"].size()
			corresponding_card = Netgame.game_state.comm_cards[id] \
				if id < known_cards else null
		"hole":
			var player = Netgame.me()
			known_cards = player["cards"].size()
			corresponding_card = player.cards[id] \
				if id < known_cards else null
	
	# If there's not a card there...
	if not card_exists:
		# ... and there's supposed to be...
		if id < known_cards:
			# ... make it.
			marker.add_child(create_new_card(corresponding_card))
	# But if there is a card there...
	else:
		# ... when there shouldn't be...
		if not corresponding_card and corresponding_card != 0:
			# Get rid of it.
			marker.get_child(0).queue_free()
		# If it should be, but it's not right...
		elif marker.get_child(0).get_meta("card") != corresponding_card:
			# Get rid of it,
			marker.get_child(0).queue_free()
			# and put the right one there.
			marker.add_child(create_new_card(corresponding_card))

func create_new_card(card: int):
	var new_card = UI_CARD.instantiate()
	new_card.setup(card)
	new_card.scale = CARD_SCALE
	return new_card
