extends RigidBody3D

## NPC M: hostile guinea pig. Responds to greet (circle) with bounce + emoji.
## Knocks the player back on body contact.

@export var detection_range: float = 12.0
@export var turn_speed: float = 5.0
@export var bounce_height: float = 0.4
@export var bounce_count: int = 3
@export var bounce_speed: float = 8.0
@export var knockback_radius: float = 2.5
@export var knockback_force: float = 8.0
@export var knockback_cooldown: float = 1.0

var _player: CharacterBody3D
var _signal_manager: Node
var _player_in_range: bool = false
var _facing_player: bool = false
var _bouncing: bool = false
var _bounce_time: float = 0.0
var _bounce_duration: float = 0.0
var _base_y: float = 0.0
var _original_rotation_y: float = 0.0
var _knockback_timer: float = 0.0


func _ready() -> void:
	_player = get_node_or_null("/root/Main/Player") as CharacterBody3D
	_signal_manager = get_node_or_null("/root/Main/SignalManager")
	if _signal_manager:
		_signal_manager.signal_triggered.connect(_on_signal_triggered)


func _process(delta: float) -> void:
	if not _player:
		return

	if _knockback_timer > 0.0:
		_knockback_timer -= delta

	var distance := global_position.distance_to(_player.global_position)
	_player_in_range = distance <= detection_range

	# Knockback player on contact
	if distance <= knockback_radius and _knockback_timer <= 0.0:
		_knockback_timer = knockback_cooldown
		var dir := _player.global_position - global_position
		dir.y = 0.0
		if dir.length_squared() > 0.001:
			dir = dir.normalized()
		else:
			dir = Vector3.FORWARD
		_player._target_position = _player.global_position + dir * knockback_force
		_player._target_position.y = 0.0
		$Emoji.flash_emoji(4)

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
		$Emoji.flash_emoji(4)
