extends Node

@onready var player_display = $LobbyControls/PlayerDisplay/MarginContainer/RichTextLabel
@onready var address_bar = $LobbyControls/Control/PreGame/VBoxContainer/Address
@onready var lobby_controls = $LobbyControls/Control/PreGame
@onready var start_controls = $LobbyControls/Control/InGame

@onready var name_input = $PlayerSetup/LineEdit

func _ready():
	Netgame.test_player_conditions.connect(update_player_display)
	Netgame.test_player_conditions.connect(test_start)
	Netgame.server_disconnected.connect(server_exploded)
	Netgame.upnp_complete.connect(did_it_work)
	Netgame.players.clear()

func test_start(remaining_players):
	start_controls.get_node("StartButton").disabled = false if remaining_players >= 2 else true

func update_player_display(_remaining = null):
	var template_string = "%s\n"
	
	player_display.clear()
	if not multiplayer or not multiplayer.has_multiplayer_peer(): return
	
	player_display.push_font_size(20)
	for player_id in Netgame.players:
		if player_id == 1:
			player_display.push_color(Color.GOLD)
			player_display.add_text(template_string % Netgame.players[player_id].name)
			player_display.pop()
		elif player_id == multiplayer.get_unique_id():
			player_display.push_color(Color.LIGHT_BLUE)
			player_display.add_text(template_string % Netgame.players[player_id].name)
			player_display.pop()
		else:
			player_display.add_text(template_string % Netgame.players[player_id].name)
	player_display.pop()

func create_game():
	if not name_input.text.is_empty():
		Netgame.player_info["name"] = name_input.text
	
	var error = Netgame.create_game()
	if not error:
		name_input.editable = false
		lobby_controls.visible = false
		start_controls.visible = true
		start_controls.get_node("StartButton").visible = true
	else:
		player_display.clear()
		player_display.push_color(Color.RED)
		match error:
			ERR_CANT_CREATE:
				player_display.append_text("ERROR: Can't create lobby.")
			_:
				player_display.append_text("Not sure what the issue is: %s" % error)
		player_display.pop()

func on_join_button():
	if not name_input.text.is_empty():
		Netgame.player_info["name"] = name_input.text
	
	var error = Netgame.join_game(address_bar.text)
	if not error:
		name_input.editable = false
		lobby_controls.visible = false
		start_controls.visible = true
		start_controls.get_node("StartButton").visible = false
		
		player_display.clear()
		player_display.append_text("...")
		await get_tree().create_timer(0.1).timeout
		if not Netgame.players.has(1):
			player_display.clear()
			player_display.push_italics()
			player_display.push_color(Color.DARK_GRAY)
			player_display.append_text("Nobody seems to be hosting yet...\n")
			player_display.append_text("But you'll automatically join once they do.")
			player_display.pop()
			player_display.pop()
	else:
		print(error)

func on_cancel_button():
	if multiplayer.is_server():
		Netgame.server_disconnected.emit()
	else:
		Netgame.player_disconnected.emit(multiplayer.get_unique_id())
		Netgame.players.clear()
	multiplayer.multiplayer_peer = null
	update_player_display()

	start_controls.visible = false
	lobby_controls.visible = true
	name_input.editable = true

func on_start_button():
	start_game.rpc()

@rpc("call_local", "reliable")
func start_game():
	get_parent().start_game()

func server_exploded():
	var is_server = multiplayer.is_server()
	Netgame.players.clear()
	multiplayer.multiplayer_peer = null
	
	start_controls.visible = false
	lobby_controls.visible = true
	name_input.editable = true
	
	player_display.clear()
	if not is_server:
		player_display.push_color(Color.RED)
		player_display.append_text("Server closed!")
		player_display.pop()

func did_it_work(notif):
	player_display.clear()
	if notif == OK:
		player_display.append_text("UPNP OK!")
	else:
		player_display.push_color(Color.RED)
		player_display.append_text("UPNP error: %s" % str(notif))
		player_display.pop()
	
