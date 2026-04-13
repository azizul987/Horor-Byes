extends CharacterBody2D

const SPEED := 250.0

@onready var sprite: AnimatedSprite2D = $Player

var facing_direction := "down"

func _physics_process(delta: float) -> void:
	var input_x := Input.get_axis("ui_left", "ui_right")
	var input_y := Input.get_axis("ui_up", "ui_down")
	var input_vector := Vector2(input_x, input_y).normalized()

	velocity = input_vector * SPEED
	move_and_slide()

	if input_vector != Vector2.ZERO:
		update_facing_direction(input_vector)
		play_walk_animation()
	else:
		play_idle_animation()

func update_facing_direction(direction: Vector2) -> void:
	if abs(direction.x) > abs(direction.y):
		if direction.x > 0:
			facing_direction = "right"
		else:
			facing_direction = "left"
	else:
		if direction.y > 0:
			facing_direction = "down"
		else:
			facing_direction = "up"

func play_walk_animation() -> void:
	var anim_name := "Walk_" + facing_direction
	if sprite.animation != anim_name:
		sprite.play(anim_name)

func play_idle_animation() -> void:
	var anim_name := "Idle_" + facing_direction
	if sprite.animation != anim_name:
		sprite.play(anim_name)
