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

func _ready() -> void:
	pass

func initialize(round_number: int, manager: Node) -> void:
	round_manager = manager
	var max_health = base_health + (round_number * health_per_round)
	current_health = max_health
	print("Zombie spawned with ", current_health, " health points for round ", round_number)

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
		
	if not is_on_floor():
		velocity.y -= 9.8 * delta
		
	var target = _get_closest_player()
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
			
		var dir = global_position.direction_to(target.global_position)
		var new_velocity = dir * speed
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
			die()

func die() -> void:
	if round_manager:
		round_manager.zombie_died()
	queue_free()
