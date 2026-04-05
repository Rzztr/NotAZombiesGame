## weapon_shop.gd
## Attach to an Area3D placed at each weapon display in the map.
## When the local player enters the area and presses E, they buy the weapon.
extends Area3D

@export var weapon_name: String = "submachine"   # "submachine" | "assault" | "assault2"
@export var cost: int = 500

@onready var label: Label3D = $Label3D

var player_inside: Node = null

func _ready() -> void:
	# collision_mask = 2 so it detects the player layer (set in tscn as well)
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	label.text = "[E] Comprar %s\n%d pts" % [_display_name(), cost]
	label.visible = true   # Always visible so player can see the shop from afar

func _process(_delta: float) -> void:
	if player_inside == null:
		return
	if Input.is_action_just_pressed("interact"):
		_try_buy()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("Players"):
		# Store first matching player
		player_inside = body

func _on_body_exited(body: Node3D) -> void:
	if body == player_inside:
		player_inside = null

func _try_buy() -> void:
	if not player_inside:
		return
	# Only the local authority can spend points & change skin
	if not player_inside.is_multiplayer_authority():
		return
	if Global.spend_score(cost):
		player_inside.change_weapon_skin(weapon_name)
	else:
		# Flash the label red briefly to signal not enough points
		label.modulate = Color(1, 0.2, 0.2)
		await get_tree().create_timer(0.5).timeout
		label.modulate = Color(1, 1, 1)

func _display_name() -> String:
	match weapon_name:
		"submachine": return "SMG"
		"assault":    return "Rifle"
		"assault2":   return "Rifle MK2"
		_:            return weapon_name
