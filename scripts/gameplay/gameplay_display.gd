extends Node

@onready var HUD_self_text = $Scorebug/RichTextLabel

const self_text_template = "[center]%s\nChips: %d[/center]"

func _ready():
	Netgame.state_updated.connect(update_display)

#@rpc("authority", "call_local", "unreliable", 2)
func update_display():
	HUD_self_text.text = self_text_template % [Netgame.me().name, Netgame.me().chips]
