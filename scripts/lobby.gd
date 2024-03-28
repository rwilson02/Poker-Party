extends Node

@onready var player_display = $LobbyControls/LobbyMenu/Players/RichTextLabel
@onready var address_bar = $LobbyControls/Control/PreGame/Joining/Address
@onready var port_input = $LobbyControls/Control/PreGame/Hosting/SpinBox
@onready var options = $LobbyControls/LobbyMenu/Options/ScrollContainer/VBoxContainer
@onready var lobby_controls = $LobbyControls/Control/PreGame
@onready var start_controls = $LobbyControls/Control/InGame
@onready var timer = $Timer
@onready var ai_input = %AIInput

const POKERPEDIA = preload("res://scenes/Pokerpedia.tscn")

@onready var player_inputs = $PlayerSetup/IDCard

func _ready():
	Netgame.test_player_conditions.connect(update_player_display)
	Netgame.test_player_conditions.connect(test_start)
	ai_input.value_changed.connect(test_start)
	Netgame.server_disconnected.connect(server_exploded)
	timer.timeout.connect(timeout)
	Netgame.players.clear()
	Rules.reset()
	$PlayerSetup/VBoxContainer/QuitButton.pressed.connect(func(): get_tree().quit())
	$Background/Logo/Button.pressed.connect(func(): $AnimationPlayer.play("go_to_lobby"))
	
	if not get_parent().first_boot:
		$Background/CurtainL.visible = false
		$Background/CurtainR.visible = false
		$Camera2D.position = Vector2.DOWN * 1440
		player_inputs.show_anim()

func test_start(remaining_players = 1):
	var rem = maxi(remaining_players, Netgame.players.keys().size())
	ai_input.max_value = Netgame.MAX_CONNECTIONS - Netgame.players.keys().filter(func(c): return c > 0).size()
	
	start_controls.get_node("%StartButton").disabled = (rem + ai_input.value) < 2

func update_player_display(_remaining = null):
	var template_string = "%s\n"
	
	player_display.clear()
	if not multiplayer or not multiplayer.has_multiplayer_peer(): return
	
	player_display.push_font_size(20)
	for player_id in Netgame.players:
		if player_id == 1:
			player_display.push_color(Color.GOLD)
			player_display.add_text(template_string % (Netgame.players[player_id].name + " [HOST]"))
			player_display.pop()
		elif player_id == multiplayer.get_unique_id():
			player_display.push_color(Color.LIGHT_BLUE)
			player_display.add_text(template_string % Netgame.players[player_id].name)
			player_display.pop()
		else:
			player_display.add_text(template_string % Netgame.players[player_id].name)
	player_display.pop()

func create_game():
	set_player_info()
	
	var port = port_input.value
	var error = Netgame.create_game(port)
	if not error:
		player_inputs.set_editable(false)
		lobby_controls.visible = false
		start_controls.visible = true
		start_controls.get_node("%StartButton").visible = true
		$LobbyControls/LobbyMenu.tabs_visible = true
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
	set_player_info()
	
	var error
	if ":" in address_bar.text:
		var address_pieces = address_bar.text.split(":")
		error = Netgame.join_game(address_pieces[0], address_pieces[1])
	else:
		error = Netgame.join_game(address_bar.text)
	
	if not error:
		player_inputs.set_editable(false)
		lobby_controls.visible = false
		start_controls.visible = true
		start_controls.get_node("StartButton").visible = false
		
		player_display.clear()
		player_display.append_text("...")
		timer.start(5)
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
	player_inputs.set_editable(true)
	$LobbyControls/LobbyMenu.tabs_visible = false

func set_player_info():
	Netgame.player_info.name = player_inputs.get_player_name()
	Netgame.player_info.color = player_inputs.get_player_color()
	Netgame.player_info.icon = player_inputs.get_player_icon()

func on_start_button():
	set_lobby_rules()
	Rules.num_ai = ai_input.value
	start_game.rpc()

@rpc("call_local", "reliable")
func start_game():
	get_parent().start_game()

func server_exploded():
	var is_server = multiplayer.has_multiplayer_peer() and multiplayer.is_server()
	Netgame.players.clear()
	multiplayer.multiplayer_peer = null
	timer.stop()
	
	start_controls.visible = false
	lobby_controls.visible = true
	player_inputs.set_editable(true)
	
	player_display.clear()
	if not is_server:
		player_display.push_color(Color.RED)
		player_display.append_text("Server closed!")
		player_display.pop()

func timeout():
	if not Netgame.players.has(1):
		player_display.clear()
		multiplayer.multiplayer_peer = null
		player_display.push_color(Color.DARK_GRAY)
		player_display.append_text("Nobody's hosting at this address right now.")
		lobby_controls.visible = true
		start_controls.visible = false
		player_inputs.set_editable(true)

func set_lobby_rules():
	for possible_rule in options.get_children():
		if possible_rule is HBoxContainer:
			var rule_name = possible_rule.name
			var valid_change = get_rule_change(rule_name)
			var value
			
			if rule_name in Rules.RULES:
				var possible_value = possible_rule.get_child(1)
				
				if possible_value is SpinBox:
					value = possible_rule.get_node("SpinBox").value as int
					var val_diff = (value - Rules.RULES[rule_name]) / possible_rule.get_node("SpinBox").step
				
					if val_diff != 0 and not valid_change.is_empty():
						var modifier = "UP" if signi(val_diff) == 1 else "DOWN"
						var change = "%s_%s" % [valid_change, modifier]
						
						for i in absi(val_diff):
							Rules.add_change(change)
				elif possible_value is OptionButton:
					if rule_name == "BALL" and possible_value.selected > 0:
						value = -1
						Rules.add_change("BALL_FLIP")
				
				Rules.set_rule(rule_name, value)

func get_rule_change(rule_name):
	var change_file = FileAccess.open("res://rules/change_info.txt", FileAccess.READ)
	while not change_file.eof_reached():
		var line = change_file.get_csv_line()
		if rule_name in line:
			return line[0].get_slice("_", 0)
	return ""

func show_how_to_play():
	add_child(POKERPEDIA.instantiate())
