extends Node

signal animation_complete
signal get_out
signal okay_continue
signal do_it_again(with_restart)
signal request_restart

@onready var shade = $Shade
@onready var rule_changer = $RuleChange
@onready var end_screen = $End
@onready var pause = $Pause

var paused = false
var pause_tween

func _ready():
	rule_changer.option_selected.connect(hide_rule_changer)
	rule_changer.option_selected.connect(func(value): self.done_here.rpc_id(1, value))
	
	if multiplayer.is_server():
		Netgame.player_disconnected.connect(begone_thot)
		end_screen.get_node("HBoxContainer/RestartButton").visible = true
		end_screen.get_node("HBoxContainer/RestartButton").pressed.connect(func(): do_it_again.emit(true))
		end_screen.get_node("HBoxContainer/ContinueButton").visible = true
		end_screen.get_node("HBoxContainer/ContinueButton").pressed.connect(func(): do_it_again.emit(false))
		var pause_restart: Button = pause.get_node("%Restart")
		pause_restart.visible = true
		pause_restart.pressed.connect(
			func(): 
				request_restart.emit()
				pause_restart.text = "AWAITING..."
				pause_restart.disabled = true
		)
	
	end_screen.get_node("HBoxContainer/ExitButton").pressed.connect(okay_get_out)
	pause.get_node("%Exit").pressed.connect(okay_get_out)

func _input(event):
	if event is InputEventKey:
		if event.key_label == KEY_ESCAPE and event.is_pressed():
			toggle_pause()

func toggle_shadow():
	var tween = create_tween()
	
	if shade.visible:
		tween.tween_property(shade, "modulate", Color.hex(0xFFFFFF00), 0.25)
		await tween.finished
		shade.visible = false
		animation_complete.emit()
	else:
		shade.visible = true
		tween.tween_property(shade, "modulate", Color.hex(0xFFFFFFFF), 0.5)
		await tween.finished
		animation_complete.emit()

@rpc("authority", "call_local", "reliable")
func show_rule_changer():
	rule_changer.setup_menu()
	toggle_shadow()
	await animation_complete
	rule_changer.position = screen_center(rule_changer) + (Vector2.UP * 720)
	if not rule_changer.visible: rule_changer.visible = true
	var tween = create_tween()
	tween.tween_property(rule_changer, "position", screen_center(rule_changer), 1)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func hide_rule_changer(_value):
	var tween = create_tween()
	tween.tween_property(rule_changer, "position", screen_center(rule_changer) + (Vector2.DOWN * 720), 0.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	if rule_changer.visible: rule_changer.visible = false
	toggle_shadow()
	await animation_complete

@rpc("any_peer","call_local","reliable")
func done_here(valid):
	okay_continue.emit(valid)

func begone_thot(id):
	prints(id, "gone")
	if Netgame.players[id].awaiting and id in Netgame.game_state.losers:
		done_here(false)

@rpc("authority", "call_local", "reliable")
func show_end_screen():
	const TEMPLATE = "[center][font_size=24]🥇 %s[/font_size]\n🥈 %s"
	const THIRD = "\n🥉 %s"
	
	var players = []
	
	var get_player_name = func(id: int):
		return Netgame.players[id].name
	
	players.append(get_player_name.call(Netgame.game_state.active_players[0]))
	players.append(get_player_name.call(Netgame.game_state.losers[-1]))
	
	var end_text = TEMPLATE % [players[0], players[1]]
	if Netgame.game_state.losers.size() >= 2:
		end_text += THIRD % get_player_name.call(Netgame.game_state.losers[-2])
	end_screen.get_node("Ranking").text = end_text
	
	toggle_shadow()
	await animation_complete
	if Netgame.game_state.active_players.has(multiplayer.get_unique_id()):
		end_screen.get_node("BigText").text = "YOU WIN"
	if multiplayer.is_server():
		end_screen.get_node("Message").text = "You decide what's next!"
	else:
		end_screen.get_node("Message").text = "Waiting for the host's decision..."
		
	
	var tween = create_tween()
	tween.tween_property(end_screen, "position", screen_center(end_screen), 1).set_trans(Tween.TRANS_BOUNCE)

@rpc("authority", "call_local", "reliable")
func hide_end_screen():
	if end_screen.position.y > 0:
		var tween = create_tween()
		tween.tween_property(end_screen, "position", screen_center(end_screen) + (Vector2.DOWN * 720), 0.5)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await tween.finished
		end_screen.position = screen_center(end_screen) + (Vector2.UP * 720)
		toggle_shadow()
		await animation_complete

func toggle_pause():
	if pause_tween == null:
		var dir = Vector2.LEFT if paused else Vector2.RIGHT
		#if paused:
			#dir = Vector2.LEFT
		#else:
			#dir = Vector2.RIGHT
		pause_tween = create_tween()
		pause_tween.tween_property(pause, "position", pause.position + (400 * dir), 0.5).set_ease(Tween.EASE_OUT)
		await pause_tween.finished
		paused = not paused
		pause_tween = null

func okay_get_out():
	if multiplayer:
		multiplayer.multiplayer_peer = null
	get_out.emit()

func screen_center(node: Node):
	return (Vector2(get_tree().root.content_scale_size) - node.size) / 2.0
