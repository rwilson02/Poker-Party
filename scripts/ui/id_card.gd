extends Panel

@onready var player_name = %PlayerName
@onready var ICON_COLUMNS = ICON_ATLAS.get_width() / ICON_SIZE

@export var main_color: Color

var config: ConfigFile
var selected_icon: int
const CONFIG_PATH = "user://config.cfg"
const ICON_ATLAS = preload("res://textures/lobby/icon_atlas.png")
const ICON_SIZE = 256

# Called when the node enters the scene tree for the first time.
func _ready():
	player_name.text_changed.connect(func(c): $BottomRight/Label.text = c)
	$ColorPickerButton.color_changed.connect(func(c): color_all_children(self, c))
	$HBoxContainer/FwdButton.pressed.connect(func(): diff_icon(1))
	$HBoxContainer/BackButton.pressed.connect(func(): diff_icon(-1))
	
	var picker: ColorPicker = $ColorPickerButton.get_picker()
	picker.presets_visible = false
	
	config = ConfigFile.new()
	var err = config.load(CONFIG_PATH)
	if not err:
		player_name.text = config.get_value("cosmetic", "name", "")
		player_name.text_changed.emit(player_name.text)
		main_color = config.get_value("cosmetic", "color", Color.SLATE_BLUE.darkened(0.2))
		selected_icon = config.get_value("cosmetic", "icon", 0)
	
	change_icon(selected_icon)
	color_all_children(self, main_color)
	$ColorPickerButton.color = main_color

func get_player_name(): 
	return player_name.text if not player_name.text.is_empty() else "Player"
func get_player_color(): return $ColorPickerButton.color
func get_player_icon(): return selected_icon

func set_editable(can_edit: bool):
	player_name.editable = can_edit
	$HBoxContainer/FwdButton.disabled = not can_edit
	$HBoxContainer/BackButton.disabled = not can_edit

func color_all_children(node: Node, color: Color):
	for c in node.get_children():
		if c.get_child_count() > 0:
			color_all_children(c, color)
		
		if not c.name.contains("Color"):
			c.self_modulate = color

func diff_icon(dir: int):
	selected_icon = wrapi(selected_icon + dir, 0, ICON_COLUMNS * (ICON_ATLAS.get_height() / ICON_SIZE))
	change_icon(selected_icon)
func change_icon(icon):
	var pos = Vector2(icon % ICON_COLUMNS, icon / ICON_COLUMNS)
	var region = Rect2(pos * ICON_SIZE, Vector2.ONE * ICON_SIZE)
	
	for c in get_children():
		if c is TextureRect:
			c.texture.region = region

func _exit_tree():
	if not OS.has_feature("editor"):
		config.set_value("cosmetic", "name", player_name.text)
		config.set_value("cosmetic", "color", get_child(0).self_modulate)
		config.set_value("cosmetic", "icon", selected_icon)
		
		config.save(CONFIG_PATH)
