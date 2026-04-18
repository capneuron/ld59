extends Sprite3D

## Offset in screen-relative directions: x = screen right, y = screen up.
@export var screen_offset: Vector2 = Vector2(2.25, 2.25)
## Duration for pop-in/pop-out animation.
@export var anim_duration: float = 0.15
## Duration for flash display.
@export var flash_duration: float = 2.0

## Map recognized shape names to emoji frame indices.
## Frames: 0=Note, 1=Heart, 2=Cross, 3=Dots, 4=Angry, 5=Question, 6=Alert
const SHAPE_EMOJI := {
	"heart": 1,
	"triangle": 6,
	"circle": 0,
	"square": 3,
	"star": 0,
}

var target_scale: Vector3 = Vector3.ONE
var _tween: Tween


func _ready() -> void:
	top_level = true
	target_scale = scale
	scale = Vector3.ZERO


func _process(_delta: float) -> void:
	var parent_node := get_parent() as Node3D
	if not parent_node:
		return
	var cam := _find_camera()
	if cam:
		var cam_right := cam.global_basis.x
		var cam_up := cam.global_basis.y
		global_position = parent_node.global_position + cam_right * screen_offset.x + cam_up * screen_offset.y
	else:
		global_position = parent_node.global_position + Vector3(screen_offset.x, screen_offset.y, 0.0)
	global_rotation = Vector3.ZERO


## Show a specific emoji frame with a pop-in animation.
func show_emoji(frame_index: int) -> void:
	frame = clampi(frame_index, 0, hframes - 1)
	visible = true
	_kill_tween()
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", target_scale, anim_duration).from(Vector3.ZERO)


## Hide the emoji with a pop-out animation.
func hide_emoji() -> void:
	_kill_tween()
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "scale", Vector3.ZERO, anim_duration)
	_tween.tween_callback(func() -> void: scale = Vector3.ZERO)


## Show emoji for a duration, then auto-hide.
func flash_emoji(frame_index: int, duration: float = 2.0) -> void:
	show_emoji(frame_index)
	_kill_tween()
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", target_scale, anim_duration).from(Vector3.ZERO)
	_tween.tween_interval(duration)
	_tween.tween_property(self, "scale", Vector3.ZERO, anim_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func() -> void: scale = Vector3.ZERO)


func _find_camera() -> Camera3D:
	# Camera lives inside a SubViewport, so get_viewport().get_camera_3d() won't find it.
	var cam := get_viewport().get_camera_3d()
	if cam:
		return cam
	var sub_vp := get_node_or_null("/root/Main/SubViewportContainer/SubViewport")
	if sub_vp:
		return sub_vp.get_camera_3d()
	return null


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
