extends Node2D

func _ready() -> void:
	$AnimationPlayer.animation_finished.connect(func(_name: StringName) -> void: queue_free())
