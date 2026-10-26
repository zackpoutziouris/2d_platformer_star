extends CharacterBody2D

@export_category("Movement")
@export var move_speed: float = 250.0
@export var acceleration: float = 1800.0
@export var deceleration: float = 2200.0
@export var jump_velocity: float = -420.0
@export var gravity_multiplier: float = 1.0

var gravity: float = float(
	ProjectSettings.get_setting("physics/2d/default_gravity")
)

func _physics_process(delta: float) -> void:
	# Apply gravity while airborne.
	if not is_on_floor():
		velocity.y += gravity * gravity_multiplier * delta

	# Horizontal movement.
	var direction := Input.get_axis("move_left", "move_right")

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

	move_and_slide()
