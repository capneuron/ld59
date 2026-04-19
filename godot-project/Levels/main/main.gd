extends Node3D

## true = use PhysicalTail (independent physics tail)
## false = use ginnie's built-in Tail (visual tail)
@export var use_physical_tail: bool = false


@onready var signal_manager: Node = $SignalManager
@onready var player_emoji: Node = $Player/Emoji
@onready var cutscene_bars: Node = $CutsceneBars
@onready var animation_player: AnimationPlayer = $AnimationPlayer

@onready var _bgm_main: AudioStreamPlayer = $BGMMain
@onready var _bgm_ending: AudioStreamPlayer = $BGMEnding

func _ready() -> void:
	set_tail_mode(use_physical_tail)
	_setup_bgm_loop()
	_play_bgm("main")
	signal_manager.vibe_changed.connect(_on_vibe_changed)
	signal_manager.vibe_expired.connect(_on_vibe_expired)
	signal_manager.signal_triggered.connect(_on_signal_triggered)
	signal_manager.shape_recognized.connect(_on_shape_recognized)
	signal_manager.shape_unrecognized.connect(_on_shape_unrecognized)

	$CameraManager/CutFirstMet/CutScene.body_entered.connect(_on_cut_first_met_body_entered)
	$L.ending_triggered.connect(_on_ending)
	$F.ending_triggered.connect(_on_ending_f)
	_setup_enemy_tracking()
	_show_start_screen()


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
	start_btn.pivot_offset = start_btn.size / 2.0
	start_btn.pressed.connect(_on_start)
	start_btn.mouse_entered.connect(func() -> void:
		var tw := start_btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(start_btn, "scale", Vector2(1.2, 1.2), 0.15)
	)
	start_btn.mouse_exited.connect(func() -> void:
		var tw := start_btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(start_btn, "scale", Vector2(1.0, 1.0), 0.15)
	)
	start_btn.button_down.connect(func() -> void:
		var tw := start_btn.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(start_btn, "scale", Vector2(0.9, 0.9), 0.08)
	)
	start_btn.button_up.connect(func() -> void:
		var tw := start_btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(start_btn, "scale", Vector2(1.2, 1.2), 0.1)
	)


func _on_start() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	$Player.mouse_input_enabled = true
	$Player.set_physics_process(true)
	$Player/ginnie/Tail.visible = true
	$StartCanvas.queue_free()
	$CameraManager/StartCam.priority = 0
	$PauseMenu.enabled = true


func _setup_bgm_loop() -> void:
	_bgm_main.bus = "BGM"
	_bgm_ending.bus = "BGM"
	_bgm_main.process_mode = Node.PROCESS_MODE_ALWAYS
	_bgm_ending.process_mode = Node.PROCESS_MODE_ALWAYS
	_bgm_main.finished.connect(_bgm_main.play)
	_bgm_ending.finished.connect(_bgm_ending.play)


func _play_bgm(which: String) -> void:
	_bgm_main.stop()
	_bgm_ending.stop()
	if which == "main":
		_bgm_main.play()
	elif which == "ending":
		_bgm_ending.play()

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

# ===== Cutscene =====

func start_cutscene() -> void:
	if cutscene_bars:
		cutscene_bars.show_bars()
	$Player.mouse_input_enabled = false


func end_cutscene() -> void:
	if cutscene_bars:
		cutscene_bars.hide_bars()
	$Player.mouse_input_enabled = true


# ===== Player Signal Handlers =====

var _default_emoji_scale: Vector3 = Vector3.ZERO
var _extra_tail: Node3D = null
var _physical_tail_scene: PackedScene = preload("res://scene/physical_tail.tscn")

func _on_vibe_changed(vibe_name: String) -> void:
	print("[Main] Vibe changed: %s" % vibe_name)
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
	print("[Main] Vibe expired")
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
	# Position must match player BEFORE add_child, because _ready() creates
	# PinJoint3D constraints relative to this node's origin.
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
	print("[Main] Signal triggered: %s (vibe: %s)" % [signal_name, vibe_name])


func _on_shape_recognized(shape_name: String, shape_type: String) -> void:
	print("[Main] Shape recognized: %s (%s)" % [shape_name, shape_type])
	if player_emoji:
		var emoji_frame: int = player_emoji.SHAPE_EMOJI.get(shape_name, 5) # default to question mark
		player_emoji.flash_emoji(emoji_frame, player_emoji.flash_duration)


func _on_shape_unrecognized() -> void:
	print("[Main] Shape unrecognized")
	if player_emoji:
		player_emoji.flash_emoji(5, 1.0)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T:
			set_tail_mode(not use_physical_tail)
			print("Tail mode: %s" % ("Physical" if use_physical_tail else "Visual"))

var first_met_played: bool = false
var _enemies_killed: int = 0
var _enemy_nodes: Array[Node] = []

func _on_cut_first_met_body_entered(body: Node) -> void:
	if body.name == "Player" and not first_met_played:
		first_met_played = true
		start_cutscene()
		animation_player.play("FirstMet")
		await animation_player.animation_finished
		$CameraManager.disable_cam("CutFirstMet")
		$L.turn_on_shaking()
		end_cutscene()


func _setup_enemy_tracking() -> void:
	for node: Node in get_tree().get_nodes_in_group("enemy"):
		_enemy_nodes.append(node)
		var swipeable: Node = node.get_node_or_null("Swipeable")
		if swipeable:
			swipeable.swiped.connect(_on_enemy_swiped.bind(node))


func _on_enemy_swiped(_hit_velocity: Vector3, enemy: Node) -> void:
	_enemies_killed += 1
	print("[Main] Enemy swiped: %s (%d/%d)" % [enemy.name, _enemies_killed, _enemy_nodes.size()])
	if _enemies_killed >= _enemy_nodes.size():
		$L.turn_off_shaking()
		$L.enable_ending()
		print("[Main] All enemies defeated — L stopped shaking")

var _ending_triggered: bool = false
func _on_ending() -> void:
	if _ending_triggered:
		return
	_ending_triggered = true
	print("[Ending] _on_ending called!")
	_play_bgm("") #stop music
	$SubViewportContainer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_cutscene()
	$CameraManager/EndingCam.set("priority", 500)
	$Player.hide()
	$L/Emoji.flash_emoji(3, 5.0)
	await get_tree().create_timer(6.0).timeout
	$L/Emoji.flash_emoji(1, 1.5)
	await get_tree().create_timer(1.5).timeout
	$EndingCanvas.show_ending()
	_play_bgm("ending")
	$Player.set_process(false)
	$Player.set_physics_process(false)
	$Player.set_process_unhandled_input(false)


func _on_ending_f() -> void:
	if _ending_triggered:
		return
	_ending_triggered = true
	print("[Ending] _on_ending_f called!")
	_play_bgm("") #stop music
	start_cutscene()
	$F/Emoji.flash_emoji(1, 5.0)
	await get_tree().create_timer(6.0).timeout
	$EndingCanvas.show_ending()
	_play_bgm("ending")
	$Player.set_process(false)
	$Player.set_physics_process(false)
	$Player.set_process_unhandled_input(false)
