extends Node

@export var change: String

const CHANGE_INFO_PATH = "res://rules/change_info.txt"
const TEXT_TEMPLATE = "[font_size=24]%s[/font_size]\n%s\n[i][font_size=12]%s[/font_size][/i]"

# Called when the node enters the scene tree for the first time.
func _ready():
	var raw_info = RuleChanger.get_option_information(change)
	var info = RuleChanger.get_info_dict(raw_info)
	
	$Icon.texture = load("res://textures/rule_changes/%s.png" % info.ICON)
	
	var desc: String = info.DESC % info.VALUE if info.FORMATTED else info.DESC
	desc = desc.replace("GREEN", "DARK_GREEN")
	
	var tags = []
	
	if change.ends_with("FLIP"):
		tags.append("Toggle")
	else:
		var v = RuleChanger.CHANGES[change]
		
		if v < RuleChanger.ONE_TIME_CHANGES:
			tags.append("One-shot")
		elif v < RuleChanger.TWO_TIME_CHANGES:
			tags.append("Applies once")
		elif v < RuleChanger.DEPENDENT_CHANGES:
			tags.append("Applies twice")
		else:
			tags.append("Dependent")
	
	if change.get_slice("_", 0) in ["HOLE", "COMM", "HAND", "SUITS", "CARDS"]:
		tags.append("Scales with player count")
	
	%Text.text = TEXT_TEMPLATE % [info.TITLE, desc, ", ".join(tags)]
