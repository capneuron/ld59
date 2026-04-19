extends Node3D

## true = use PhysicalTail (independent physics tail)
## false = use ginnie's built-in Tail (visual tail)
@export var use_physical_tail: bool = false


@onready var signal_manager: Node = $SignalManager
@onready var player_emoji: Node = $Player/Emoji
@onready var cutscene_bars: Node = $CutsceneBars
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	set_tail_mode(use_physical_tail)

	signal_manager.vibe_changed.connect(_on_vibe_changed)
	signal_manager.vibe_expired.connect(_on_vibe_expired)
	signal_manager.signal_triggered.connect(_on_signal_triggered)
	signal_manager.shape_recognized.connect(_on_shape_recognized)
	signal_manager.shape_unrecognized.connect(_on_shape_unrecognized)

	$CameraManager/CutFirstMet/CutScene.body_entered.connect(_on_cut_first_met_body_entered)
	$L.ending_triggered.connect(_on_ending)
	_setup_enemy_tracking()

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

func _on_vibe_changed(vibe_name: String) -> void:
	print("[Main] Vibe changed: %s" % vibe_name)
	if vibe_name == "star":
		set_tail_mode(true)
	if vibe_name == "triangle" and player_emoji:
		if _default_emoji_scale == Vector3.ZERO:
			_default_emoji_scale = player_emoji.target_scale
		player_emoji.target_scale = Vector3(7, 7, 7)
		player_emoji.scale = player_emoji.target_scale


func _on_vibe_expired() -> void:
	print("[Main] Vibe expired")
	set_tail_mode(false)
	if player_emoji and _default_emoji_scale != Vector3.ZERO:
		player_emoji.target_scale = _default_emoji_scale
		player_emoji.scale = _default_emoji_scale


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
		print("[Main] All enemies defeated — L stopped shaking")

var _ending_triggered: bool = false
func _on_ending() -> void:
	if _ending_triggered:
		return
	_ending_triggered = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	start_cutscene()
	$CameraManager/EndingCam.set("priority", 500)
	$Player.hide()
	$L/Emoji.flash_emoji(3, 5.0)
	await get_tree().create_timer(6.0).timeout
	$L/Emoji.flash_emoji(1, 1.5)
	await get_tree().create_timer(1.5).timeout
	$EndingCanvas.show()
	await get_tree().create_timer(5.0).timeout
	var restart_btn: TextureButton = $EndingCanvas/RestartButton
	restart_btn.pivot_offset = restart_btn.size / 2.0
	restart_btn.show()
	restart_btn.pressed.connect(_on_restart)
	restart_btn.mouse_entered.connect(func() -> void:
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(restart_btn, "scale", Vector2(1.2, 1.2), 0.15)
	)
	restart_btn.mouse_exited.connect(func() -> void:
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(restart_btn, "scale", Vector2(1.0, 1.0), 0.15)
	)
	restart_btn.button_down.connect(func() -> void:
		var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(restart_btn, "scale", Vector2(0.9, 0.9), 0.08)
	)
	restart_btn.button_up.connect(func() -> void:
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(restart_btn, "scale", Vector2(1.2, 1.2), 0.1)
	)


func _on_restart() -> void:
	get_tree().reload_current_scene()

