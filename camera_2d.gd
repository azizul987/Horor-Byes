extends Camera2D

@export var zoom_speed: float = 5.0
@export var min_zoom: float = 0.5
@export var max_zoom: float = 3.0

var target_zoom: float = 1.0

func _ready() -> void:
	target_zoom = zoom.x

func _process(delta: float) -> void:
	if Input.is_action_pressed("zoom_in"):
		target_zoom -= zoom_speed * delta
	
	if Input.is_action_pressed("zoom_out"):
		target_zoom += zoom_speed * delta

	target_zoom = clamp(target_zoom, min_zoom, max_zoom)
	zoom = zoom.lerp(Vector2(target_zoom, target_zoom), 8.0 * delta)
