extends CharacterBody2D

@export var pemain: CharacterBody2D
@export var tilemap: TileMapLayer
@export var speed: float = 55.0
@export var jarak_kejar: float = 70.0
@export var jarak_sampai: float = 4.0
@export var radius_dengar: float = 180.0

@onready var _Center_A: Marker2D = $"../Ruang A"
@onready var _Center_B: Marker2D = $"../Ruang B"
@onready var _Center_C: Marker2D = $"../Ruang C"
@onready var _Center_Lorong: Marker2D = $"../Lorong"

enum Mode { PATROLI, SELIDIKI, KEJAR }
var mode: Mode = Mode.PATROLI

var patrol_index: int = 0
var patrol_points: Array[Marker2D] = []

var path: Array[Vector2] = []
var last_pemain_cell: Vector2i = Vector2i(-9999, -9999)
var last_npc_cell: Vector2i = Vector2i(-9999, -9999)

func _ready() -> void:
	patrol_points = [_Center_A, _Center_B, _Center_C, _Center_Lorong]

# ─────────────────────────────────────────
# LOOP UTAMA
# ─────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if pemain == null or tilemap == null:
		return

	var pemain_cell = world_to_cell(pemain.global_position)
	var npc_cell    = world_to_cell(global_position)

	# Hitung ulang hanya saat ada yang berpindah tile
	if pemain_cell != last_pemain_cell or npc_cell != last_npc_cell:
		last_pemain_cell = pemain_cell
		last_npc_cell    = npc_cell
		_update_mode_and_path()

	# Gerak tile per tile
	if path.size() > 0:
		var target = path[0]
		global_position = global_position.move_toward(target, speed * delta)
		if global_position.distance_to(target) < jarak_sampai:
			path.remove_at(0)
			if path.size() == 0:
				global_position = target
	else:
		if mode == Mode.PATROLI:
			patrol_index = (patrol_index + 1) % patrol_points.size()
			_update_mode_and_path()

# ─────────────────────────────────────────
# LOGIKA MODE
# ─────────────────────────────────────────

func _update_mode_and_path() -> void:
	var jarak = global_position.distance_to(pemain.global_position)
	var target_world: Vector2

	if jarak <= jarak_kejar:
		mode = Mode.KEJAR
		target_world = pemain.global_position

	else:
		# Teorema Bayes: P(lokasi|bukti) = P(bukti|lokasi) * P(lokasi) / P(bukti)
		var prior      = bayes_prior()
		var likelihood = bayes_likelihood()
		var posterior  = bayes_posterior(prior, likelihood)
		var lokasi     = bayes_tertinggi(posterior)

		# Hanya SELIDIKI jika ada sinyal nyata DAN posterior cukup tinggi
		if bayes_ada_sinyal(likelihood) and posterior.get(lokasi, 0.0) >= 0.70:
			mode = Mode.SELIDIKI
			target_world = _marker_pos(lokasi)
		else:
			mode = Mode.PATROLI
			target_world = patrol_points[patrol_index].global_position

	var goal = get_nearest_free_cell(world_to_cell(target_world))
	path = bfs_path(global_position, cell_to_world(goal))

# ─────────────────────────────────────────
# TEOREMA BAYES
# ─────────────────────────────────────────

# P(lokasi) — lokasi patroli aktif diberi bobot lebih tinggi
func bayes_prior() -> Dictionary:
	var prior: Dictionary = {}
	var total := 0.0

	for lok in _markers().keys():
		prior[lok] = 2.0 if lok == _nama_patrol_aktif() else 1.0
		total += prior[lok]

	for lok in prior.keys():
		prior[lok] /= total  # normalisasi → jumlah = 1

	return prior

# P(bukti|lokasi) — seberapa kuat sinyal suara pemain ke tiap lokasi
# Likelihood TIDAK harus berjumlah 1, bukan distribusi probabilitas
func bayes_likelihood() -> Dictionary:
	var likelihood: Dictionary = {}

	for lok in _markers().keys():
		var d = pemain.global_position.distance_to(_markers()[lok])
		likelihood[lok] = max(0.01, 1.0 - d / radius_dengar)

	return likelihood

# Cek apakah setidaknya satu lokasi punya sinyal nyata (> floor 0.01)
func bayes_ada_sinyal(likelihood: Dictionary) -> bool:
	for lok in likelihood.keys():
		if likelihood[lok] > 0.01:
			return true
	return false

# P(lokasi|bukti) — hasil akhir Bayes, dinormalisasi → jumlah = 1
func bayes_posterior(prior: Dictionary, likelihood: Dictionary) -> Dictionary:
	var posterior: Dictionary = {}
	var p_bukti := 0.0

	for lok in prior.keys():
		posterior[lok] = likelihood.get(lok, 0.01) * prior[lok]
		p_bukti += posterior[lok]

	if p_bukti > 0.0:
		for lok in posterior.keys():
			posterior[lok] /= p_bukti  # normalisasi → jumlah = 1

	return posterior

# Ambil lokasi dengan nilai posterior tertinggi
func bayes_tertinggi(posterior: Dictionary) -> String:
	var best := ""
	var max_val := -1.0
	for lok in posterior.keys():
		if posterior[lok] > max_val:
			max_val = posterior[lok]
			best = lok
	return best

# ─────────────────────────────────────────
# HELPER
# ─────────────────────────────────────────

func _markers() -> Dictionary:
	return {
		"A":      _Center_A.global_position,
		"B":      _Center_B.global_position,
		"C":      _Center_C.global_position,
		"lorong": _Center_Lorong.global_position
	}

func _nama_patrol_aktif() -> String:
	match patrol_index:
		0: return "A"
		1: return "B"
		2: return "C"
		3: return "lorong"
	return "A"

func _marker_pos(nama: String) -> Vector2:
	return _markers().get(nama, global_position)

# ─────────────────────────────────────────
# BFS PATHFINDING
# ─────────────────────────────────────────

func bfs_path(start_world: Vector2, goal_world: Vector2) -> Array[Vector2]:
	var start = get_nearest_free_cell(world_to_cell(start_world))
	var goal  = get_nearest_free_cell(world_to_cell(goal_world))

	if start == goal:
		return []

	var queue:   Array[Vector2i] = [start]
	var visited: Dictionary = { start: true }
	var parent:  Dictionary = {}
	var dirs = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]

	while queue.size() > 0:
		var cur = queue.pop_front()
		if cur == goal:
			break
		for d in dirs:
			var nxt = cur + d
			if visited.has(nxt) or is_blocked(nxt):
				continue
			visited[nxt] = true
			parent[nxt]  = cur
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
	return tilemap.local_to_map(tilemap.to_local(pos))

func cell_to_world(cell: Vector2i) -> Vector2:
	return tilemap.to_global(tilemap.map_to_local(cell))
