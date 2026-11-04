@tool
extends AnimatableBody2D

@export var width: float = 16.0:
	set(value):
		width = maxf(value, 4.0)
		if is_node_ready():
			_apply_width()

@export var moves: bool = true
@export var travel: Vector2 = Vector2(64.0, 0.0) # end point, relative to where you place it
@export var speed: float = 40.0 # average speed in pixels per second
@export var wait_time: float = 0.4 # pause at each end

@onready var patch: NinePatchRect = $NinePatchRect
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	_apply_width()

	# Never animate inside the editor.
	if Engine.is_editor_hint():
		return

	sync_to_physics = true

	if not moves or travel == Vector2.ZERO or speed <= 0.0:
		return

	var start := position
	var end := start + travel
	var duration := travel.length() / speed

	var tween := create_tween().set_loops()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "position", end, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(wait_time)
	tween.tween_property(self, "position", start, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(wait_time)

func _apply_width() -> void:
	# Visual: keep the platform centred on the node's origin.
	patch.size = Vector2(width, 4.0)
	patch.position = Vector2(-width / 2.0, 4.0)

	# Collision: a fresh shape per platform so resizing one never affects another.
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, 3.0)
	collision.shape = shape
	collision.position = Vector2(0.0, 5.5)
