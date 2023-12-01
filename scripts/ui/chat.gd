extends Node

@onready var chat = $MarginContainer/RichTextLabel
var chat_scroll

#const MESSAGE_LIMIT = 50
const REGEX_TEMPLATE = "(player|chat)\\((\\d+)\\)"

var regex: RegEx
var messages = 0
var scroll_val = 0.0

func _ready():
	regex = RegEx.new()
	regex.compile(REGEX_TEMPLATE)
	
	chat_scroll = chat.get_v_scroll_bar()
	chat_scroll.value_changed.connect(func(c): scroll_val = c)

func add_message(msg: String):
	var final_msg = msg
	var matches = regex.search_all(msg)
	var italicize = true
	
	if matches != null:
		for mtch in matches:
			if mtch.get_string(1) == "player":
				var id = int(mtch.get_string(2))
				final_msg = final_msg.replace(mtch.get_string(), Netgame.players[id].name)
			elif mtch.get_string(1) == "chat" and mtch.get_start(1) == 0:
				var id = int(mtch.get_string(2))
				final_msg = final_msg.replace(mtch.get_string(), Netgame.players[id].name + ": ")
				italicize = false
	
	if italicize:
		final_msg = "[i]%s[/i]" % final_msg
	
#	if messages >= MESSAGE_LIMIT:
##		print("waoh message limit reached")
#		chat.text = chat.text.split("\n", false, 1)[1]
#		messages -= 1
	
	chat.text += "%s\n" % final_msg
	messages += 1
	
	fake_add_message.rpc("%s\n" % final_msg)
	
	scroll_handling()

@rpc("call_remote", "authority", "reliable")
func fake_add_message(msg):
#	while messages >= MESSAGE_LIMIT:
#		chat.remove_paragraph(0)
#		messages -= 1
	
	chat.append_text(msg)
	messages += 1
	scroll_handling()

func scroll_handling():
	if chat_scroll.max_value - (chat_scroll.page + scroll_val) <= 10:
		chat.scroll_to_line(chat.get_line_count() - 1)
