extends CharacterBody2D

@export_category("Movement")
@export var move_speed: float = 100.0
@export var acceleration: float = 1800.0
@export var deceleration: float = 2200.0
@export var jump_velocity: float = -250.0
@export var gravity_multiplier: float = 0.65
@export var jump_cut_ratio: float = 0.5
@export var fall_gravity_multiplier: float = 1.1
@export var max_fall_speed: float = 420.0

@export_category("Air Control")
@export var air_acceleration: float = 1000.0
@export var air_turn_acceleration: float = 2400.0
@export var air_drag: float = 125.0
var air_speed_cap: float = 0.0

@export_category("Dash")
@export var dash_speed: float = 300.0
@export var dash_duration: float = 0.3
@export var max_air_dashes: int = 1
@export var dash_ignores_gravity: bool = true
@export var dash_air_drag: float = 500.0
var dash_carry: bool = false

@export_category("Crouch")
@export var crouch_speed_multiplier: float = 0.5
@export var stand_clearance: float = 3.0 # standing is 2px taller than crouching
var is_crouching: bool = false

@export_category("Sprint")
@export var sprint_speed_multiplier: float = 1.4
@export var sprint_animation_speed: float = 2.0
var is_sprinting: bool = false

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
	
	_update_crouch()
	_update_sprint(direction)
	_try_start_dash()

	if is_dashing:
		_process_dash(delta)
	else:
		_process_movement(delta, direction)

	move_and_slide()
	_update_animation()

func _process_movement(delta: float, direction: float) -> void:
	var on_floor := is_on_floor()

	# Gravity: stronger when falling, with a terminal velocity.
	if not on_floor:
		var g := gravity * gravity_multiplier
		if velocity.y > 0.0:
			g *= fall_gravity_multiplier
		velocity.y = minf(velocity.y + g * delta, max_fall_speed)

	if on_floor:
		_move_on_ground(delta, direction)
	else:
		_move_in_air(delta, direction)

	# Jump only when grounded.
	if Input.is_action_just_pressed("jump") and on_floor:
		velocity.y = jump_velocity

	# Variable height: if jump is released while rising, cap the upward speed.
	if velocity.y < 0.0 and not Input.is_action_pressed("jump"):
		velocity.y = maxf(velocity.y, jump_velocity * jump_cut_ratio)

func _move_on_ground(delta: float, direction: float) -> void:
	var current_speed := move_speed
	if is_crouching:
		current_speed *= crouch_speed_multiplier
	elif is_sprinting:
		current_speed *= sprint_speed_multiplier

	if direction != 0.0:
		velocity.x = move_toward(velocity.x, direction * current_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)

	# Remember ground speed so a jump or ledge walk-off can carry it.
	air_speed_cap = maxf(absf(velocity.x), move_speed)
	dash_carry = false

func _move_in_air(delta: float, direction: float) -> void:
	# Hitting a wall kills the carried momentum.
	if is_on_wall():
		air_speed_cap = move_speed
		dash_carry = false

	# No input: drag slows you, harder after a dash.
	if direction == 0.0:
		var drag := dash_air_drag if dash_carry else air_drag
		velocity.x = move_toward(velocity.x, 0.0, drag * delta)
		# Momentum lost to drag can't be regained by pressing the key again.
		air_speed_cap = minf(air_speed_cap, maxf(absf(velocity.x), move_speed))
		return

	# Pressing against your movement drops momentum and turns sharply.
	var reversing := velocity.x != 0.0 and signf(direction) != signf(velocity.x)
	var accel := air_acceleration
	if reversing:
		air_speed_cap = move_speed
		dash_carry = false
		accel = air_turn_acceleration

	velocity.x = move_toward(velocity.x, direction * air_speed_cap, accel * delta)

func _can_stand() -> bool:
	return not test_move(global_transform, Vector2(0.0, -stand_clearance))

func _update_crouch() -> void:
	var wants_crouch := (
		Input.is_action_pressed("crouch")
		and is_on_floor()
		and not is_dashing
	)

	if wants_crouch:
		is_crouching = true
	elif is_crouching and _can_stand():
		is_crouching = false

func _update_sprint(direction: float) -> void:
	is_sprinting = (
		Input.is_action_pressed("sprint")
		and direction != 0.0
		and not is_crouching
		and not is_dashing
	)

func _try_start_dash() -> void:
	if is_dashing or not Input.is_action_just_pressed("dash"):
		return
	
	# Can't dash out of a crouch if there's no room to stand.
	if is_crouching and not _can_stand():
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
		# Carry the dash speed into the air.
		if not is_on_floor():
			air_speed_cap = maxf(air_speed_cap, absf(velocity.x))
			dash_carry = true

func _is_moving_horizontally() -> bool:
	return absf(get_real_velocity().x) > 30.0

func _update_animation() -> void:
	# Mirror the handle around its origin to face the right way.
	animation_handle.scale.x = facing
	animation_player.speed_scale = 1.0

	# Dash overrides everything for its whole duration.
	if is_dashing:
		animation_player.play("dash")
	elif is_crouching:
		if _is_moving_horizontally():
			animation_player.play("crouch-walk")
		else:
			animation_player.play("crouch")
	# Moving horizontally: walk, faster while sprinting.
	elif _is_moving_horizontally():
		if is_sprinting:
			animation_player.speed_scale = sprint_animation_speed
		animation_player.play("walk")
	# Not moving horizontally and airborne: jump or fall.
	elif not is_on_floor():
		if velocity.y < 0.0:
			animation_player.play("jump")
		else:
			animation_player.play("fall")
	else:
		animation_player.play("idle")
