extends AnimatableBody2D

@export var moves: bool = true
@export var travel: Vector2 = Vector2(64.0, 0.0) # end point, relative to where you place it
@export var speed: float = 40.0 # average speed in pixels per second
@export var wait_time: float = 0.4 # pause at each end

func _ready() -> void:
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
