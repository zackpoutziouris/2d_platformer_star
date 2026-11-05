extends Node

signal deaths_changed(count: int)

var deaths: int = 0

func add_death() -> void:
	deaths += 1
	deaths_changed.emit(deaths)

func reset() -> void:
	deaths = 0
	deaths_changed.emit(deaths)
