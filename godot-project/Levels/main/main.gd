extends Node3D

## true = use PhysicalTail (independent physics tail)
## false = use ginnie's built-in Tail (visual tail)
@export var use_physical_tail: bool = false


@onready var signal_manager: Node = $SignalManager
@onready var player_emoji: Node = $Player/Emoji
@onready var cutscene_bars: Node = $CutsceneBars


func _ready() -> void:
	set_tail_mode(use_physical_tail)

	signal_manager.vibe_changed.connect(_on_vibe_changed)
	signal_manager.vibe_expired.connect(_on_vibe_expired)
	signal_manager.signal_triggered.connect(_on_signal_triggered)
	signal_manager.shape_recognized.connect(_on_shape_recognized)
	signal_manager.shape_unrecognized.connect(_on_shape_unrecognized)

	$CamaeraManger/CutFirstMet/CutScene.body_entered.connect(_on_cut_first_met_body_entered)

	SceneManager.set_transition_scene(preload("res://scene/UI/TransitionScreen/TransitionScreen.tscn"))

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

func _on_cut_first_met_body_entered(body: Node) -> void:
	if body.name == "Player":
		start_cutscene()
