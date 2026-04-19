extends Node

## Add as a child of any Node3D. Makes the parent face the player when nearby
## and react to shape signals (e.g. greet → happy bounce + emoji).

@export var detection_range: float = 15.0
@export var face_player: bool = true
@export var turn_speed: float = 5.0

## Bounce parameters (reused from happy_bounce logic)
@export var bounce_height: float = 0.4
@export var bounce_count: int = 3
@export var bounce_speed: float = 8.0
@export var squash_amount: float = 0.15

var _target: Node3D
var _player: Node3D
var _signal_manager: Node
var _player_in_range: bool = false

# Bounce state
var _bouncing: bool = false
var _bounce_time: float = 0.0
var _bounce_duration: float = 0.0
var _base_y: float = 0.0
var _disabled: bool = false


func _ready() -> void:
	_target = get_parent() as Node3D
	_bounce_duration = bounce_count * TAU / bounce_speed
	_player = get_node_or_null("/root/Main/Player")
	_signal_manager = get_node_or_null("/root/Main/SignalManager")
	if _signal_manager:
		_signal_manager.signal_triggered.connect(_on_signal_triggered)
		_signal_manager.shape_recognized.connect(_on_shape_recognized)
		_signal_manager.shape_unrecognized.connect(_on_shape_unrecognized)


func disable() -> void:
	_disabled = true
	_bouncing = false


func _process(delta: float) -> void:
	if _disabled or not _target or not _player:
		return

	var distance := _target.global_position.distance_to(_player.global_position)
	_player_in_range = distance <= detection_range

	# Face player (also during bounce)
	if face_player and (_player_in_range or _bouncing):
		var dir := _player.global_position - _target.global_position
		dir.y = 0.0
		if dir.length_squared() > 0.01:
			var target_y := atan2(dir.x, dir.z) + PI
			var current_y := _target.global_rotation.y
			var diff := wrapf(target_y - current_y, -PI, PI)
			_target.global_rotation.y = current_y + diff * clampf(turn_speed * delta, 0.0, 1.0)

	# Bounce
	if _bouncing:
		_bounce_time += delta
		if _bounce_time >= _bounce_duration:
			_bouncing = false
			_target.position.y = _base_y
			_target.scale = Vector3.ONE
		else:
			var progress: float = _bounce_time / _bounce_duration
			var decay: float = 1.0 - progress
			var bounce_y: float = abs(sin(_bounce_time * bounce_speed)) * bounce_height * decay
			_target.position.y = _base_y + bounce_y
			var squash: float = squash_amount * decay * abs(sin(_bounce_time * bounce_speed))
			_target.scale = Vector3(1.0 + squash, 1.0 - squash, 1.0 + squash)


func _play_bounce() -> void:
	if _bouncing or not _target:
		return
	_base_y = _target.position.y
	_bouncing = true
	_bounce_time = 0.0


func _get_emoji() -> Node:
	if not _target:
		return null
	return _target.get_node_or_null("Emoji")


func _on_shape_recognized(shape_name: String, _shape_type: String) -> void:
	pass
# 	if not _player_in_range:
# 		return
# 	var emoji := _get_emoji()
# 	if emoji:
# 		var emoji_frame: int = emoji.SHAPE_EMOJI.get(shape_name, 5)
# 		emoji.flash_emoji(emoji_frame, emoji.flash_duration)


func _on_shape_unrecognized() -> void:
	if not _player_in_range:
		return
	var emoji := _get_emoji()
	if emoji:
		emoji.flash_emoji(5, 1.0)  # question mark


func _on_signal_triggered(_vibe_name: String, signal_name: String) -> void:
	if not _player_in_range:
		return
	if signal_name == "circle":  # Greet
		_play_bounce()
		var emoji := _get_emoji()
		if emoji:
			emoji.flash_emoji(0)  # Note emoji
