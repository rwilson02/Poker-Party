extends Node

@onready var mat = self.material

const BG_RESCROLL_TIME = 3 * 60 # 3 minutes in seconds
const BG_TEMPLATE = "res://textures/gameplay/background%d.png"

var bg_num: int

# Called when the node enters the scene tree for the first time.
func _ready():
	var get_circle_vec = func(): return Vector2(randf_range(-1,1), randf_range(-1,1)).normalized()
	
	var bg_timer_a = Timer.new()
	bg_timer_a.one_shot = false
	bg_timer_a.timeout.connect(func():
		mat.set_shader_parameter("dir", get_circle_vec.call())
	)
	add_child(bg_timer_a)
	bg_timer_a.start(BG_RESCROLL_TIME)
	mat.set_shader_parameter("dir", get_circle_vec.call())
	
	var bg_timer_b = Timer.new()
	bg_timer_b.one_shot = false
	bg_timer_b.timeout.connect(func():
		bg_num = (bg_num % 3) + 1
		self.texture = load(BG_TEMPLATE % bg_num)
	)
	add_child(bg_timer_b)
	bg_timer_b.start(BG_RESCROLL_TIME * 3)
	bg_num = randi_range(1, 3)
	self.texture = load(BG_TEMPLATE % bg_num)
