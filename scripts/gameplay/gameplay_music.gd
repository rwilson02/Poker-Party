extends Node

@export var clips: Dictionary

@onready var MUSIC = $Music
@onready var SFX = $SFX

# Called when the node enters the scene tree for the first time.
func _ready():
	MUSIC.play()
	
	SFX.finished.connect(func(): SFX.stream = null)

func play_sfx(clip: String):
	if clips.has(clip):
		SFX.stream = clips[clip]
		SFX.play()
