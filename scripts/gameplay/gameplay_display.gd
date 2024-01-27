extends Node

@onready var hud_text = $Scorebug/HUDText
@onready var wager_text = $Scorebug/WagerText
@onready var hole_card_holder = $Scorebug/ClipMask/HoleCards
@onready var comm_card_holder = $CommCards
@onready var change_icons = $ChangeIcons
@onready var showdown_panel = $ShowdownPanel
@onready var chip_zoom = $ChipZoom
@onready var sfxer = $AudioStreamPlayer
@onready var chat = $Chat
@onready var players = $Table/Players

signal done

const CHIP_TEMPLATE = "[img=24]res://textures/ico_chips.png[/img] %d"
const UI_CARD = preload("res://scenes/ui/ui_card.tscn")
const CARD_SCALE = Vector2.ONE * 0.4
const HOLDER_BASE_WIDTH = 600
const ICON_SIZE = 40

var host_timer

func _ready():
	if(multiplayer.get_unique_id() == 1):
		host_timer = Timer.new()
		host_timer.one_shot = false
		host_timer.timeout.connect(update_display)
		add_child(host_timer)
		host_timer.start($MultiplayerSynchronizer.replication_interval)

func update_display():
	# Handle scorebug
	adjust_scorebug()
	
	# Handle pot
	$PotText.text = CHIP_TEMPLATE % Netgame.game_state.pot
	
	# Handle community and hole cards
	adjust_cards()
	adjust_comm_holder()
	if change_icons.get_child_count() != Rules.RULES.CURRENT_CHANGES.size():
		adjust_change_icons()

func adjust_scorebug():
	hud_text.text = "[center]%s\n%s[/center]" % [Netgame.me().name, CHIP_TEMPLATE % Netgame.me().chips]
	var betted = absi(Netgame.me().current_bet)
	if betted > 0:
		wager_text.visible = true
		wager_text.text = "[center]%s[/center]" % (CHIP_TEMPLATE % betted)
	else: wager_text.visible = false

func adjust_cards():
	var comm_difference = comm_card_holder.get_child_count() - Rules.RULES.COMM_CARDS
	var hole_difference = hole_card_holder.get_child_count() - Rules.RULES.HOLE_CARDS
	
	while comm_difference != 0:
		if comm_difference > 0:
			comm_card_holder.get_children()[-1].free()
		elif comm_difference < 0:
			comm_card_holder.add_child(comm_card_holder.get_child(0).duplicate())
		comm_difference = comm_card_holder.get_child_count() - Rules.RULES.COMM_CARDS
	while hole_difference != 0:
		if hole_difference > 0:
			hole_card_holder.get_children()[-1].free()
		elif hole_difference < 0:
			hole_card_holder.add_child(hole_card_holder.get_child(0).duplicate())
		hole_difference = hole_card_holder.get_child_count() - Rules.RULES.HOLE_CARDS
	
	if Netgame.game_state.comm_cards.size() == 0: return
	
	for id in comm_card_holder.get_child_count():
		determine_card("comm", comm_card_holder, id)
	for id in hole_card_holder.get_child_count():
		determine_card("hole", hole_card_holder, id)

func adjust_comm_holder():
	var viewport_size = get_viewport().get_visible_rect().size
	var required_size = HOLDER_BASE_WIDTH + (75 * (Rules.RULES.COMM_CARDS - 5))
	
	if comm_card_holder.size.x == required_size: return
	
	comm_card_holder.size.x = required_size
	
	comm_card_holder.position = Vector2i(
		(viewport_size.x - comm_card_holder.size.x) / 2,
		(viewport_size.y - comm_card_holder.size.y) / 2
	)

@rpc("call_local", "authority", "reliable")
func adjust_change_icons():
	const ICON_TEMPLATE = "res://textures/rule_changes/%s.png"
	var CHANGE_DESCS = Rules.get_changes()
	var CHANGES = Rules.RULES.CURRENT_CHANGES
	
	for child in change_icons.get_children():
		child.free()
	for idx in CHANGES.size():
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2.ONE * ICON_SIZE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture = load(ICON_TEMPLATE % CHANGES[idx])
		icon.self_modulate = Color.INDIAN_RED if "DOWN" in CHANGES[idx] else Color.GREEN_YELLOW
		icon.tooltip_text = CHANGE_DESCS[idx]
		change_icons.add_child(icon)

func determine_card(flavor: String, holder: Node, id: int):
	var known_cards
	var corresponding_card
	var marker = holder.get_child(id)
	var card_exists = marker.get_child_count() > 0
	
	match flavor:
		"comm":
			known_cards = Netgame.game_state.comm_cards.size()
			corresponding_card = Netgame.game_state.comm_cards[id] \
				if id < known_cards else null
		"hole":
			var player = Netgame.me()
			known_cards = player.cards.size()
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
		if corresponding_card == null:
			# Get rid of it.
			for child in marker.get_children():
				child.queue_free()
		# If it should be, but it's not right...
		elif marker.get_child(0).get_meta("card") != corresponding_card:
			# Get rid of it,
			for child in marker.get_children():
				child.queue_free()
			# and put the right one there.
			marker.add_child(create_new_card(corresponding_card))

func create_new_card(card: int):
	var new_card = UI_CARD.instantiate()
	new_card.setup(card)
	
	if card & Rules.HIDDEN: new_card.flip(true)
	
	new_card.scale = CARD_SCALE
	return new_card

@rpc("authority","call_local","reliable")
func display_showdown(results: Array):
	showdown_panel.size = Vector2(50 * Rules.RULES.CARDS_PER_HAND + 50, 400)
	
	var any_flips = false
	for marker in (comm_card_holder.get_children() + hole_card_holder.get_children()):
		if marker.get_child(0).flipped:
			any_flips = true
			marker.get_child(0).flip()
			await get_tree().create_timer(0.5).timeout
	if any_flips:
		await get_tree().create_timer(1).timeout
	
	var showdown_text: RichTextLabel = showdown_panel.find_child("RichTextLabel")
	showdown_text.clear()
	
	for pair in results:
		var id = pair[0]
		var hand = Hand.new(pair[1])
		
		showdown_text.append_text("%s:\n" % Netgame.players[id].name)
		showdown_text.append_text("[b]%s[/b]\n" % Hand.hand_to_string(hand))
		showdown_text.append_text("[i]%s[/i]\n\n" % hand.get_name())
	
	var in_tween = create_tween()
	in_tween.tween_property(showdown_panel, "position", showdown_panel.position + (Vector2.LEFT * 400), 0.5)
	await in_tween.finished
	await get_tree().create_timer(3 + results.size()).timeout
	var out_tween = create_tween()
	out_tween.tween_property(showdown_panel, "position", showdown_panel.position + (Vector2.RIGHT * 400), 0.5)
	
	done.emit()

@rpc("authority", "call_local", "reliable")
func chip_zoom_anim(to_pot: bool):
	var pot_loc = $PotText.get_global_transform_with_canvas().origin + ($PotText.size / 2)
	var wager_loc = wager_text.get_global_transform_with_canvas().origin + (wager_text.size / 2)
	var location_pair
	
	location_pair = [wager_loc, pot_loc] if to_pot else [pot_loc, wager_loc]
	
	chip_zoom.position = location_pair[0]
	chip_zoom.visible = true
	var tween = chip_zoom.create_tween()
	tween.tween_property(chip_zoom, "position", location_pair[1], 0.5)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	sfxer.play()
	await tween.finished
	chip_zoom.visible = false

func log_to_chat(this: String):
	chat.add_message(this)

@rpc("authority", "call_local", "reliable")
func setup_icons(ids):
	var icons = []
	
	$MultiplayerSynchronizer.synchronized.connect(update_display)
	for idx in ids.size():
		var icon = players.get_child(idx)
		icon.setup(ids[idx])
		$MultiplayerSynchronizer.synchronized.connect(icon.update)
		icons.append(icon)
	for child in players.get_children():
		if child.id == -1:
			child.visible = false
	
	if multiplayer.get_unique_id() == 1:
		for i in icons:
			host_timer.timeout.connect(i.update)
