
extends Control

# Node References
@onready var board = $VBoxContainer/BoardCenter/Board
@onready var size_option = $VBoxContainer/Controls/SizeOption
@onready var season_option = $VBoxContainer/Controls/SeasonOption
@onready var shuffle_btn = $VBoxContainer/Controls/ShuffleBtn
@onready var reset_btn = $VBoxContainer/Controls/ResetBtn
@onready var moves_label = $VBoxContainer/Stats/MovesLabel
@onready var time_label = $VBoxContainer/Stats/TimeLabel
@onready var win_label = $VBoxContainer/WinLabel
@onready var timer = $Timer
@onready var background = $Background
@onready var weather_particles = $CPUParticles2D
@onready var move_sound = $MoveSound
@onready var season_sound = $SeasonSound

# Game State
var grid_size: int = 3
var grid_array: Array = []
var moves_count: int = 0
var seconds_elapsed: int = 0
var game_started: bool = false
var empty_pos: Vector2i = Vector2i.ZERO


func _ready():
	randomize()

	size_option.clear()
	size_option.add_item("3 x 3")
	size_option.add_item("4 x 4")
	size_option.add_item("5 x 5")

	season_option.clear()
	season_option.add_item("🌧️ Hujan")
	season_option.add_item("🍂 Gugur")
	season_option.add_item("❄️ Salju")

	size_option.item_selected.connect(_on_size_changed)
	season_option.item_selected.connect(_on_season_changed)
	shuffle_btn.pressed.connect(_on_shuffle_pressed)
	reset_btn.pressed.connect(_on_reset_pressed)
	timer.timeout.connect(_on_timer_timeout)

	# Siapkan suara gerakan
	if ResourceLoader.exists("res://move.wav"):
		move_sound.stream = load("res://move.wav")
		move_sound.volume_db = 0.0
		move_sound.bus = "Master"
	else:
		push_warning("File move.wav tidak ditemukan")

	# Mulai game dengan musim hujan
	season_option.select(0)
	_on_season_changed(0)
	shuffle_board()


func start_new_game():
	timer.stop()
	seconds_elapsed = 0
	moves_count = 0
	game_started = false
	win_label.text = ""
	update_ui_stats()
	create_board()


func create_board():
	for child in board.get_children():
		board.remove_child(child)
		child.queue_free()

	board.columns = grid_size
	grid_array.clear()

	var total_tiles = grid_size * grid_size

	for i in range(total_tiles):
		var row = int(i / grid_size)
		var col = i % grid_size

		if i == total_tiles - 1:
			grid_array.append(null)
			empty_pos = Vector2i(col, row)
		else:
			var tile_btn = Button.new()
			var val = i + 1

			tile_btn.text = str(val)
			tile_btn.custom_minimum_size = Vector2(70, 70)
			tile_btn.add_theme_font_size_override("font_size", 22)
			tile_btn.pressed.connect(_on_tile_clicked.bind(val))

			board.add_child(tile_btn)
			grid_array.append(val)


func _on_tile_clicked(val: int):
	var index = grid_array.find(val)
	if index == -1:
		return

	var tile_pos = Vector2i(
		index % grid_size,
		int(index / grid_size)
	)

	if not is_adjacent(tile_pos, empty_pos):
		return

	if not game_started:
		game_started = true
		timer.start()

	var empty_index = empty_pos.y * grid_size + empty_pos.x
	grid_array[empty_index] = val
	grid_array[index] = null
	empty_pos = tile_pos

	moves_count += 1

	if is_instance_valid(move_sound) and move_sound.stream != null:
		move_sound.play()

	update_ui_stats()
	render_board()
	check_win()


func render_board():
	for child in board.get_children():
		board.remove_child(child)
		child.queue_free()

	for val in grid_array:
		if val != null:
			var btn = Button.new()
			btn.text = str(val)
			btn.custom_minimum_size = Vector2(70, 70)
			btn.add_theme_font_size_override("font_size", 22)
			btn.pressed.connect(_on_tile_clicked.bind(val))
			board.add_child(btn)
		else:
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(70, 70)
			board.add_child(spacer)


func is_adjacent(pos1: Vector2i, pos2: Vector2i) -> bool:
	var diff = pos1 - pos2
	return (
		(abs(diff.x) == 1 and diff.y == 0)
		or (abs(diff.y) == 1 and diff.x == 0)
	)


func _on_shuffle_pressed():
	shuffle_board()


# Shuffle melalui gerakan legal agar puzzle tetap solvable
func shuffle_board():
	start_new_game()

	var steps = grid_size * 30
	var previous_empty = Vector2i(-999, -999)

	for i in range(steps):
		var valid_neighbors: Array[int] = []

		for idx in range(grid_array.size()):
			if grid_array[idx] == null:
				continue

			var pos = Vector2i(
				idx % grid_size,
				int(idx / grid_size)
			)

			if is_adjacent(pos, empty_pos) and pos != previous_empty:
				valid_neighbors.append(idx)

		if valid_neighbors.is_empty():
			for idx in range(grid_array.size()):
				if grid_array[idx] == null:
					continue

				var pos = Vector2i(
					idx % grid_size,
					int(idx / grid_size)
				)

				if is_adjacent(pos, empty_pos):
					valid_neighbors.append(idx)

		if not valid_neighbors.is_empty():
			var idx: int = valid_neighbors.pick_random()
			var empty_index = empty_pos.y * grid_size + empty_pos.x

			grid_array[empty_index] = grid_array[idx]
			grid_array[idx] = null

			previous_empty = Vector2i(
				idx % grid_size,
				int(idx / grid_size)
			)
			empty_pos = previous_empty

	render_board()


func _on_reset_pressed():
	start_new_game()


func check_win():
	var total = grid_size * grid_size

	for i in range(total - 1):
		if grid_array[i] != i + 1:
			return

	timer.stop()
	game_started = false
	win_label.text = "🎉 Selamat! Anda Menang!"


func _on_timer_timeout():
	seconds_elapsed += 1
	update_ui_stats()


func update_ui_stats():
	moves_label.text = "Gerakan: " + str(moves_count)

	var mins = int(seconds_elapsed / 60)
	var secs = seconds_elapsed % 60
	time_label.text = "Waktu: %02d:%02d" % [mins, secs]


# Memilih ukuran langsung mengacak papan
func _on_size_changed(index: int):
	grid_size = index + 3
	shuffle_board()


# Pengaturan tema dan audio setiap musim
func _on_season_changed(index: int):
	match index:
		0:
			background.color = Color("#1e293b")
			weather_particles.emitting = true
			weather_particles.direction = Vector2(0.2, 1)
			weather_particles.color = Color("#38bdf8")
			weather_particles.amount = 100
			_play_season_sound("res://season_rain.wav")

		1:
			background.color = Color("#451a03")
			weather_particles.emitting = true
			weather_particles.direction = Vector2(-0.5, 1)
			weather_particles.color = Color("#f97316")
			weather_particles.amount = 30
			_play_season_sound("res://season_autumn.wav")

		2:
			background.color = Color("#0f172a")
			weather_particles.emitting = true
			weather_particles.direction = Vector2(0, 1)
			weather_particles.color = Color("#ffffff")
			weather_particles.amount = 60
			_play_season_sound("res://season_snow.wav")


# Koneksi pemutar suara musim
func _play_season_sound(path: String):
	if not is_instance_valid(season_sound):
		push_error("Node SeasonSound tidak ditemukan!")
		return

	season_sound.stop()

	if not ResourceLoader.exists(path):
		season_sound.stream = null
		push_error("File audio tidak ditemukan: " + path)
		return

	var audio_stream = load(path) as AudioStream

	if audio_stream == null:
		push_error("Audio gagal dimuat: " + path)
		return

	season_sound.stream = audio_stream
	season_sound.bus = "Master"
	season_sound.volume_db = 6.0

	if audio_stream is AudioStreamWAV:
		audio_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif audio_stream is AudioStreamOggVorbis:
		audio_stream.loop = true
	elif audio_stream is AudioStreamMP3:
		audio_stream.loop = true

	season_sound.play()

	print("File musim: ", path)
	print("Audio bermain: ", season_sound.playing)
	print("Volume musim: ", season_sound.volume_db)
