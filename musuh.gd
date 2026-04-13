extends CharacterBody2D

@export var pemain: CharacterBody2D

@onready var _Center_A: Marker2D = $"../Ruang A"
@onready var _Center_B: Marker2D = $"../Ruang B"
@onready var _Center_C: Marker2D = $"../Ruang C"
@onready var _Center_Lorong: Marker2D = $"../Lorong"

var prior: Dictionary = {}
var likelihood_dengar: Dictionary = {}

func _process(_delta: float) -> void:
	if pemain == null:
		return

	prior = hitung_prior_dari_posisi()
	likelihood_dengar = hitung_likelihood_dengar_dari_posisi(300.0)

	var evidence_aktif = {
		"dengar": true
	}

	var likelihoods = {
		"dengar": likelihood_dengar
	}

	var posterior = naive_bayes(prior, likelihoods, evidence_aktif)
	var lokasi_target = get_lokasi_tertinggi(posterior)

	print("=== PRIOR ===")
	for lokasi in prior.keys():
		print(lokasi, ": ", prior[lokasi])

	print("=== LIKELIHOOD DENGAR ===")
	for lokasi in likelihood_dengar.keys():
		print(lokasi, ": ", likelihood_dengar[lokasi])

	print("=== POSTERIOR ===")
	for lokasi in posterior.keys():
		print(lokasi, ": ", posterior[lokasi])

	print("Lokasi paling mungkin: ", lokasi_target)


func hitung_prior_dari_posisi() -> Dictionary:
	var markers = {
		"A": _Center_A.global_position,
		"B": _Center_B.global_position,
		"C": _Center_C.global_position,
		"lorong": _Center_Lorong.global_position
	}

	var score = {}
	var total = 0.0
	var epsilon = 0.001

	for lokasi in markers.keys():
		var d = pemain.global_position.distance_to(markers[lokasi])
		var s = 1.0 / (d + epsilon)
		score[lokasi] = s
		total += s

	var hasil = {}
	if total > 0.0:
		for lokasi in score.keys():
			hasil[lokasi] = score[lokasi] / total

	return hasil


func hitung_likelihood_dengar_dari_posisi(radius_dengar: float) -> Dictionary:
	var markers = {
		"A": _Center_A.global_position,
		"B": _Center_B.global_position,
		"C": _Center_C.global_position,
		"lorong": _Center_Lorong.global_position
	}

	var hasil = {}

	for lokasi in markers.keys():
		var d = pemain.global_position.distance_to(markers[lokasi])

		# Makin dekat ke marker, makin besar peluang terdengar
		var p = max(0.0, 1.0 - (d / radius_dengar))

		# Biar tidak nol total semua
		p = max(p, 0.01)

		hasil[lokasi] = p

	return hasil


func naive_bayes(prior_data: Dictionary, likelihoods: Dictionary, evidence: Dictionary) -> Dictionary:
	var hasil = {}
	var total = 0.0

	for lokasi in prior_data.keys():
		var nilai = prior_data[lokasi]

		for nama_evidence in evidence.keys():
			if evidence[nama_evidence] == true:
				if likelihoods.has(nama_evidence) and likelihoods[nama_evidence].has(lokasi):
					nilai *= likelihoods[nama_evidence][lokasi]

		hasil[lokasi] = nilai
		total += nilai

	if total > 0.0:
		for lokasi in hasil.keys():
			hasil[lokasi] = hasil[lokasi] / total

	return hasil


func get_lokasi_tertinggi(data: Dictionary) -> String:
	var lokasi_terbaik = ""
	var nilai_tertinggi = -1.0

	for lokasi in data.keys():
		if data[lokasi] > nilai_tertinggi:
			nilai_tertinggi = data[lokasi]
			lokasi_terbaik = lokasi

	return lokasi_terbaik
