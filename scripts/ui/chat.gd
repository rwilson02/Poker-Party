extends Node

@onready var chat = $MarginContainer/VBoxContainer/RichTextLabel
@onready var textbox = $MarginContainer/VBoxContainer/HBoxContainer/LineEdit
@onready var send_button = $MarginContainer/VBoxContainer/HBoxContainer/Button
var chat_scroll

#const MESSAGE_LIMIT = 50
const REGEX_TEMPLATE = "(player|chat)\\((\\d+)\\)"

var regex: RegEx
var messages = 0
var scroll_val = 0.0

var collapsed = true
var is_moving = false

func _ready():
	regex = RegEx.new()
	regex.compile(REGEX_TEMPLATE)
	
	send_button.pressed.connect(send_chat_message)
	$Panel/TextureButton.pressed.connect(move)
	
	chat_scroll = chat.get_v_scroll_bar()
	chat_scroll.value_changed.connect(func(c): scroll_val = c)

@rpc("any_peer", "call_local", "reliable")
func add_message(msg: String):
	var final_msg = msg
	var matches = regex.search_all(msg)
	var italicize = true
	
	if matches != null:
		for mtch in matches:
			if mtch.get_string(1) == "player":
				var id = int(mtch.get_string(2))
				if Netgame.players.has(id):
					final_msg = final_msg.replace(mtch.get_string(), Netgame.players[id].name)
			elif mtch.get_string(1) == "chat" and mtch.get_start(1) == 0:
				var id = int(mtch.get_string(2))
				final_msg = final_msg.replace(mtch.get_string(), Netgame.players[id].name + ": ")
				italicize = false
	
	var colored_msg = ""
	if italicize:
		final_msg = "[i][color=GRAY]%s[/color][/i]" % final_msg
	elif final_msg.begins_with("%s: " % Netgame.me().name):
		colored_msg = "[color=LIGHT_BLUE]%s[/color]" % final_msg
	
#	if messages >= MESSAGE_LIMIT:
##		print("waoh message limit reached")
#		chat.text = chat.text.split("\n", false, 1)[1]
#		messages -= 1
	
	chat.text += ("%s\n" % final_msg if colored_msg.is_empty() else "%s\n" % colored_msg)
	messages += 1
	
	fake_add_message.rpc("%s\n" % final_msg)
	
	scroll_handling()

@rpc("call_remote", "authority", "reliable")
func fake_add_message(msg: String):
	if msg.begins_with("%s: " % Netgame.me().name):
		msg = "[color=LIGHT_BLUE]%s[/color]" % msg
	
	chat.append_text(msg)
	messages += 1
	scroll_handling()

func send_chat_message():
	if textbox.text.is_empty(): return
	
	var message = "chat(%d) %s" % [multiplayer.get_unique_id(), textbox.text]
	add_message.rpc_id(1, message)
	textbox.clear()

func scroll_handling():
	if chat_scroll.max_value - (chat_scroll.page + scroll_val) <= 10:
		chat.scroll_to_line(chat.get_line_count() - 1)

func move():
	if not is_moving:
		is_moving = true
		
		if textbox.has_focus():
			textbox.release_focus()
		
		var tween1 = create_tween()
		tween1.tween_property(self, "position", self.position + Vector2.UP * (200 if collapsed else -200), 0.5)\
			.set_trans(Tween.TRANS_CUBIC)
		var tween2 = create_tween()
		tween2.tween_property($Panel/TextureButton, "rotation", $Panel/TextureButton.rotation + PI, 0.5)
		await tween1.finished
		
		$Panel/TextureButton.rotation = fmod($Panel/TextureButton.rotation, TAU)
		collapsed = not collapsed
		is_moving = false

func _input(event):
	if textbox.has_focus():
		if event.is_action_pressed("send_message"):
			send_chat_message()
