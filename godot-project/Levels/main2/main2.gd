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

@onready var rock_launcher: Node = $RockLauncher
var rock_packed: PackedScene = preload("res://scene/rock.tscn")
@onready var target_scene: Node3D = $Target

var _enemy_scene: PackedScene = preload("res://scene/ginnie2.tscn")
var _swipeable_script: Script = preload("res://other_scripts/swipeable.gd")
var _boom_scene: PackedScene = preload("res://scene/boom.tscn")

var _game_started: bool = false
var _game_over: bool = false
var _elapsed_time: float = 0.0
var _spawn_timer: float = 0.0
var _current_interval: float = 4.0
var _l_node: Node3D
var _lover_node: Node3D
@onready var _timer_label: Label = $TimerCanvas/TimerLabel
var _last_knockback_time: float = 0.0
var _rock_timer: float = 0.0
var _rock_interval: float = 5.0
var _rock_delay: float = 10.0
var _rock_started: bool = false
var _spawn_positions: Array[Vector3] = [
	Vector3(-6.734573, -0.12096977, 25.73685),
	Vector3(-6.734573, -0.12096977, 28.954723),
	Vector3(-6.734573, -0.12096977, 32.575478),
	Vector3(-6.734573, -0.12096977, 35.78226),
]


func _ready() -> void:
	set_tail_mode(use_physical_tail)
	_setup_bgm()
	_setup_lover()
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

	# Remove template rock from scene tree
	$Rock.queue_free()

	_timer_label.visible = false
	_show_start_screen()

	# Rocks will be launched in _process after start

# no longer created dynamically; referenced from scene tree

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
		SceneManager.set_transition_scene(preload("res://scene/UI/Transition.tscn"))
		var fade_out := SceneManager.create_options(1.0, "crooked_tiles")
		var fade_in := SceneManager.create_options(1.0, "crooked_tiles")
		var general := SceneManager.create_general_options(Color.BLACK, 0.5, false, false)
		await get_tree().create_timer(0.5).timeout
		await SceneManager.change_scene("main", fade_out, fade_in, general)

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
	$PauseMenu.enable_exit("res://Levels/main2/main2.tscn")
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

	# Launch rocks: wait 10s after start, then every 5s
	if not _rock_started:
		if _elapsed_time >= _rock_delay:
			_rock_started = true
			_rock_timer = 0.0
			launch_rock($Player.global_position)
	else:
		_rock_timer += delta
		if _rock_timer >= _rock_interval:
			_rock_timer = 0.0
			launch_rock($Player.global_position)

	# Spawn enemies — count increases over time
	_spawn_timer += delta
	if _spawn_timer >= _current_interval:
		_spawn_timer = 0.0
		var spawn_count: int = 1 + int(_elapsed_time / 30.0)  # +1 every 30s
		for n in spawn_count:
			_spawn_enemy()
		_current_interval = maxf(_current_interval * spawn_speedup, spawn_interval_min)

	# Knockback player if too close to enemies
	_check_player_knockback()

	# Check if any enemy reached L
	_check_enemies_reached_l()

	# Lover always faces the player
	_update_lover_facing()


func _check_player_knockback() -> void:
	if _elapsed_time - _last_knockback_time < 1.0:
		return
	var player_pos = $Player.global_position
	for node in get_tree().get_nodes_in_group("wave_enemy"):
		if not is_instance_valid(node):
			continue
		var enemy: RigidBody3D = node
		var dist = enemy.global_position.distance_to(player_pos)
		if dist <= 2:  # knockback radius
			_last_knockback_time = _elapsed_time
			var dir = (player_pos - enemy.global_position).normalized()
			$Player.bounce(dir)
			enemy.get_node("Emoji").flash_emoji(4)
			break  # only one knockback per frame


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
		if enemy.is_in_group("stunned"):
			# Face the player while stunned
			var to_player: Vector3 = $Player.global_position - enemy.global_position
			to_player.y = 0.0
			if to_player.length_squared() > 0.01:
				enemy.global_rotation.y = atan2(to_player.x, to_player.z) + PI
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
var _extra_tails: Array[Node3D] = []
const _MAX_EXTRA_TAILS: int = 10
var _physical_tail_scene: PackedScene = preload("res://scene/physical_tail.tscn")

func _on_vibe_changed(vibe_name: String) -> void:
	if vibe_name == "star":
		set_tail_mode(true)
	if vibe_name == "triangle":
		if use_physical_tail:
			_spawn_extra_tail()
		if player_emoji:
			player_emoji.upgraded = true
			if _default_emoji_scale == Vector3.ZERO:
				_default_emoji_scale = player_emoji.target_scale
			player_emoji.target_scale = Vector3(7, 7, 7)
			player_emoji.scale = player_emoji.target_scale
	else:
		if player_emoji:
			player_emoji.upgraded = false


func _on_vibe_expired() -> void:
	_remove_all_extra_tails()
	set_tail_mode(false)
	if player_emoji:
		player_emoji.upgraded = false
	if player_emoji and _default_emoji_scale != Vector3.ZERO:
		player_emoji.target_scale = _default_emoji_scale
		player_emoji.scale = _default_emoji_scale


func _spawn_extra_tail() -> void:
	if _extra_tails.size() >= _MAX_EXTRA_TAILS:
		return
	var tail: Node3D = _physical_tail_scene.instantiate()
	tail.player = $Player
	tail.position = $Player.global_position
	var darken: float = 0.1 + 0.05 * _extra_tails.size()
	tail.tube_color = $PhysicalTail.tube_color.darkened(darken)
	add_child(tail)
	tail.teleport_to_player()
	_set_tail_collision(tail, true)
	_extra_tails.append(tail)

func launch_rock(target_pos: Vector3) -> void:
	# Spawn target indicator at landing position
	var target: Sprite3D = target_scene.duplicate() as Sprite3D
	add_child(target)
	target.global_position = Vector3(target_pos.x, 0.05, target_pos.z)
	target.global_rotation = Vector3(-PI / 2.0, 0.0, 0.0)
	target.visible = true

	# Blink the target indicator
	var tw := create_tween()
	for i in 6:
		tw.tween_property(target, "modulate:a", 0.2, 0.15)
		tw.tween_property(target, "modulate:a", 1.0, 0.15)
	tw.tween_callback(func() -> void:
		target.queue_free()
		if _game_over:
			return

		# Launch rock with ballistic trajectory to land at target_pos
		var rock_instance: RigidBody3D = rock_packed.instantiate() as RigidBody3D
		rock_instance.freeze = true
		rock_instance.gravity_scale = 1.0
		rock_instance.contact_monitor = true
		rock_instance.max_contacts_reported = 3
		# Add swipeable
		var swipeable := Area3D.new()
		swipeable.set_script(_swipeable_script)
		swipeable.set("boom_on_swipe", true)
		swipeable.set("destroy_delay", 2.0)
		rock_instance.add_child(swipeable)
		add_child(rock_instance)
		rock_instance.global_position = rock_launcher.global_position

		var start: Vector3 = rock_instance.global_position
		var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
		var land_pos: Vector3 = Vector3(target_pos.x, 0.0, target_pos.z)

		# Calculate initial velocity for ballistic arc
		# Use fixed flight time, solve for required velocity
		var flight_time: float = 0.8
		var displacement: Vector3 = land_pos - start
		var dx: Vector3 = Vector3(displacement.x, 0.0, displacement.z)
		# vx = dx / t, vy = (dy + 0.5*g*t^2) / t
		var vx: Vector3 = dx / flight_time
		var vy: float = (displacement.y + 0.5 * gravity * flight_time * flight_time) / flight_time
		var launch_velocity: Vector3 = vx + Vector3.UP * vy

		rock_instance.freeze = false
		# Use impulse instead of linear_velocity for reliable launch
		rock_instance.apply_central_impulse(launch_velocity * rock_instance.mass)
		print("Rock launch: start=%s target=%s vel=%s gravity=%.1f" % [start, land_pos, launch_velocity, gravity])

		# Connect to detect landing
		rock_instance.body_entered.connect(_on_rock_landed.bind(rock_instance))
	)


func _on_rock_landed(body: Node, rock: RigidBody3D) -> void:
	print("Rock landed on: ", body.name)
	# Always check distance to player on any collision
	var dist: float = rock.global_position.distance_to($Player.global_position)
	print("Rock dist to player: ", dist)
	if dist <= 1.5:
		_game_over = true
		_on_game_over()
		return
	# Freeze rock in place until swipe unfreezes it
	if body is StaticBody3D:
		rock.freeze = true
		rock.linear_velocity = Vector3.ZERO
		rock.angular_velocity = Vector3.ZERO
		# Spawn boom effect at landing position
		var boom := _boom_scene.instantiate()
		add_child(boom)
		boom.global_position = rock.global_position
		if rock.body_entered.is_connected(_on_rock_landed):
			rock.body_entered.disconnect(_on_rock_landed)


func _setup_lover() -> void:
	if Global.get_param("lover") == "F":
		$L.visible = false
		$F.visible = true
		_lover_node = $F
	else:
		_lover_node = $L

func _remove_all_extra_tails() -> void:
	for tail in _extra_tails:
		if is_instance_valid(tail):
			tail.queue_free()
	_extra_tails.clear()


func _update_lover_facing() -> void:
	if not _lover_node or not is_instance_valid(_lover_node):
		return
	var player_pos: Vector3 = $Player.global_position
	var lover_pos: Vector3 = _lover_node.global_position
	var dir: Vector3 = player_pos - lover_pos
	dir.y = 0.0
	if dir.length_squared() > 0.01:
		var target_y := atan2(dir.x, dir.z) + PI
		_lover_node.global_rotation.y = target_y


func _bounce_lover() -> void:
	if not _lover_node or not is_instance_valid(_lover_node):
		return
	var base_y: float = _lover_node.global_position.y
	var tw := create_tween().set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_lover_node, "global_position:y", base_y + 1.5, 0.2).set_ease(Tween.EASE_OUT)
	tw.tween_property(_lover_node, "global_position:y", base_y, 0.2).set_ease(Tween.EASE_IN)
	tw.tween_property(_lover_node, "global_position:y", base_y + 0.6, 0.15).set_ease(Tween.EASE_OUT)
	tw.tween_property(_lover_node, "global_position:y", base_y, 0.15).set_ease(Tween.EASE_IN)


func _on_signal_triggered(vibe_name: String, signal_name: String) -> void:
	# Lover reaction
	if _lover_node and is_instance_valid(_lover_node):
		var lover_emoji: Node = _lover_node.get_node_or_null("Emoji")
		if lover_emoji:
			if signal_name == "heart":
				lover_emoji.flash_emoji(1)  # heart emoji
			elif signal_name == "circle":
				lover_emoji.flash_emoji(0)  # note emoji
				_bounce_lover()

	# Enemy reaction
	if signal_name == "circle":
		_enemies_react_to_greet()


func _enemies_react_to_greet() -> void:
	for node in get_tree().get_nodes_in_group("wave_enemy"):
		if not is_instance_valid(node):
			continue
		var enemy: RigidBody3D = node as RigidBody3D
		if not enemy or not enemy.freeze or enemy.is_in_group("stunned"):
			continue
		enemy.add_to_group("stunned")
		# Face the player and hold facing during stun
		var player_pos: Vector3 = $Player.global_position
		var dir: Vector3 = player_pos - enemy.global_position
		dir.y = 0.0
		if dir.length_squared() > 0.01:
			var face_y := atan2(dir.x, dir.z) + PI
			enemy.global_rotation.y = face_y
		# Show question mark immediately, resume after 0.5s
		var emoji: Node = enemy.get_node_or_null("Emoji")
		if emoji:
			emoji.flash_emoji(5)  # question mark
		get_tree().create_timer(0.5).timeout.connect(func() -> void:
			if is_instance_valid(enemy):
				enemy.remove_from_group("stunned")
		)


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
