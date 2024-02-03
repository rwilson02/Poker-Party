extends Node

@export var clips: Dictionary

@onready var MUSIC = $Music
@onready var SFX = $SFX

# Called when the node enters the scene tree for the first time.
func _ready():
	var config = ConfigFile.new()
	var err = config.load("user://config.cfg")
	if not err:
		MUSIC.volume_db = linear_to_db(config.get_value("settings", "music_vol", 1))
		SFX.volume_db = linear_to_db(config.get_value("settings", "sfx_vol", 1))
	
	MUSIC.play()
	SFX.finished.connect(func(): SFX.stream = null)

func play_sfx(clip: String):
	if clips.has(clip):
		SFX.stream = clips[clip]
		SFX.play()
