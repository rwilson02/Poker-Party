extends Node

@onready var left_page = %PageL
@onready var right_page = %PageR
@onready var forward_button = %ButtonFWD
@onready var back_button = %ButtonBACK
@onready var TOC = %Sections

const SETTINGS = preload("res://scenes/ui/settings.tscn")

var page = 1
var currentL
var currentR
var settings_page

func _ready():
	TOC.meta_clicked.connect(set_page)
	
	currentL = left_page.get_child(page)
	currentR = right_page.get_child(page)

func close():
	self.queue_free()

func go_forward():
	set_page(page + 1, true)
func go_back():
	set_page(page - 1, true)
func set_page(page_num, internal = false):
	if typeof(page_num) == TYPE_STRING:
		var dict = JSON.parse_string(page_num)
		page_num = roundi(dict.page)
	elif typeof(page_num) != TYPE_INT:
		return
	
	if not internal:
		page_num = ceili(page_num / 2.0)
	
	if page_num == page:
		return
	
	page = page_num
	var newL = left_page.get_child(page)
	var newR = null
	if right_page.get_child_count() > page:
		newR = right_page.get_child(page)
	left_page.get_child(0).text = str(page * 2 - 1)
	right_page.get_child(0).text = str(page * 2)
	var has_right = newR != null
	
	newL.visible = true
	if has_right: newR.visible = true
	currentL.visible = false
	if currentR != null: currentR.visible = false
	currentL = newL
	currentR = newR
	
	if page == 1:
		back_button.disabled = true
		forward_button.disabled = false
	elif page >= left_page.get_child_count() - 1:
		forward_button.disabled = true
		back_button.disabled = false
	else:
		forward_button.disabled = false
		back_button.disabled = false

func toggle_settings():
	right_page.visible = not right_page.visible
	forward_button.disabled = not right_page.visible
	
	if right_page.visible:
		settings_page.queue_free()
	else:
		settings_page = SETTINGS.instantiate()
		left_page.get_parent().add_child(settings_page)
