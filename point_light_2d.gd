extends PointLight2D

@export var min_energy: float = 0.7
@export var max_energy: float = 1.6
@export var flicker_speed: float = 8.0
@export var color_change_interval: float = 0.4
@export var smooth_color_change: float = 4.0

var target_energy: float
var target_color: Color
var color_timer: float = 0.0

func _ready() -> void:
	randomize()
	target_energy = energy
	target_color = color
	_pick_new_color()

func _process(delta: float) -> void:
	# Flicker / kedip halus
	var flicker = randf_range(min_energy, max_energy)
	target_energy = lerp(target_energy, flicker, flicker_speed * delta)
	energy = target_energy

	# Timer ganti warna
	color_timer -= delta
	if color_timer <= 0.0:
		color_timer = color_change_interval
		_pick_new_color()

	# Smooth transisi warna
	color = color.lerp(target_color, smooth_color_change * delta)

func _pick_new_color() -> void:
	# Warna terang random
	target_color = Color.from_hsv(
		randf(),              # hue random
		randf_range(0.6, 1.0),# saturation
		randf_range(0.8, 1.0) # value / brightness
	)
