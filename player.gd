extends CharacterBody2D

const SPEED := 250.0

@onready var sprite: AnimatedSprite2D = $Player

var facing_direction := "down"
var is_hidden := false # --- BARU: Variabel status sembunyi

func _physics_process(delta: float) -> void:
	# --- BARU: Logika sembunyi dengan input "hide"
	if Input.is_action_pressed("hide"):
		is_hidden = true
		sprite.visible = false # Bikin hilang (invisible)
	else:
		is_hidden = false
		sprite.visible = true # Muncul kembali

	var input_x := Input.get_axis("ui_left", "ui_right")
	var input_y := Input.get_axis("ui_up", "ui_down")
	var input_vector := Vector2(input_x, input_y).normalized()

	velocity = input_vector * SPEED
	move_and_slide()

	# Mainkan animasi hanya jika sedang tidak sembunyi
	if input_vector != Vector2.ZERO:
		update_facing_direction(input_vector)
		if not is_hidden:
			play_walk_animation()
	else:
		if not is_hidden:
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
