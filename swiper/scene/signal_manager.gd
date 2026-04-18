# signal_manager.gd
extends Node

## Manages vibe state and signal dispatch.
## Connect trail_system.shape_closed to on_shape_closed().

signal vibe_changed(vibe_name: String)
signal vibe_expired()
signal signal_triggered(vibe_name: String, signal_name: String)
signal shape_recognized(shape_name: String, shape_type: String)
signal shape_unrecognized()

@export var vibe_duration: float = 18.0  ## Seconds a vibe lasts
@export var trail_system: Node3D

## Shape name -> type mapping
const SHAPE_TYPES := {
	"square": "vibe",
	"figure8": "vibe",
	"heart": "signal",
	"triangle": "signal",
	"circle": "signal",
}

## Shape name -> display name
const SHAPE_DISPLAY := {
	"square": "Sincere",
	"figure8": "Confident",
	"heart": "Court",
	"triangle": "Warn",
	"circle": "Greet",
}

var _recognizer: ShapeRecognizer
var _current_vibe := ""  ## Empty = neutral
var _vibe_timer := 0.0


func _ready() -> void:
	_recognizer = ShapeRecognizer.new()


func _process(delta: float) -> void:
	if _current_vibe != "":
		_vibe_timer -= delta
		if _vibe_timer <= 0.0:
			_current_vibe = ""
			_vibe_timer = 0.0
			vibe_expired.emit()


func get_current_vibe() -> String:
	return _current_vibe


func get_current_vibe_display() -> String:
	if _current_vibe == "":
		return "Neutral"
	return SHAPE_DISPLAY.get(_current_vibe, _current_vibe)


func get_vibe_time_remaining() -> float:
	return maxf(_vibe_timer, 0.0)


func on_shape_closed(points: Array[Vector2]) -> void:
	var result := _recognizer.recognize(points)
	print("Shape recognition: best=%s score=%.3f (points=%d)" % [result.get("name", "?"), result.get("score", 0.0), points.size()])

	if result["name"] == "":
		shape_unrecognized.emit()
		if trail_system:
			trail_system.flash_last_trail(trail_system.fail_color)
		return

	var shape_name: String = result["name"]
	var shape_type: String = SHAPE_TYPES.get(shape_name, "")

	shape_recognized.emit(shape_name, shape_type)

	if trail_system:
		if shape_type == "vibe":
			trail_system.flash_last_trail(trail_system.vibe_color)
		elif shape_type == "signal":
			trail_system.flash_last_trail(trail_system.signal_color)

	if shape_type == "vibe":
		_current_vibe = shape_name
		_vibe_timer = vibe_duration
		vibe_changed.emit(shape_name)

	elif shape_type == "signal":
		signal_triggered.emit(_current_vibe, shape_name)
