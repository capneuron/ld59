extends RigidBody3D

## NPC L: shakes left and right in place.

@export var shake_speed: float = 30.0
@export var shake_amount: float = 0.05
@export var shaking: bool = false

var _base_position: Vector3 = Vector3.ZERO
var _shake_time: float = 0.0


func _ready() -> void:
	_base_position = position


func _process(delta: float) -> void:
	if shaking:
		_shake_time += delta
		position.x = _base_position.x + sin(_shake_time * shake_speed) * shake_amount