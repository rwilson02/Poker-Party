extends Node

@onready var player_display = $LobbyControls/PlayerDisplay/MarginContainer/RichTextLabel
@onready var address_bar = $LobbyControls/Control/PreGame/VBoxContainer/Address
@onready var other_buttons = $LobbyControls/Control/PreGame
@onready var start_button = $LobbyControls/Control/InGame/StartButton
@onready var cancel_button = $LobbyControls/Control/InGame/CancelButton

@onready var name_input = $PlayerSetup/LineEdit

func _ready():
	Netgame.test_player_conditions.connect(update_player_display)
	Netgame.test_player_conditions.connect(test_start)

func test_start(remaining_players):
	start_button.disabled = false if remaining_players >= 2 else true

func update_player_display(_remaining = null):
	var template_string = "%s\n"
	
	player_display.clear()
	if not multiplayer.has_multiplayer_peer(): return
	
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
	name_input.editable = false
	
	Netgame.create_game()
	other_buttons.visible = false
	start_button.visible = true
	cancel_button.visible = true

func on_join_button():
	if not name_input.text.is_empty():
		Netgame.player_info["name"] = name_input.text
	name_input.editable = false
	
	Netgame.join_game(address_bar.text)
	other_buttons.visible = false
	cancel_button.visible = true

func on_cancel_button():
	if multiplayer.is_server():
		Netgame.server_disconnected.emit()
	else:
		Netgame.player_disconnected.emit(multiplayer.get_unique_id())
	multiplayer.multiplayer_peer = null
	update_player_display()
	
	start_button.visible = false
	cancel_button.visible = false
	other_buttons.visible = true
	name_input.editable = true

func on_start_button():
	start_game.rpc()

@rpc("call_local", "reliable")
func start_game():
	get_parent().start_game()
