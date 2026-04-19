extends RigidBody3D

## NPC F: when the player gets close, draws a circle on the ground.

signal ending_triggered

@export var detection_range: float = 12.0
@export var draw_cooldown: float = 25.0

var _player: Node3D
var _signal_manager: Node
var _shape_drawer: ShapeDrawer
var _cooldown_timer: float = 0.0
var _has_drawn: bool = false
var _pre_draw_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	_player = get_node_or_null("/root/Main/Player")
	_signal_manager = get_node_or_null("/root/Main/SignalManager")
	_shape_drawer = get_node_or_null("ShapeDrawer") as ShapeDrawer
	if _shape_drawer:
		_shape_drawer.drawing_finished.connect(_on_drawing_finished)
	if _signal_manager:
		_signal_manager.signal_triggered.connect(_on_signal_triggered)


func _process(delta: float) -> void:
	if not _player:
		return

	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta

	var distance := global_position.distance_to(_player.global_position)
	if distance <= detection_range and _cooldown_timer <= 0.0 and not _has_drawn:
		_start_drawing()


func _start_drawing() -> void:
	if not _shape_drawer or _shape_drawer.is_drawing():
		return
	_has_drawn = true
	_pre_draw_position = global_position
	_shape_drawer.draw_shape("circle", global_position)


func _on_drawing_finished(_shape_name: String) -> void:
	_cooldown_timer = draw_cooldown
	_has_drawn = false
	if _pre_draw_position != Vector3.ZERO:
		global_position = _pre_draw_position
		_pre_draw_position = Vector3.ZERO
	$Emoji.flash_emoji(0)


func _on_signal_triggered(vibe_name: String, signal_name: String) -> void:
	if not _player:
		return
	var distance := global_position.distance_to(_player.global_position)
	if distance > detection_range:
		return
	if signal_name == "heart":
		if vibe_name == "triangle":
			ending_triggered.emit()
		else:
			$Emoji.flash_emoji(2)
