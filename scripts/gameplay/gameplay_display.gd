extends Node

@onready var HUD_self_text = $Label

const self_text_template = "%s\nChips: %d"

func _ready():
	update_display()

@rpc("authority", "call_local", "unreliable", 1)
func update_display():
	HUD_self_text.text = self_text_template % [Netgame.me().name, Netgame.me().chips]
