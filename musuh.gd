extends CharacterBody2D

@export var pemain: CharacterBody2D
@export var tilemap: TileMapLayer
@export var speed: float = 55.0
@export var jarak_sampai: float = 4.0
@export var radius_dengar: float = 180.0

@export var label_debug: Label
@export var kamera: Camera2D
@export var debug_manual_move: bool = false
@export var debug_move_speed: float = 120.0
@export var zoom_step: float = 0.1
@export var zoom_min: float = 0.5
@export var zoom_max: float = 2.0

@onready var markers: Dictionary = {
	"A": ($"../Ruang A" as Marker2D).global_position,
	"B": ($"../Ruang B" as Marker2D).global_position,
	"C": ($"../Ruang C" as Marker2D).global_position,
	"lorong": ($"../Lorong" as Marker2D).global_position,
}

@onready var sprite: AnimatedSprite2D = $Musuh
var facing_direction := "down"

enum Mode { PATROLI, SELIDIKI}
var mode: Mode = Mode.PATROLI

var patrol_keys: Array = ["A", "B", "C", "lorong"]
var patrol_index: int = 0

var path: Array[Vector2] = []
var last_pemain_cell: Vector2i = Vector2i(-9999, -9999)
var last_npc_cell: Vector2i = Vector2i(-9999, -9999)

var _last_prior: Dictionary = {}
var _last_likelihood: Dictionary = {}
var _last_posterior: Dictionary = {}


func _ready() -> void:
	if label_debug:
		label_debug.visible = true

	print("=== DEBUG CONTROL ===")
	print("W A S D = gerak manual NPC saat debug_manual_move = true")
	print("Q = zoom out kamera")
	print("E = zoom in kamera")
	print("Z dipakai oleh player untuk hide")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			ubah_zoom(zoom_step)
		elif event.keycode == KEY_E:
			ubah_zoom(-zoom_step)


func _physics_process(delta: float) -> void:
	if pemain == null or tilemap == null:
		return

	if debug_manual_move:
		_debug_move_manual(delta)
		_update_mode_and_path()
		_update_label()
		return

	var pemain_cell = world_to_cell(pemain.global_position)
	var npc_cell = world_to_cell(global_position)

	if pemain_cell != last_pemain_cell or npc_cell != last_npc_cell:
		last_pemain_cell = pemain_cell
		last_npc_cell = npc_cell
		_update_mode_and_path()

	var is_moving = false
	var move_dir = Vector2.ZERO

	if path.size() > 0:
		var target = path[0]
		move_dir = (target - global_position).normalized()

		global_position = global_position.move_toward(target, speed * delta)
		is_moving = true

		if global_position.distance_to(target) < jarak_sampai:
			path.remove_at(0)
			if path.size() == 0:
				global_position = target
	elif mode == Mode.PATROLI:
		patrol_index = (patrol_index + 1) % patrol_keys.size()
		_update_mode_and_path()

	if is_moving and move_dir != Vector2.ZERO:
		update_facing_direction(move_dir)
		play_walk_animation()
	else:
		play_idle_animation()

	_update_label()


func _debug_move_manual(delta: float) -> void:
	var arah := Vector2.ZERO

	if Input.is_key_pressed(KEY_W):
		arah.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		arah.y += 1.0
	if Input.is_key_pressed(KEY_A):
		arah.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		arah.x += 1.0

	arah = arah.normalized()
	velocity = arah * debug_move_speed
	move_and_slide()

	if arah != Vector2.ZERO:
		update_facing_direction(arah)
		play_walk_animation()
	else:
		play_idle_animation()


func ubah_zoom(delta_zoom: float) -> void:
	if kamera == null:
		return

	var new_zoom_x = clamp(kamera.zoom.x + delta_zoom, zoom_min, zoom_max)
	var new_zoom_y = clamp(kamera.zoom.y + delta_zoom, zoom_min, zoom_max)
	kamera.zoom = Vector2(new_zoom_x, new_zoom_y)

	print("Zoom kamera: ", kamera.zoom)


func _update_mode_and_path() -> void:
	var target_world: Vector2

	var pemain_sembunyi = false
	if "is_hidden" in pemain:
		pemain_sembunyi = pemain.is_hidden


	_last_prior = bayes_prior()
	_last_likelihood = bayes_likelihood(pemain_sembunyi)
	_last_posterior = bayes_posterior(_last_prior, _last_likelihood)
	var lokasi = bayes_tertinggi(_last_posterior)

	if bayes_ada_sinyal(_last_likelihood) and _last_posterior[lokasi] >= 0.70:
		mode = Mode.SELIDIKI
		target_world = markers[lokasi]
	else:
		mode = Mode.PATROLI
		target_world = markers[patrol_keys[patrol_index]]

	path = bfs_path(global_position, cell_to_world(get_nearest_free_cell(world_to_cell(target_world))))


func _update_label() -> void:
	if label_debug == null:
		return

	var jarak = global_position.distance_to(pemain.global_position)
	var mode_nama = Mode.keys()[mode]

	var terdekat_nama := ""
	var terdekat_jarak := INF
	for lok in markers.keys():
		var d = pemain.global_position.distance_to(markers[lok])
		if d < terdekat_jarak:
			terdekat_jarak = d
			terdekat_nama = lok

	var teks := "MODE: %s\n" % mode_nama
	teks += "Debug Manual Move: %s\n" % str(debug_manual_move)
	teks += "Pos NPC: (%.0f, %.0f)\n" % [global_position.x, global_position.y]
	teks += "Pos Player: (%.0f, %.0f)\n" % [pemain.global_position.x, pemain.global_position.y]
	teks += "Jarak NPC ke Pemain: %.0f px\n" % jarak
	teks += "Pemain paling dekat ke: %s (%.0f px)\n" % [terdekat_nama, terdekat_jarak]

	if kamera != null:
		teks += "Zoom Kamera: %.2f\n" % kamera.zoom.x

	teks += "\n-- Hipotesis --\n"

	for lok in patrol_keys:
		var prior = "%.2f" % _last_prior.get(lok, 0.0)
		var like = "%.2f" % _last_likelihood.get(lok, 0.0)
		var post = "%.2f" % _last_posterior.get(lok, 0.0)
		var aktif = " <==" if lok == bayes_tertinggi(_last_posterior) else ""
		teks += "%s | P: %s  L: %s  Post: %s%s\n" % [lok.rpad(6), prior, like, post, aktif]

	teks += "\nKontrol Debug:\n"
	teks += "Q/E = zoom out/in\n"
	teks += "WASD = gerak manual saat debug_manual_move aktif\n"
	teks += "Z = hide player\n"

	label_debug.text = teks


func bayes_prior() -> Dictionary:
	var prior: Dictionary = {}
	var total := 0.0
	var patrol_aktif = patrol_keys[patrol_index]

	for lok in markers.keys():
		prior[lok] = 2.0 if lok == patrol_aktif else 1.0
		total += prior[lok]

	for lok in prior.keys():
		prior[lok] /= total
	return prior


func bayes_likelihood(pemain_sembunyi: bool = false) -> Dictionary:
	var likelihood: Dictionary = {}
	for lok in markers.keys():
		if pemain_sembunyi:
			likelihood[lok] = 0.01
		else:
			var d = pemain.global_position.distance_to(markers[lok])
			likelihood[lok] = max(0.01, 1.0 - d / radius_dengar)
	return likelihood


func bayes_ada_sinyal(likelihood: Dictionary) -> bool:
	for lok in likelihood.keys():
		if likelihood[lok] > 0.01:
			return true
	return false


func bayes_posterior(prior: Dictionary, likelihood: Dictionary) -> Dictionary:
	var posterior: Dictionary = {}
	var total := 0.0

	for lok in prior.keys():
		posterior[lok] = prior[lok] * likelihood[lok]
		total += posterior[lok]

	if total > 0.0:
		for lok in posterior.keys():
			posterior[lok] /= total
	return posterior


func bayes_tertinggi(posterior: Dictionary) -> String:
	var best := ""
	var max_val := -1.0
	for lok in posterior.keys():
		if posterior[lok] > max_val:
			max_val = posterior[lok]
			best = lok
	return best


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


func bfs_path(start_world: Vector2, goal_world: Vector2) -> Array[Vector2]:
	var start = get_nearest_free_cell(world_to_cell(start_world))
	var goal = get_nearest_free_cell(world_to_cell(goal_world))

	if start == goal:
		return []

	var queue: Array[Vector2i] = [start]
	var visited: Dictionary = {start: true}
	var parent: Dictionary = {}
	var dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	while queue.size() > 0:
		var cur = queue.pop_front()
		if cur == goal:
			break
		for d in dirs:
			var nxt = cur + d
			if visited.has(nxt) or is_blocked(nxt):
				continue
			visited[nxt] = true
			parent[nxt] = cur
			queue.append(nxt)

	if not visited.has(goal):
		return []

	var result: Array[Vector2] = []
	var step = goal
	while step != start:
		result.push_front(cell_to_world(step))
		if not parent.has(step):
			break
		step = parent[step]
	return result


func get_nearest_free_cell(target: Vector2i) -> Vector2i:
	if not is_blocked(target):
		return target
	for radius in range(1, 5):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				var c = target + Vector2i(dx, dy)
				if not is_blocked(c):
					return c
	return target


func is_blocked(cell: Vector2i) -> bool:
	if tilemap.get_cell_source_id(cell) == -1:
		return true
	var data = tilemap.get_cell_tile_data(cell)
	if data == null:
		return true
	return data.get_custom_data("blocked") == true


func world_to_cell(pos: Vector2) -> Vector2i:
	return tilemap.local_to_map(pos)


func cell_to_world(cell: Vector2i) -> Vector2:
	return tilemap.to_global(tilemap.map_to_local(cell))
