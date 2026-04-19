extends Node3D

## Bonus level: endless wave defense. Protect L from M enemies.

@export var use_physical_tail: bool = false
@export var spawn_interval: float = 4.0
@export var spawn_interval_min: float = 1.5
@export var spawn_speedup: float = 0.95
@export var enemy_move_speed: float = 4.0
@export var enemy_speed_max: float = 12.0
@export var enemy_speed_ramp: float = 120.0  ## seconds to reach max speed

@onready var signal_manager: Node = $SignalManager
@onready var player_emoji: Node = $Player/Emoji
@onready var cutscene_bars: Node = $CutsceneBars

@onready var _bgm_main: AudioStreamPlayer = $BGMMain
@onready var _bgm_ending: AudioStreamPlayer = $BGMEnding
@onready var _sfx_button: AudioStreamPlayer = $SFXButton

var _enemy_scene: PackedScene = preload("res://scene/ginnie2.tscn")
var _swipeable_script: Script = preload("res://other_scripts/swipeable.gd")

var _game_started: bool = false
var _game_over: bool = false
var _elapsed_time: float = 0.0
var _spawn_timer: float = 0.0
var _current_interval: float = 4.0
var _l_node: Node3D
var _timer_label: Label

## Spawn positions (from M1-M4 in scene)
var _spawn_positions: Array[Vector3] = [
	Vector3(-6.734573, -0.12096977, 25.73685),
	Vector3(-6.734573, -0.12096977, 28.954723),
	Vector3(-6.734573, -0.12096977, 32.575478),
	Vector3(-6.734573, -0.12096977, 35.78226),
]


func _ready() -> void:
	set_tail_mode(use_physical_tail)
	_setup_bgm()

	signal_manager.vibe_changed.connect(_on_vibe_changed)
	signal_manager.vibe_expired.connect(_on_vibe_expired)
	signal_manager.signal_triggered.connect(_on_signal_triggered)
	signal_manager.shape_recognized.connect(_on_shape_recognized)
	signal_manager.shape_unrecognized.connect(_on_shape_unrecognized)

	_l_node = $L
	_current_interval = spawn_interval

	# Remove the static M1-M4 from scene (we spawn dynamically)
	for name in ["M1", "M2", "M3", "M4"]:
		var node := get_node_or_null(name)
		if node:
			node.queue_free()

	_create_timer_label()
	_show_start_screen()


func _create_timer_label() -> void:
	_timer_label = Label.new()
	_timer_label.anchors_preset = Control.PRESET_CENTER_TOP
	_timer_label.anchor_left = 0.5
	_timer_label.anchor_right = 0.5
	_timer_label.anchor_top = 0.0
	_timer_label.offset_left = -100.0
	_timer_label.offset_right = 100.0
	_timer_label.offset_top = 20.0
	_timer_label.offset_bottom = 60.0
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var settings := LabelSettings.new()
	settings.font_size = 36
	settings.font_color = Color.WHITE
	settings.outline_size = 4
	settings.outline_color = Color.BLACK
	_timer_label.label_settings = settings
	_timer_label.text = "0.0s"
	_timer_label.visible = false

	# Add to a CanvasLayer so it renders on top
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)
	canvas.add_child(_timer_label)


func _show_start_screen() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$Player.mouse_input_enabled = false
	$Player.set_physics_process(false)
	$Player/ginnie/Tail.visible = false
	$PauseMenu.enabled = false
	var start_slider: HSlider = $StartCanvas/VolumeContainer/VolumeSlider
	start_slider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")))
	start_slider.value_changed.connect(func(v: float) -> void:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(v))
	)
	var start_btn: TextureButton = $StartCanvas/StartButton
	_setup_start_button_hover(start_btn)
	start_btn.pressed.connect(func() -> void:
		await get_tree().create_timer(0.5).timeout
		get_tree().change_scene_to_file("res://Levels/main/main.tscn")
	)

	var bonus_btn: TextureButton = $StartCanvas/BonusButton
	_setup_start_button_hover(bonus_btn)
	bonus_btn.pressed.connect(_on_start)


func _setup_start_button_hover(btn: TextureButton) -> void:
	btn.pivot_offset = btn.size / 2.0
	btn.mouse_entered.connect(func() -> void:
		var tw := btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(1.2, 1.2), 0.15)
	)
	btn.mouse_exited.connect(func() -> void:
		var tw := btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15)
	)
	btn.button_down.connect(func() -> void:
		_sfx_button.play()
		var tw := btn.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(0.9, 0.9), 0.08)
	)
	btn.button_up.connect(func() -> void:
		var tw := btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(1.2, 1.2), 0.1)
	)


func _on_start() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	$Player.mouse_input_enabled = true
	$Player.set_physics_process(true)
	$Player/ginnie/Tail.visible = true
	$StartCanvas.queue_free()
	$StartCam.priority = 0
	$Playground2Cam.priority = 10

	$PauseMenu.enabled = true
	$PauseMenu.enable_exit("res://Levels/main/main.tscn")
	_game_started = true
	_timer_label.visible = true

	await get_tree().create_timer(0.5).timeout
	_play_bgm("main")

func _process(delta: float) -> void:
	if not _game_started or _game_over:
		return

	_elapsed_time += delta
	_timer_label.text = "%.1fs" % _elapsed_time
	# ====== TODO: _update_sunset()

	# Spawn enemies — count increases over time
	_spawn_timer += delta
	if _spawn_timer >= _current_interval:
		_spawn_timer = 0.0
		var spawn_count: int = 1 + int(_elapsed_time / 30.0)  # +1 every 30s
		for n in spawn_count:
			_spawn_enemy()
		_current_interval = maxf(_current_interval * spawn_speedup, spawn_interval_min)

	# Check if any enemy reached L
	_check_enemies_reached_l()


func _spawn_enemy() -> void:
	var pos: Vector3 = _spawn_positions[randi() % _spawn_positions.size()]
	# Add some randomness
	pos.x += randf_range(-2.0, 2.0)
	pos.z += randf_range(-2.0, 2.0)

	var enemy: RigidBody3D = _enemy_scene.instantiate()
	enemy.freeze = true
	enemy.position = pos
	enemy.add_to_group("wave_enemy")

	# Add swipeable
	var swipeable := Area3D.new()
	swipeable.set_script(_swipeable_script)
	swipeable.set("boom_on_swipe", true)
	swipeable.set("destroy_delay", 3.0)
	enemy.add_child(swipeable)

	add_child(enemy)
	enemy.global_position = pos


func _check_enemies_reached_l() -> void:
	if not _l_node:
		return
	var l_pos := _l_node.global_position
	for node in get_tree().get_nodes_in_group("wave_enemy"):
		if not is_instance_valid(node):
			continue
		var enemy: RigidBody3D = node as RigidBody3D
		if not enemy or not enemy.freeze:
			continue
		var dist: float = enemy.global_position.distance_to(l_pos)
		if dist <= 2.0:
			_game_over = true
			_on_game_over()
			return
		# Move enemy toward L — speed ramps over time
		var speed_t: float = clampf(_elapsed_time / enemy_speed_ramp, 0.0, 1.0)
		var current_speed: float = lerpf(enemy_move_speed, enemy_speed_max, speed_t)
		var dir: Vector3 = (l_pos - enemy.global_position).normalized()
		dir.y = 0.0
		enemy.position += dir * current_speed * get_process_delta_time()
		# Face movement direction
		if dir.length_squared() > 0.01:
			var target_y := atan2(dir.x, dir.z) + PI
			enemy.global_rotation.y = target_y


func _on_game_over() -> void:
	_play_bgm("ending")
	$EndingCanvas.show_ending()
	$Player.set_process(false)
	$Player.set_physics_process(false)
	$Player.set_process_unhandled_input(false)


# ===== Sunset ===== NOT IN USE

## Sunset transition duration in seconds
@export var sunset_duration: float = 120.0

# Day colors
const _SKY_TOP_DAY := Color(0.35, 0.55, 0.85)
const _SKY_HORIZON_DAY := Color(0.65, 0.78, 0.9)
const _LIGHT_COLOR_DAY := Color(1.0, 1.0, 1.0)
const _LIGHT_ENERGY_DAY := 1.0
# Sunset colors
const _SKY_TOP_SUNSET := Color(0.15, 0.1, 0.35)
const _SKY_HORIZON_SUNSET := Color(0.95, 0.4, 0.15)
const _LIGHT_COLOR_SUNSET := Color(1.0, 0.55, 0.25)
const _LIGHT_ENERGY_SUNSET := 0.7

func _update_sunset() -> void:
	var t: float = clampf(_elapsed_time / sunset_duration, 0.0, 1.0)
	# Ease-in for a slow start, accelerating toward the end
	t = t * t

	var sky_mat: ProceduralSkyMaterial = $SubViewportContainer/SubViewport/WorldEnvironment.environment.sky.sky_material
	sky_mat.sky_top_color = _SKY_TOP_DAY.lerp(_SKY_TOP_SUNSET, t)
	sky_mat.sky_horizon_color = _SKY_HORIZON_DAY.lerp(_SKY_HORIZON_SUNSET, t)
	sky_mat.ground_bottom_color = _SKY_TOP_DAY.lerp(_SKY_TOP_SUNSET, t)
	sky_mat.ground_horizon_color = _SKY_HORIZON_DAY.lerp(_SKY_HORIZON_SUNSET, t)

	var light: DirectionalLight3D = $DirectionalLight3D
	light.light_color = _LIGHT_COLOR_DAY.lerp(_LIGHT_COLOR_SUNSET, t)
	light.light_energy = lerpf(_LIGHT_ENERGY_DAY, _LIGHT_ENERGY_SUNSET, t)


# ===== Tail mode =====

func set_tail_mode(physical: bool) -> void:
	use_physical_tail = physical
	var physical_tail := $PhysicalTail
	var visual_tail := $Player/ginnie/Tail

	if physical:
		physical_tail.teleport_to_player()
		physical_tail.visible = true
		physical_tail.set_physics_process(true)
		physical_tail.set_process(true)
		_set_tail_collision(physical_tail, true)
		visual_tail.visible = false
		visual_tail.set_physics_process(false)
		visual_tail.set_process(false)
	else:
		physical_tail.visible = false
		physical_tail.set_physics_process(false)
		physical_tail.set_process(false)
		_set_tail_collision(physical_tail, false)
		visual_tail.visible = true
		visual_tail.set_physics_process(true)
		visual_tail.set_process(true)


func _set_tail_collision(tail_root: Node, enabled: bool) -> void:
	for child in tail_root.get_children():
		if child is RigidBody3D:
			child.set_deferred("freeze", not enabled)


# ===== BGM =====

func _setup_bgm() -> void:
	_bgm_main.bus = "BGM"
	_bgm_ending.bus = "BGM"
	_bgm_main.process_mode = Node.PROCESS_MODE_ALWAYS
	_bgm_ending.process_mode = Node.PROCESS_MODE_ALWAYS
	_bgm_main.finished.connect(_bgm_main.play)
	_bgm_ending.finished.connect(_bgm_ending.play)
	
	_sfx_button.bus = "SFX"
	_sfx_button.stream = preload("res://audio/short_piano5.wav")


func _play_bgm(which: String) -> void:
	_bgm_main.stop()
	_bgm_ending.stop()
	if which == "main":
		_bgm_main.play()
	elif which == "ending":
		_bgm_ending.play()


# ===== Signal handlers =====

var _default_emoji_scale: Vector3 = Vector3.ZERO
var _extra_tail: Node3D = null
var _physical_tail_scene: PackedScene = preload("res://scene/physical_tail.tscn")

func _on_vibe_changed(vibe_name: String) -> void:
	var was_upgraded: bool = player_emoji and player_emoji.upgraded
	if vibe_name == "star":
		set_tail_mode(true)
		if was_upgraded:
			_spawn_extra_tail()
	if player_emoji:
		player_emoji.upgraded = (vibe_name == "triangle")
	if vibe_name == "triangle" and player_emoji:
		if _default_emoji_scale == Vector3.ZERO:
			_default_emoji_scale = player_emoji.target_scale
		player_emoji.target_scale = Vector3(7, 7, 7)
		player_emoji.scale = player_emoji.target_scale


func _on_vibe_expired() -> void:
	_remove_extra_tail()
	set_tail_mode(false)
	if player_emoji:
		player_emoji.upgraded = false
	if player_emoji and _default_emoji_scale != Vector3.ZERO:
		player_emoji.target_scale = _default_emoji_scale
		player_emoji.scale = _default_emoji_scale


func _spawn_extra_tail() -> void:
	if _extra_tail:
		return
	_extra_tail = _physical_tail_scene.instantiate()
	_extra_tail.player = $Player
	_extra_tail.position = $Player.global_position
	_extra_tail.tube_color = $PhysicalTail.tube_color.darkened(0.2)
	add_child(_extra_tail)
	_extra_tail.teleport_to_player()
	_set_tail_collision(_extra_tail, true)


func _remove_extra_tail() -> void:
	if _extra_tail:
		_extra_tail.queue_free()
		_extra_tail = null


func _on_signal_triggered(vibe_name: String, signal_name: String) -> void:
	pass


func _on_shape_recognized(shape_name: String, shape_type: String) -> void:
	if player_emoji:
		var emoji_frame: int = player_emoji.SHAPE_EMOJI.get(shape_name, 5)
		player_emoji.flash_emoji(emoji_frame, player_emoji.flash_duration)


func _on_shape_unrecognized() -> void:
	if player_emoji:
		player_emoji.flash_emoji(5, 1.0)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T:
			set_tail_mode(not use_physical_tail)
