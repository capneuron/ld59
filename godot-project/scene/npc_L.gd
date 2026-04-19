extends RigidBody3D

## NPC L: shakes left and right in place.

signal ending_triggered

@export var shake_speed: float = 30.0
@export var shake_amount: float = 0.05
@export var _shaking: bool = false
@export var detection_range: float = 15.0

var _base_position: Vector3 = Vector3.ZERO
var _shake_time: float = 0.0
var _player: Node3D
var _signal_manager: Node


func _ready() -> void:
	_base_position = position
	_player = get_node_or_null("/root/Main/Player")
	_signal_manager = get_node_or_null("/root/Main/SignalManager")
	if _signal_manager:
		_signal_manager.signal_triggered.connect(_on_signal_triggered)


func turn_on_shaking() -> void:
	_base_position = position
	_shaking = true


func turn_off_shaking() -> void:
	_shaking = false


func _process(delta: float) -> void:
	if _shaking:
		_shake_time += delta
		position.x = _base_position.x + sin(_shake_time * shake_speed) * shake_amount


func _on_signal_triggered(vibe_name: String, signal_name: String) -> void:
	if vibe_name != "triangle" or signal_name != "heart":
		return
	if not _player:
		return
	var distance := global_position.distance_to(_player.global_position)
	if distance > detection_range:
		return
	ending_triggered.emit()
