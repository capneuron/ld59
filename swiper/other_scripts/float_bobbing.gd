extends Node3D

@export var amplitude: float = 0.3
@export var speed: float = 2.0
@export var offset: float = 0.0

var _base_y: float

func _ready() -> void:
	_base_y = position.y

func _process(delta: float) -> void:
	position.y = _base_y + sin(Time.get_ticks_msec() * 0.001 * speed + offset) * amplitude
