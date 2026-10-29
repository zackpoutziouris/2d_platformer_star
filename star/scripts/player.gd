extends CharacterBody2D

@export_category("Movement")
@export var move_speed: float = 140.0
@export var acceleration: float = 1800.0
@export var deceleration: float = 2200.0
@export var jump_velocity: float = -280.0
@export var gravity_multiplier: float = 0.80
@export var jump_cut_ratio: float = 0.5

@export_category("Dash")
@export var dash_speed: float = 300.0
@export var dash_duration: float = 0.3
@export var max_air_dashes: int = 1
@export var dash_ignores_gravity: bool = true

@onready var animation_handle: Node2D = $AnimationHandle
@onready var animation_player: AnimationPlayer = $AnimationHandle/AnimationPlayer

var gravity: float = float(
	ProjectSettings.get_setting("physics/2d/default_gravity")
)

var facing: float = 1.0
var is_dashing: bool = false
var dash_time_left: float = 0.0
var air_dashes_left: int = 0

func _physics_process(delta: float) -> void:
	# Landing refills the air dash.
	if is_on_floor():
		air_dashes_left = max_air_dashes

	var direction := Input.get_axis("move_left", "move_right")

	# Facing is locked while dashing.
	if direction != 0.0 and not is_dashing:
		facing = signf(direction)

	_try_start_dash()

	if is_dashing:
		_process_dash(delta)
	else:
		_process_movement(delta, direction)

	move_and_slide()
	_update_animation()

func _process_movement(delta: float, direction: float) -> void:
	# Apply gravity while airborne.
	if not is_on_floor():
		var g := gravity * gravity_multiplier
		if velocity.y > 0.0:
			g *= 1.1
		velocity.y += g * delta

	# Horizontal movement.
	if direction != 0.0:
		velocity.x = move_toward(
			velocity.x,
			direction * move_speed,
			acceleration * delta
		)
	else:
		velocity.x = move_toward(
			velocity.x,
			0.0,
			deceleration * delta
		)

	# Jump only when grounded.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		
	# Variable height: if jump is released while rising, cap the upward speed.
	if velocity.y < 0.0 and not Input.is_action_pressed("jump"):
		velocity.y = maxf(velocity.y, jump_velocity * jump_cut_ratio)

func _try_start_dash() -> void:
	if is_dashing or not Input.is_action_just_pressed("dash"):
		return

	# Dashing on the ground is free; dashing in the air uses a charge.
	if not is_on_floor():
		if air_dashes_left <= 0:
			return
		air_dashes_left -= 1

	is_dashing = true
	dash_time_left = dash_duration

func _process_dash(delta: float) -> void:
	velocity.x = facing * dash_speed

	if dash_ignores_gravity:
		velocity.y = 0.0
	elif not is_on_floor():
		velocity.y += gravity * gravity_multiplier * delta

	dash_time_left -= delta
	if dash_time_left <= 0.0:
		is_dashing = false

func _update_animation() -> void:
	# Mirror the handle around its origin to face the right way.
	animation_handle.scale.x = facing

	# Dash overrides everything for its whole duration.
	if is_dashing:
		animation_player.play("dash")
	# Moving horizontally: walk, even in the air.
	elif absf(velocity.x) > 0.0:
		animation_player.play("walk")
	# Not moving horizontally and airborne: jump or fall.
	elif not is_on_floor():
		if velocity.y < 0.0:
			animation_player.play("jump")
		else:
			animation_player.play("fall")
	else:
		animation_player.play("idle")
