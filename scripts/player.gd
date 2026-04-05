extends CharacterBody3D

@onready var camera: Camera3D = $Camera3D
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var muzzle_flash: GPUParticles3D = $Camera3D/pistol/GPUParticles3D
@onready var raycast: RayCast3D = $Camera3D/RayCast3D
@onready var gunshot_sound: AudioStreamPlayer3D = %GunshotSound
@onready var gun_node: Node3D = $Camera3D/pistol
@onready var round_label: Label = $HUD/MarginContainer/RoundLabel
@onready var health_bar: ProgressBar = $HUD/HealthBar
@onready var score_label: Label = $HUD/ScoreContainer/ScoreLabel

const WEAPON_SCENES: Dictionary = {
	"submachine": preload("res://Guns/SubmachineGun_5.blend"),
	"assault":    preload("res://Guns/AssaultRifle_2.blend"),
	"assault2":   preload("res://Guns/AssaultRifle2_2.blend"),
}
var current_skin: String = "pistol"

## Number of shots before a player dies
@export var max_health: int = 100
var current_health: int = 100
var time_since_last_damage: float = 0.0
var time_since_last_regen: float = 0.0

var hit_sound_player: AudioStreamPlayer

## The xyz position of the random spawns, you can add as many as you want!
@export var spawns: PackedVector3Array = ([
	Vector3(-18, 0.2, 0),
	Vector3(18, 0.2, 0),
	Vector3(-2.8, 0.2, -6),
	Vector3(-17,0,17),
	Vector3(17,0,17),
	Vector3(17,0,-17),
	Vector3(-17,0,-17)
])
var sensitivity : float =  .005
var controller_sensitivity : float =  .010

var axis_vector : Vector2
var	mouse_captured : bool = true

const SPEED = 5.5
const JUMP_VELOCITY = 4.5

func _enter_tree() -> void:
	set_multiplayer_authority(str(name).to_int())
	add_to_group("Players")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if not is_multiplayer_authority(): return

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.current = true
	position = spawns[randi() % spawns.size()]
	
	hit_sound_player = AudioStreamPlayer.new()
	hit_sound_player.stream = preload("res://audio/soundsEffects/Hit.mp3")
	add_child(hit_sound_player)

func _process(delta: float) -> void:
	sensitivity = Global.sensitivity
	controller_sensitivity = Global.controller_sensitivity

	rotate_y(-axis_vector.x * controller_sensitivity)
	camera.rotate_x(-axis_vector.y * controller_sensitivity)
	camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
	
	if is_multiplayer_authority():
		var rm = get_tree().get_first_node_in_group("RoundManager")
		if rm and round_label != null:
			round_label.text = "Round: " + str(rm.current_round)
			
		if score_label != null:
			score_label.text = "Puntos: " + str(Global.score)
			
		if current_health < max_health:
			time_since_last_damage += delta
			if time_since_last_damage >= 2.0:
				time_since_last_regen += delta
				if time_since_last_regen >= 1.0: # Regens 10 points every 1 second
					current_health = min(current_health + 10, max_health)
					time_since_last_regen = 0.0
					
		if health_bar != null:
			health_bar.value = current_health

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority(): return

	axis_vector = Input.get_vector("look_left", "look_right", "look_up", "look_down")

	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * sensitivity)
		camera.rotate_x(-event.relative.y * sensitivity)
	camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)

	if Input.is_action_just_pressed("capture"):
		if mouse_captured:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			mouse_captured = false
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			mouse_captured = true

func _physics_process(delta: float) -> void:
	if multiplayer.multiplayer_peer != null:
		if not is_multiplayer_authority(): return
		
	# Handle shooting continuously during physics to ensure reliable tracking
	if Input.is_action_pressed("shoot") and anim_player.current_animation != "shoot":
		play_shoot_effects.rpc()
		gunshot_sound.play()
		if raycast.is_colliding() and raycast.get_collider() is CharacterBody3D:
			var hit_target = raycast.get_collider()
			if hit_target.is_in_group("Zombies") and hit_target.has_method("take_damage"):
				# Assuming machine gun deals less damage per shot, e.g. 35
				hit_target.take_damage.rpc_id(1, 35)
			elif hit_target.has_method("recieve_damage"):
				hit_target.recieve_damage.rpc_id(hit_target.get_multiplayer_authority())

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("left", "right", "up", "down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y))
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	if anim_player.current_animation == "shoot":
		pass
	elif input_dir != Vector2.ZERO and is_on_floor() :
		anim_player.play("move")
	else:
		anim_player.play("idle")

	move_and_slide()

@rpc("call_local")
func play_shoot_effects() -> void:
	anim_player.stop()
	anim_player.play("shoot")
	muzzle_flash.restart()
	muzzle_flash.emitting = true

@rpc("any_peer", "call_local")
func recieve_damage(damage:= 1) -> void:
	if is_multiplayer_authority() and hit_sound_player:
		hit_sound_player.play()
	current_health -= damage
	time_since_last_damage = 0.0
	time_since_last_regen = 0.0
	if current_health <= 0:
		if is_multiplayer_authority():
			var world = get_tree().current_scene
			if world.has_method("show_death_screen"):
				world.show_death_screen()

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "shoot":
		anim_player.play("idle")

@rpc("any_peer", "call_local")
func change_weapon_skin(weapon_name: String) -> void:
	if not WEAPON_SCENES.has(weapon_name):
		return
	# Remove old custom skin if there is one
	for child in gun_node.get_children():
		if child is Node3D and not child is GPUParticles3D and not child is AudioStreamPlayer3D:
			child.queue_free()
			await child.tree_exited
			break
	# Instantiate new skin and attach under gun_node
	var new_skin: Node3D = WEAPON_SCENES[weapon_name].instantiate()

	# Blender→Godot: barrels are usually along Blender +Y → Godot -Z (pointing away = correct).
	# We need to rotate the model so the barrel faces -Z (into the scene).
	# The map display transforms tell us the native orientation:
	#   AssaultRifle_2  → no rotation in map, scale ~0.25  → rotate -90° X to lay from vertical
	#   AssaultRifle2_2 → ~90° Y rotation in map, scale ~0.30
	#   SubmachineGun_5 → ~90° Y rotation in map, scale ~0.20
	# For first-person the gun should look similar in size to the pistol mesh.
	# gun_node is 0.5 m from the camera, so a ~0.30 scale on a real-size Blender model works.
	var s: float
	var rot: Vector3  # Euler XYZ in radians (YXZ order in Godot)
	# The gun barrels are natively along +X in Godot space after Blender import.
	# Rx(-90°) doesn't affect the X axis — that's why they pointed right.
	# Ry(+90°) correctly sends +X → -Z (barrel pointing into the scene, away from player).
	match weapon_name:
		"assault":    # AssaultRifle_2 (1000 pts)
			s = 0.28
			rot = Vector3(0.0, PI / 2.0, 0.0)
		"assault2":   # AssaultRifle2_2 MK2 (1500 pts)
			s = 0.32
			rot = Vector3(0.0, PI / 2.0, 0.0)
		"submachine": # SubmachineGun_5 (500 pts)
			s = 0.22
			rot = Vector3(0.0, PI / 2.0, 0.0)
		_:
			s = 0.25
			rot = Vector3(0.0, PI / 2.0, 0.0)

	var basis = Basis.from_euler(rot).scaled(Vector3(s, s, s))
	# Offset slightly so the gun sits in the same visual spot as the pistol mesh
	new_skin.transform = Transform3D(basis, Vector3(0.0, -0.05, 0.1))
	gun_node.add_child(new_skin)
	current_skin = weapon_name
