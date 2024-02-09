extends Node

var listening_button = null
var prior_text = ""

func _ready():
	var config = ConfigFile.new()
	var err = config.load("user://config.cfg")
	if not err:
		%MusicSlider.value = config.get_value("settings", "music_vol", 1)
		%SFXSlider.value = config.get_value("settings", "sfx_vol", 1)
		
		%CheckHotkey.text = config.get_value("settings", "check_ctrl", InputMap.action_get_events("check_call")[0])
		%BetHotkey.text = config.get_value("settings", "bet_ctrl", InputMap.action_get_events("bet_raise")[0])
		%FoldHotkey.text = config.get_value("settings", "fold_ctrl", InputMap.action_get_events("fold")[0])
	
	%CheckHotkey.pressed.connect(start_listening.bind(%CheckHotkey))
	%BetHotkey.pressed.connect(start_listening.bind(%BetHotkey))
	%FoldHotkey.pressed.connect(start_listening.bind(%FoldHotkey))

func _exit_tree():
	if not OS.has_feature("editor"):
		var config = ConfigFile.new()
		var err = config.load("user://config.cfg")
		if not err:
			config.set_value("settings", "music_vol", %MusicSlider.value)
			config.set_value("settings", "sfx_vol", %SFXSlider.value)
			
			config.set_value("settings", "check_ctrl", OS.find_keycode_from_string(%CheckHotkey.text))
			config.set_value("settings", "bet_ctrl", OS.find_keycode_from_string(%BetHotkey.text))
			config.set_value("settings", "fold_ctrl", OS.find_keycode_from_string(%FoldHotkey.text))
	
	get_tree().get_root().get_node("Main").settings_changed.emit()

func _input(event):
	if listening_button != null:
		if event is InputEventKey:
			if event.keycode == KEY_ESCAPE:
				stop_listening(false)
			else:
				# TODO: figure out how to make this work when you hold down modifier keys (e.g. CTRL-V)
				listening_button.text = OS.get_keycode_string(event.get_keycode_with_modifiers())
				change_control(listening_button.get_meta("action"), event)
				stop_listening(true)

func start_listening(who):
	if who is BaseButton:
		listening_button = who
		prior_text = who.text
		who.text = "ESC to cancel"

func stop_listening(success: bool):
	if not success:
		listening_button.text = prior_text
	prior_text = ""
	listening_button = null

func change_control(which: String, event):
	if InputMap.has_action(which):
		InputMap.action_erase_events(which)
		InputMap.action_add_event(which, event)
