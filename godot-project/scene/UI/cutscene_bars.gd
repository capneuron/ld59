extends CanvasLayer

## Cinematic letterbox bars + input block for cutscenes.
## Call show_bars() / hide_bars() to toggle.

signal bars_shown
signal bars_hidden

@export var bar_height: float = 60.0
@export var anim_duration: float = 0.5

var _top_bar: ColorRect
var _bottom_bar: ColorRect
var _input_blocker: Control
var _tween: Tween
var _active: bool = false


func _ready() -> void:
	layer = 100

	# Input blocker — covers entire screen, invisible, blocks mouse
	_input_blocker = Control.new()
	_input_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_input_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_input_blocker.visible = false
	add_child(_input_blocker)

	# Top bar
	_top_bar = ColorRect.new()
	_top_bar.color = Color.BLACK
	_top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top_bar.offset_bottom = 0.0
	_top_bar.offset_top = -bar_height
	add_child(_top_bar)

	# Bottom bar
	_bottom_bar = ColorRect.new()
	_bottom_bar.color = Color.BLACK
	_bottom_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom_bar.offset_top = 0.0
	_bottom_bar.offset_bottom = bar_height
	add_child(_bottom_bar)


func show_bars() -> void:
	if _active:
		return
	_active = true
	_input_blocker.visible = true

	_kill_tween()
	_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(_top_bar, "offset_top", 0.0, anim_duration)
	_tween.tween_property(_top_bar, "offset_bottom", bar_height, anim_duration)
	_tween.tween_property(_bottom_bar, "offset_top", -bar_height, anim_duration)
	_tween.tween_property(_bottom_bar, "offset_bottom", 0.0, anim_duration)
	_tween.chain().tween_callback(func(): bars_shown.emit())


func hide_bars() -> void:
	if not _active:
		return
	_active = false

	_kill_tween()
	_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(_top_bar, "offset_top", -bar_height, anim_duration)
	_tween.tween_property(_top_bar, "offset_bottom", 0.0, anim_duration)
	_tween.tween_property(_bottom_bar, "offset_top", 0.0, anim_duration)
	_tween.tween_property(_bottom_bar, "offset_bottom", bar_height, anim_duration)
	_tween.chain().tween_callback(func():
		_input_blocker.visible = false
		bars_hidden.emit()
	)


func is_active() -> bool:
	return _active


func _kill_tween() -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = null
