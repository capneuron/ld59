extends Node3D

## Training dummy stump. When hit by tail swipe, stretches upward briefly.

signal hit

@export var swipe_speed_threshold: float = 8.0
@export var stretch_scale: float = 1.5
@export var stretch_duration: float = 0.15
@export var recover_duration: float = 0.3

var _base_scale: Vector3
var _tween: Tween


func _ready() -> void:
	_base_scale = scale
	$SwipeDetector.body_entered.connect(_on_swipe_detector_body_entered)


func _on_swipe_detector_body_entered(body: Node3D) -> void:
	if not body.is_in_group("tail"):
		return
	if (body as RigidBody3D).linear_velocity.length() >= swipe_speed_threshold:
		_on_hit()


func _on_hit() -> void:
	if _tween and _tween.is_running():
		_tween.kill()

	_tween = create_tween()
	var stretched := Vector3(_base_scale.x, _base_scale.y * stretch_scale, _base_scale.z)
	_tween.tween_property(self, "scale", stretched, stretch_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_tween.tween_property(self, "scale", _base_scale, recover_duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_ELASTIC)

	hit.emit()
