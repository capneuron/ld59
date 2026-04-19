extends RigidBody3D

## NPC S: flashes emoji 3 when the player gets close.
## Connects to all rocks under Rocks node — when all are swiped, draws a triangle.

@export var detection_range: float = 12.0
@export var turn_speed: float = 5.0
@export var bounce_height: float = 0.4
@export var bounce_count: int = 3
@export var bounce_speed: float = 8.0

var _player: Node3D
var _signal_manager: Node
var _shape_drawer: ShapeDrawer
var _player_in_range: bool = false
var _triggered: bool = false
var _facing_player: bool = false
var _bouncing: bool = false
var _bounce_time: float = 0.0
var _bounce_duration: float = 0.0
var _base_y: float = 0.0
var _original_rotation_y: float = 0.0

var _total_rocks: int = 0
var _swiped_rocks: int = 0
var _all_rocks_swiped: bool = false


func _ready() -> void:
	_player = get_node_or_null("/root/Main/Player")
	_signal_manager = get_node_or_null("/root/Main/SignalManager")
	_shape_drawer = get_node_or_null("ShapeDrawer") as ShapeDrawer
	if _shape_drawer:
		_shape_drawer.drawing_finished.connect(_on_drawing_finished)
	if _signal_manager:
		_signal_manager.signal_triggered.connect(_on_signal_triggered)
		_signal_manager.shape_recognized.connect(_on_shape_recognized)
		_signal_manager.shape_unrecognized.connect(_on_shape_unrecognized)

	# Connect to all rocks' Swipeable.swiped_first_time
	var rocks_node := get_node_or_null("/root/Main/Ground/Rocks")
	if rocks_node:
		for rock in rocks_node.get_children():
			var swipeable := rock.get_node_or_null("Swipeable")
			if swipeable and swipeable.has_signal("swiped_first_time"):
				_total_rocks += 1
				swipeable.swiped_first_time.connect(_on_rock_swiped)


func _on_rock_swiped(_hit_velocity: Vector3) -> void:
	_swiped_rocks += 1
	if _swiped_rocks >= _total_rocks and not _all_rocks_swiped:
		_all_rocks_swiped = true
		_start_drawing_triangle()


func _start_drawing_triangle() -> void:
	if not _shape_drawer or _shape_drawer.is_drawing():
		return
	_pre_draw_position = global_position
	_shape_drawer.draw_shape("triangle", global_position)


var _pre_draw_position: Vector3 = Vector3.ZERO

func _on_drawing_finished(_shape_name: String) -> void:
	if _pre_draw_position != Vector3.ZERO:
		global_position = _pre_draw_position
		_pre_draw_position = Vector3.ZERO
	$Emoji.flash_emoji(6)


func _ready_bounce() -> void:
	_bounce_duration = bounce_count * TAU / bounce_speed


func _process(delta: float) -> void:
	if not _player:
		return

	var distance := global_position.distance_to(_player.global_position)
	_player_in_range = distance <= detection_range
	if _player_in_range and not _triggered:
		_triggered = true
		$Emoji.flash_emoji(3)
	elif not _player_in_range:
		_triggered = false

	# Face player
	if _facing_player and _player_in_range:
		var dir := _player.global_position - global_position
		dir.y = 0.0
		if dir.length_squared() > 0.01:
			var target_y := atan2(dir.x, dir.z) + PI
			var current_y := global_rotation.y
			var diff := wrapf(target_y - current_y, -PI, PI)
			global_rotation.y = current_y + diff * clampf(turn_speed * delta, 0.0, 1.0)

	# Bounce
	if _bouncing:
		_bounce_time += delta
		if _bounce_time >= _bounce_duration:
			_bouncing = false
			_facing_player = false
			position.y = _base_y
			var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(self, "global_rotation:y", _original_rotation_y, 0.5)
		else:
			var progress: float = _bounce_time / _bounce_duration
			var decay: float = 1.0 - progress
			position.y = _base_y + abs(sin(_bounce_time * bounce_speed)) * bounce_height * decay


func _play_bounce() -> void:
	if _bouncing:
		return
	_base_y = position.y
	_bouncing = true
	_bounce_time = 0.0
	_bounce_duration = bounce_count * TAU / bounce_speed


func _on_signal_triggered(_vibe_name: String, signal_name: String) -> void:
	if not _player_in_range:
		return
	if signal_name == "circle":
		_original_rotation_y = global_rotation.y
		_facing_player = true
		_play_bounce()
		$Emoji.flash_emoji(0)


func _on_shape_recognized(shape_name: String, _shape_type: String) -> void:
	if not _player_in_range:
		return
	pass


func _on_shape_unrecognized() -> void:
	if not _player_in_range:
		return
	pass
