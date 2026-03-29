extends AudioStreamPlayer

var songs: Array[String] = []

func _ready() -> void:
	# Set 65% volume
	volume_db = linear_to_db(0.65)
	
	# Connect signal to loop indefinitely with random tracks
	finished.connect(start_random_song)
	
	var dir = DirAccess.open("res://audio/music/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			# In exported builds, raw .mp3 might not exist, but .import files will.
			# We collect the base filenames.
			if not dir.current_is_dir() and file_name.ends_with(".import"):
				var orig_name = file_name.replace(".import", "")
				var path = "res://audio/music/" + orig_name
				if not songs.has(path):
					songs.append(path)
			file_name = dir.get_next()

func start_random_song() -> void:
	if songs.size() == 0:
		print("No music found in audio/music/")
		return
		
	var random_song = songs[randi() % songs.size()]
	stream = load(random_song)
	play()
