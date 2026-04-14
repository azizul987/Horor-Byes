extends CharacterBody2D

const SPEED := 250.0
@onready var sprite: AnimatedSprite2D = $Player
@onready var step: AudioStreamPlayer2D = $Step

var facing_direction := "down"
var is_hidden := false

func _physics_process(delta: float) -> void:
	# Logika sembunyi
	if Input.is_action_pressed("hide"):
		is_hidden = true
		sprite.visible = false
	else:
		is_hidden = false
		sprite.visible = true

	var input_x := Input.get_axis("ui_left", "ui_right")
	var input_y := Input.get_axis("ui_up", "ui_down")
	var input_vector := Vector2(input_x, input_y).normalized()
	velocity = input_vector * SPEED
	move_and_slide()

	if input_vector != Vector2.ZERO:
		update_facing_direction(input_vector)
		if not is_hidden:
			play_walk_animation()
	else:
		if not is_hidden:
			play_idle_animation()
		# Hentikan suara saat diam
		if step.playing:
			step.stop()

func update_facing_direction(direction: Vector2) -> void:
	if abs(direction.x) > abs(direction.y):
		facing_direction = "right" if direction.x > 0 else "left"
	else:
		facing_direction = "down" if direction.y > 0 else "up"

func play_walk_animation() -> void:
	var anim_name := "Walk_" + facing_direction
	if sprite.animation != anim_name:
		sprite.play(anim_name)
	# Mainkan suara hanya jika belum berbunyi
	if not step.playing:
		step.play()

func play_idle_animation() -> void:
	var anim_name := "Idle_" + facing_direction
	if sprite.animation != anim_name:
		sprite.play(anim_name)
