extends Panel

@onready var player_name = %PlayerName

@export var main_color: Color

# Called when the node enters the scene tree for the first time.
func _ready():
	player_name.text_changed.connect(func(c): $BottomRight/Label.text = c)
	
	var init_suit_rect = Rect2(0, 0, 256, 256)
	for c in get_children():
		if c is TextureRect:
			c.texture.region = init_suit_rect
	
	color_all_children(self, main_color)

func get_player_name(): 
	return player_name.text if not player_name.text.is_empty() else "Player"

func set_editable(can_edit: bool):
	player_name.editable = can_edit

func color_all_children(node: Node, color: Color):
	for c in node.get_children():
		if c.get_child_count() > 0:
			color_all_children(c, color)
		
		c.self_modulate = color
