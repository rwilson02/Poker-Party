extends Node

@onready var player_display = $PlayerDisplay/MarginContainer/RichTextLabel
@onready var address_bar = $Control/HBoxContainer/VBoxContainer/Address
@onready var other_buttons = $Control/HBoxContainer
@onready var start_button = $Control/HostButton
@onready var leave_button = $Control/PlayerButton

func _ready():
	Netgame.player_connected.connect(update_player_display)
	Netgame.player_disconnected.connect(update_player_display)

func test_start():
	start_button.disabled = false if Netgame.players.keys().size() >= 2 else true

func update_player_display(_id = null, _info = null):
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

func on_join_button():
	Netgame.join_game(address_bar.text)

func on_leave_button():
	Netgame.player_disconnected.emit(multiplayer.get_unique_id())
	multiplayer.multiplayer_peer = null
	update_player_display()
	
	leave_button.visible = false
	other_buttons.visible = true

func on_start_button():
	start_game.rpc()

@rpc("call_local", "reliable")
func start_game():
	get_parent().start_game()
