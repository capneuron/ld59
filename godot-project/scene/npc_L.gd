extends RigidBody3D

## NPC L: shakes left and right in place.

@export var shake_speed: float = 30.0
@export var shake_amount: float = 0.05
@export var _shaking: bool = false

var _base_position: Vector3 = Vector3.ZERO
var _shake_time: float = 0.0


func _ready() -> void:
	_base_position = position

func turn_on_shaking() -> void:
	_base_position = position
	_shaking = true

func turn_off_shaking() -> void:
	_shaking = false

func _process(delta: float) -> void:
	if _shaking:
		_shake_time += delta
		position.x = _base_position.x + sin(_shake_time * shake_speed) * shake_amount