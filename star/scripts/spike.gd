extends Area2D

@export var damage: int = 1

func _physics_process(_delta: float) -> void:
	# Checked every frame so standing in spikes hurts again
	# as soon as the invulnerability ends.
	for body in get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(damage)
