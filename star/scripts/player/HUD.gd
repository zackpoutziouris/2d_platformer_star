extends CanvasLayer

@export var full_heart: Texture2D
@export var empty_heart: Texture2D
@export var heart_size: Vector2 = Vector2(48, 48)

@onready var hearts_container: HBoxContainer = $MarginContainer/HeartsContainer
@onready var timer_label: Label = $InfoMargin/InfoBox/TimerLabel
@onready var deaths_label: Label = $InfoMargin/InfoBox/DeathsLabel

var elapsed: float = 0.0
var timing: bool = true

func _ready() -> void:
	_update_timer()
	_update_deaths(GameStats.deaths)
	GameStats.deaths_changed.connect(_update_deaths)

	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return

	_build_hearts(player.max_health)
	player.health_changed.connect(_on_health_changed)

func _process(delta: float) -> void:
	if timing:
		elapsed += delta
		_update_timer()

func _on_health_changed(health: int) -> void:
	_update_hearts(health)
	# Stop the clock the moment the player dies.
	if health <= 0:
		timing = false

func _update_timer() -> void:
	var minutes := int(elapsed / 60.0)
	var seconds := int(elapsed) % 60
	var millis := int(fmod(elapsed, 1.0) * 1000.0)
	timer_label.text = "%02d:%02d.%03d" % [minutes, seconds, millis]

func _update_deaths(count: int) -> void:
	deaths_label.text = "Deaths: %d" % count

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
