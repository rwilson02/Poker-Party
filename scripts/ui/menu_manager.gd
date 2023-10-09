extends Node

signal animation_complete
signal get_out
signal okay_continue

@onready var shade = $Shade
@onready var rule_changer = $RuleChange
@onready var end_screen = $End

func _ready():
	rule_changer.option_selected.connect(hide_rule_changer)
	rule_changer.option_selected.connect(func(): self.done_here.rpc_id(1))
	end_screen.get_node("Button").pressed.connect(okay_get_out)

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

func hide_rule_changer():
	var tween = create_tween()
	tween.tween_property(rule_changer, "position", screen_center(rule_changer) + (Vector2.DOWN * 720), 0.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	if rule_changer.visible: rule_changer.visible = false
	toggle_shadow()
	await animation_complete

@rpc("any_peer","call_local","reliable")
func done_here():
	okay_continue.emit()

@rpc("authority", "call_local", "reliable")
func show_end_screen():
	toggle_shadow()
	await animation_complete
	if Netgame.game_state["active_players"].has(multiplayer.get_unique_id()):
		end_screen.get_node("Label").text = "YOU WIN"
	var tween = create_tween()
	tween.tween_property(end_screen, "position", screen_center(end_screen), 1).set_trans(Tween.TRANS_BOUNCE)

func okay_get_out():
	multiplayer.multiplayer_peer = null
	get_out.emit()

func screen_center(node: Node):
	return (Vector2(get_tree().root.content_scale_size) - node.size) / 2.0
