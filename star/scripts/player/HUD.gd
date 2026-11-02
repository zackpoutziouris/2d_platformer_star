extends CanvasLayer

@export var full_heart: Texture2D
@export var empty_heart: Texture2D
@export var heart_size: Vector2 = Vector2(48, 48)

@onready var hearts_container: HBoxContainer = $MarginContainer/HeartsContainer

func _ready() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return

	_build_hearts(player.max_health)
	player.health_changed.connect(_update_hearts)

func _build_hearts(count: int) -> void:
	for i in count:
		var heart := TextureRect.new()
		heart.custom_minimum_size = heart_size
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart.texture = full_heart
		hearts_container.add_child(heart)

func _update_hearts(health: int) -> void:
	for i in hearts_container.get_child_count():
		var heart := hearts_container.get_child(i) as TextureRect
		heart.texture = full_heart if i < health else empty_heart
