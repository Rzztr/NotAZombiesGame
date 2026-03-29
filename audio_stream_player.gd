extends Node

@onready var player: AudioStreamPlayer = $MusicPlayer

var playlist = [
	preload("res://audio/music/115.mp3"),
	preload("res://audio/music/APT.mp3"),
	preload("res://audio/music/BringMeToLife.mp3"),
	preload("res://audio/music/ChildrenOfTheGrave.mp3"),
	preload("res://audio/music/EnterSandman.mp3"),
	preload("res://audio/music/HailToTheKing.mp3"),
	preload("res://audio/music/HeavenNHell.mp3"),
	preload("res://audio/music/Paranoid.mp3"),
	preload("res://audio/music/RosaPastel.mp3"),
	preload("res://audio/music/Scourge of Iron.mp3"),
	preload("res://audio/music/TheFourHorseman.mp3"),
	preload("res://audio/music/TheOnlyThingToFearIsYou.mp3"),
	preload("res://audio/music/WaitingForLove.mp3"),
	preload("res://audio/music/WarPigs.mp3")
]

var index = 0

func _ready():
	player.finished.connect(_next_song)
	_play_current()

func _play_current():
	player.stream = playlist[index]
	player.play()

func _next_song():
	index += 1
	if index >= playlist.size():
		index = 0
	_play_current()
