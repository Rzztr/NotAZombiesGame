extends Node

const ZombieScene = preload("res://zombie.tscn")

@export var max_zombies_at_once: int = 24
@export var base_zombies: int = 5
@export var zombies_per_round: int = 3
@export var spawn_interval: float = 2.0
@export var time_between_rounds: float = 5.0

var current_round: int = 0
var zombies_remaining_in_round: int = 0
var zombies_alive: int = 0
var round_active: bool = false
var spawn_timer: float = 0.0
var next_level_player: AudioStreamPlayer

func _ready() -> void:
	add_to_group("RoundManager")

	next_level_player = AudioStreamPlayer.new()
	next_level_player.stream = preload("res://audio/soundsEffects/NextLevel.mp3")
	add_child(next_level_player)

	if not multiplayer.is_server():
		set_process(false)
		return
	# Don't start automatically; wait for game to be hosted in world.gd or start it here for simplicity
	# Because world.gd calls `enet_peer.create_server(PORT)` when Host is clicked
	# We should probably hook into the multiplayer signal or just check in _process
	pass

@rpc("call_local")
func play_next_level_sound() -> void:
	if next_level_player:
		next_level_player.play()

func start_next_round() -> void:
	play_next_level_sound.rpc()
	current_round += 1
	zombies_remaining_in_round = base_zombies + (current_round * zombies_per_round)
	zombies_alive = 0
	round_active = true
	spawn_timer = spawn_interval
	
func _process(delta: float) -> void:
	if not round_active:
		if multiplayer.is_server() and current_round == 0:
			# Automatically start round 1 when a server exists and first player is in
			if get_tree().get_nodes_in_group("Players").size() > 0:
				start_next_round()
		return
		
	if zombies_remaining_in_round > 0 and zombies_alive < max_zombies_at_once:
		spawn_timer -= delta
		if spawn_timer <= 0:
			spawn_zombie()
			spawn_timer = spawn_interval
			
	if zombies_remaining_in_round <= 0 and zombies_alive <= 0:
		round_active = false
		await get_tree().create_timer(time_between_rounds).timeout
		start_next_round()

func spawn_zombie() -> void:
	var spawn_points = get_tree().get_nodes_in_group("SpawnPoints")
	if spawn_points.size() == 0:
		return
		
	var sp = spawn_points[randi() % spawn_points.size()]
	var zombie = ZombieScene.instantiate()
	zombie.position = sp.global_position
	zombie.name = "Zombie_" + str(current_round) + "_" + str(zombies_remaining_in_round)
	get_parent().add_child(zombie)
	
	zombie.initialize(current_round, self)
	zombies_remaining_in_round -= 1
	zombies_alive += 1

func zombie_died() -> void:
	zombies_alive -= 1
