extends CharacterBody2D

signal health_changed(new_health: int)
signal died

@export_category("Health")
@export var max_health: int = 3
@export var invulnerability_time: float = 1.5
@export var flash_interval: float = 0.05
@export var death_fade_time: float = 0.8

var health: int = 0
var is_invulnerable: bool = false
var invulnerability_left: float = 0.0
var is_dead: bool = false

@export_category("Movement")
@export var move_speed: float = 100.0
@export var acceleration: float = 600.0
@export var turn_acceleration: float = 1200.0
@export var deceleration: float = 900.0
@export var jump_velocity: float = -250.0
@export var gravity_multiplier: float = 0.65
@export var jump_cut_ratio: float = 0.5
@export var fall_gravity_multiplier: float = 1.1
@export var max_fall_speed: float = 420.0

@export_category("Double Jump")
@export var max_air_jumps: int = 1
@export var double_jump_velocity: float = -250.0
@export var double_jump_effect: PackedScene
@export var effect_offset: Vector2 = Vector2.ZERO
var air_jumps_left: int = 0

@export_category("Air Control")
@export var air_acceleration: float = 600.0
@export var air_turn_acceleration: float = 1200.0
@export var air_drag: float = 125.0
var air_speed_cap: float = 0.0

@export_category("Glide")
@export var glide_fall_speed: float = 40.0
@export var glide_horizontal_acceleration: float = 400.0
@export var glide_vertical_acceleration: float = 1200.0
@export var glide_max_entry_fall_speed: float = 500.0
var is_gliding: bool = false
var glide_blocked: bool = false

@export_category("Dive")
@export var dive_speed: float = 200.0
@export var dive_horizontal_speed: float = 25.0
@export var dive_horizontal_acceleration: float = 300.0
var is_diving: bool = false

@export_category("Dash")
@export var dash_speed: float = 210.0
@export var dash_duration: float = 0.3
@export var max_air_dashes: int = 1
@export var dash_ignores_gravity: bool = true
@export var dash_air_drag: float = 500.0
var current_dash_speed: float = 0.0
var dash_carry: bool = false

@export_category("Crouch")
@export var crouch_speed_multiplier: float = 0.3
@export var stand_clearance: float = 3.0 # standing is 2px taller than crouching
var is_crouching: bool = false
var facing_from_crouch_jump: bool = false

@export_category("Crouch Jump")
@export var crouch_jump_velocity: float = -300.0
@export var crouch_jump_horizontal_speed: float = 90.0
@export var crouch_jump_lock_time: float = 0.25
var is_crouch_jumping: bool = false
var crouch_jump_lock_left: float = 0.0

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

func _enter_tree() -> void:
	# Registered early so the HUD and death screen can find the player
	# no matter what order the nodes are in.
	add_to_group("player")

func _ready() -> void:
	health = max_health

func _process(delta: float) -> void:
	if not is_invulnerable:
		return

	invulnerability_left -= delta
	if invulnerability_left <= 0.0:
		is_invulnerable = false
		animation_handle.modulate.a = 1.0
		return

	# Blink by toggling opacity at a fixed interval.
	var visible_phase := int(invulnerability_left / flash_interval) % 2 == 0
	animation_handle.modulate.a = 1.0 if visible_phase else 0.3

func take_damage(amount: int = 1) -> void:
	if is_invulnerable or is_dead:
		return

	health = maxi(health - amount, 0)
	health_changed.emit(health)

	if health == 0:
		_die()
	else:
		is_invulnerable = true
		invulnerability_left = invulnerability_time

func _die() -> void:
	is_dead = true
	is_invulnerable = false
	set_physics_process(false)
	set_process(false)
	velocity = Vector2.ZERO

	# Fade the sprite out, then tell the death screen to appear.
	animation_handle.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(animation_handle, "modulate:a", 0.0, death_fade_time)
	tween.tween_callback(func() -> void: died.emit())

func _physics_process(delta: float) -> void:
	# Landing refills the air dash.
	if is_on_floor():
		air_dashes_left = max_air_dashes
		air_jumps_left = max_air_jumps
		is_diving = false
		is_gliding = false
		glide_blocked = false

	var direction := Input.get_axis("move_left", "move_right")

	# Facing is locked while dashing and during the crouch jump lock.
	if direction != 0.0 and not is_dashing and crouch_jump_lock_left <= 0.0:
		facing = signf(direction)
		facing_from_crouch_jump = false
	
	_update_crouch()
	_update_sprint(direction)
	_try_start_dive()
	_try_start_dash()
	_update_glide()

	if is_diving:
		_process_dive(delta, direction)
	elif is_dashing:
		_process_dash(delta)
	else:
		_process_movement(delta, direction)

	move_and_slide()
	_update_animation()

func _process_movement(delta: float, direction: float) -> void:
	var on_floor := is_on_floor()
	crouch_jump_lock_left = maxf(crouch_jump_lock_left - delta, 0.0)

	# Vertical: glide replaces gravity while active.
	if is_gliding:
		_move_glide(delta)
	elif not on_floor:
		var g := gravity * gravity_multiplier
		if velocity.y > 0.0:
			g *= fall_gravity_multiplier
		velocity.y = minf(velocity.y + g * delta, max_fall_speed)

	# Horizontal: same rules whether gliding or not.
	if on_floor:
		is_crouch_jumping = false
		crouch_jump_lock_left = 0.0
		_move_on_ground(delta, direction)
	elif crouch_jump_lock_left <= 0.0:
		# Air control only returns once the launch lock has ended.
		_move_in_air(delta, direction)

	if Input.is_action_just_pressed("jump"):
		if on_floor:
			if is_crouching:
				_start_crouch_jump()
			else:
				velocity.y = jump_velocity
		elif air_jumps_left > 0:
			air_jumps_left -= 1
			is_gliding = false
			is_crouch_jumping = false
			crouch_jump_lock_left = 0.0
			velocity.y = double_jump_velocity
			_spawn_double_jump_effect()

	# Variable height: not applied to crouch jumps.
	if velocity.y < 0.0 and not is_crouch_jumping and not Input.is_action_pressed("jump"):
		velocity.y = maxf(velocity.y, jump_velocity * jump_cut_ratio)

func _move_on_ground(delta: float, direction: float) -> void:
	var current_speed := move_speed
	if is_crouching:
		current_speed *= crouch_speed_multiplier
	elif is_sprinting:
		current_speed *= sprint_speed_multiplier

	if direction != 0.0:
		# Reversing uses a stronger rate so turning around feels responsive.
		var accel := acceleration
		if velocity.x != 0.0 and signf(direction) != signf(velocity.x):
			accel = turn_acceleration
		velocity.x = move_toward(velocity.x, direction * current_speed, accel * delta)
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

func _start_crouch_jump() -> void:
	is_crouch_jumping = true
	crouch_jump_lock_left = crouch_jump_lock_time

	# Facing set by a previous crouch jump already points the way of travel,
	# so keep it. Otherwise launch backwards from the current facing.
	if not facing_from_crouch_jump:
		facing = -facing
	facing_from_crouch_jump = true

	velocity.y = crouch_jump_velocity
	velocity.x = facing * crouch_jump_horizontal_speed
	air_speed_cap = maxf(crouch_jump_horizontal_speed, move_speed)

func _update_sprint(direction: float) -> void:
	is_sprinting = (
		Input.is_action_pressed("sprint")
		and direction != 0.0
		and not is_crouching
		and not is_dashing
	)

func _update_glide() -> void:
	var holding_jump := Input.is_action_pressed("jump")

	# Releasing jump re-arms gliding, so you can glide as many times as you like.
	if not holding_jump:
		glide_blocked = false

	if is_on_floor() or is_dashing or is_diving or not holding_jump or glide_blocked:
		is_gliding = false
		return

	if is_gliding:
		return

	# Start only when falling, and not too fast.
	var spending_air_jump := Input.is_action_just_pressed("jump") and air_jumps_left > 0
	if (
		velocity.y >= 0.0
		and velocity.y <= glide_max_entry_fall_speed
		and crouch_jump_lock_left <= 0.0
		and not spending_air_jump
	):
		is_gliding = true

func _move_glide(delta: float) -> void:
	# Ease down to a slow, steady fall.
	velocity.y = move_toward(velocity.y, glide_fall_speed, glide_vertical_acceleration * delta)

func _try_start_dive() -> void:
	if is_diving or is_on_floor() or not Input.is_action_just_pressed("dive"):
		return

	# Cancel everything else, including a dash or a crouch jump.
	is_diving = true
	is_gliding = false
	glide_blocked = true
	is_dashing = false
	is_crouch_jumping = false
	crouch_jump_lock_left = 0.0
	dash_carry = false

	velocity.x = 0.0
	velocity.y = dive_speed

func _process_dive(delta: float, direction: float) -> void:
	# Fixed downward speed, with only a small amount of sideways control.
	velocity.y = dive_speed
	velocity.x = move_toward(
		velocity.x,
		direction * dive_horizontal_speed,
		dive_horizontal_acceleration * delta
	)

func _try_start_dash() -> void:
	if is_dashing or is_crouching or is_diving or not Input.is_action_just_pressed("dash"):
		return
	
	# Dashing on the ground is free; dashing in the air uses a charge.
	if not is_on_floor():
		if air_dashes_left <= 0:
			return
		air_dashes_left -= 1

	is_dashing = true
	is_gliding = false
	is_crouch_jumping = false
	crouch_jump_lock_left = 0.0
	dash_time_left = dash_duration
	
	# Keep any speed above the dash speed, as long as it's in the dash direction.
	var carried := maxf(velocity.x * facing, 0.0)
	current_dash_speed = maxf(dash_speed, carried)

func _process_dash(delta: float) -> void:
	velocity.x = facing * current_dash_speed

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
	return absf(get_real_velocity().x) > 20.0

func _spawn_double_jump_effect() -> void:
	if double_jump_effect == null:
		return
	var effect := double_jump_effect.instantiate() as Node2D
	get_parent().add_child(effect)
	effect.global_position = global_position + effect_offset

func _update_animation() -> void:
	# Mirror the handle around its origin to face the right way.
	animation_handle.scale.x = facing
	animation_player.speed_scale = 1.0

	# Dash overrides everything for its whole duration.
	if is_dashing:
		animation_player.play("dash")
	elif is_diving:
		animation_player.play("dive")
	elif is_gliding:
		animation_player.play("glide")
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
