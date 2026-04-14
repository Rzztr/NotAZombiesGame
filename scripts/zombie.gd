extends CharacterBody3D

@export var base_health := 100
@export var health_per_round := 50
@export var speed := 3.0
var current_health := 100
var round_manager: Node = null

var time_in_contact: float = 0.0
const ATTACK_RANGE: float = 2.0
const ATTACK_DAMAGE: int = 5
const ATTACK_DELAY: float = 1.0

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var zombie_sound_player: AudioStreamPlayer3D

func _ready() -> void:
	add_to_group("Zombies")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	zombie_sound_player = AudioStreamPlayer3D.new()
	var sound1 = preload("res://audio/soundsEffects/Zombie1.mp3")
	var sound2 = preload("res://audio/soundsEffects/Zombie2.mp3")
	zombie_sound_player.stream = sound1 if randi() % 2 == 0 else sound2
	zombie_sound_player.max_distance = 50.0
	add_child(zombie_sound_player)
	zombie_sound_player.play()

func initialize(round_number: int, manager: Node) -> void:
	round_manager = manager
	var max_health = base_health + (round_number * health_per_round)
	current_health = max_health

var target: Node3D = null
var target_update_timer: float = 0.0

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
		
	if not is_on_floor():
		velocity.y -= 9.8 * delta
		
	target_update_timer -= delta
	if target_update_timer <= 0:
		target = _get_closest_player()
		# Randomize the timer slightly so all zombies don't update exactly on the same frame
		target_update_timer = randf_range(0.2, 0.4)
		
	if target:
		var dist = global_position.distance_to(target.global_position)
		if dist < ATTACK_RANGE:
			time_in_contact += delta
			if time_in_contact >= ATTACK_DELAY:
				if target.has_method("recieve_damage"):
					target.recieve_damage.rpc_id(target.get_multiplayer_authority(), ATTACK_DAMAGE)
				time_in_contact = 0.0
		else:
			time_in_contact = 0.0
			
		# Separation force to avoid clumping (reduces collision resolution overhead)
		var separation = Vector3.ZERO
		var all_zombies = get_tree().get_nodes_in_group("Zombies")
		for z in all_zombies:
			if z != self and z.is_inside_tree():
				var d = global_position.distance_to(z.global_position)
				if d < 1.5 and d > 0.01:
					separation += (global_position - z.global_position).normalized() * (1.5 - d)
					
		var dir = global_position.direction_to(target.global_position)
		# Combine path direction with separation
		var combined_dir = (dir + separation * 1.5).normalized()
		var new_velocity = combined_dir * speed
		
		velocity.x = move_toward(velocity.x, new_velocity.x, .25)
		velocity.z = move_toward(velocity.z, new_velocity.z, .25)
		
		var v_flat = Vector3(velocity.x, 0, velocity.z)
		if v_flat.length() > 0.1:
			var look_dir = global_position + v_flat
			look_at(look_dir, Vector3.UP, true)
	else:
		velocity.x = move_toward(velocity.x, 0, .25)
		velocity.z = move_toward(velocity.z, 0, .25)
		
	move_and_slide()

func _get_closest_player() -> Node3D:
	var players = get_tree().get_nodes_in_group("Players")
	var closest = null
	var min_dist = INF
	for p in players:
		var dist = global_position.distance_to(p.global_position)
		if dist < min_dist:
			closest = p
			min_dist = dist
	return closest

@rpc("any_peer", "call_local")
func take_damage(amount: int) -> void:
	if multiplayer.is_server():
		current_health -= amount
		if current_health <= 0:
			Global.add_score.rpc(100)
			die()

func die() -> void:
	if round_manager:
		round_manager.zombie_died()
	queue_free()
