extends Node

## Add as a child node to any Node3D. Call play() to trigger a happy bounce on the parent.

@export var bounce_height: float = 0.4
@export var bounce_count: int = 3
@export var bounce_speed: float = 8.0
@export var squash_amount: float = 0.15

var _target: Node3D
var _base_y: float
var _bouncing: bool = false
var _time: float = 0.0
var _total_duration: float = 0.0

signal finished


func _ready() -> void:
	_target = get_parent() as Node3D
	_total_duration = bounce_count * TAU / bounce_speed


func play() -> void:
	if _bouncing or not _target:
		return
	_base_y = _target.position.y
	_bouncing = true
	_time = 0.0


func _process(delta: float) -> void:
	if not _bouncing:
		return

	_time += delta
	if _time >= _total_duration:
		_bouncing = false
		_target.position.y = _base_y
		_target.scale = Vector3.ONE
		finished.emit()
		return

	var progress: float = _time / _total_duration
	var decay: float = 1.0 - progress
	var bounce_y: float = abs(sin(_time * bounce_speed)) * bounce_height * decay
	_target.position.y = _base_y + bounce_y

	var squash: float = squash_amount * decay * abs(sin(_time * bounce_speed))
	_target.scale = Vector3(1.0 + squash, 1.0 - squash, 1.0 + squash)
