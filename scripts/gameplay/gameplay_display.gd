extends Node

@onready var HUD_self_text = $Scorebug/RichTextLabel
@onready var comm_card_holder = $CommCards
@onready var card_marker = $CommCards/Marker1

const SELF_TEXT_TEMPLATE = "[center]%s\n[img=24]res://textures/ico_chips.png[/img] %d[/center]"
const UI_CARD = preload("res://scenes/ui/ui_card.tscn")
const CARD_SCALE = Vector2.ONE * 0.4
const HOLDER_BASE_WIDTH = 600

func _ready():
	Netgame.state_updated.connect(update_display)

#@rpc("authority", "call_local", "unreliable", 2)
func update_display():
	# Handle scorebug
	HUD_self_text.text = SELF_TEXT_TEMPLATE % [Netgame.me().name, Netgame.me().chips]
	
	# Handle community cards
	adjust_cards()
	adjust_holder()

func adjust_cards():
	var difference = comm_card_holder.get_child_count() - Rules.RULES["COMM_CARDS"]
	
	while difference != 0:
		if difference > 0:
			comm_card_holder.get_children()[-1].free()
		elif difference < 0:
			comm_card_holder.add_child(card_marker.duplicate())
	
	if Netgame.game_state["comm_cards"].size() == 0: return
	
	var known_comm_cards = Netgame.game_state["comm_cards"].size()
	for id in comm_card_holder.get_child_count():
		var marker = comm_card_holder.get_child(id)
		var card_exists = marker.get_child_count() == 1
		var corresponding_comm_card = Netgame.game_state.comm_cards[id] \
			if id < known_comm_cards else null
		
		# If there's not a card there...
		if not card_exists:
			# ... and there's supposed to be...
			if id < known_comm_cards:
				# ... make it.
				marker.add_child(create_new_card(corresponding_comm_card))
		# But if there is a card there...
		else:
			# ... when there shouldn't be...
			if id >= known_comm_cards:
				# Get rid of it.
				marker.get_child(0).queue_free()
			# If it should be, but it's not right...
			elif marker.get_child(0).get_meta("card") != corresponding_comm_card:
				# Get rid of it,
				marker.get_child(0).queue_free()
				# and put the right one there.
				marker.add_child(create_new_card(corresponding_comm_card))

func adjust_holder():
	var viewport_size = get_viewport().get_visible_rect().size
	
	comm_card_holder.size.x = HOLDER_BASE_WIDTH + (75 * (Rules.RULES["COMM_CARDS"] - 5))
	
	comm_card_holder.position = Vector2i(
		(viewport_size.x - comm_card_holder.size.x) / 2,
		(viewport_size.y - comm_card_holder.size.y) / 2
	)

func create_new_card(card: int):
	var new_card = UI_CARD.instantiate()
	new_card.setup(card)
	new_card.scale = CARD_SCALE
	return new_card
