extends Node

@export var home_cam: Node3D
@export var plaza_cam: Node3D
@export var home_area: Area3D
@export var plaza_area: Area3D
@export var player: CharacterBody3D
@export var active_priority: int = 20
@export var inactive_priority: int = 0

var _current_cam: Node3D


func _ready() -> void:
	if home_area:
		home_area.body_entered.connect(_on_home_entered)
	if plaza_area:
		plaza_area.body_entered.connect(_on_plaza_entered)
	_switch_to(home_cam)


func _on_home_entered(body: Node3D) -> void:
	if _is_player(body):
		_switch_to(home_cam)


func _on_plaza_entered(body: Node3D) -> void:
	if _is_player(body):
		_switch_to(plaza_cam)


func _switch_to(cam: Node3D) -> void:
	if cam == _current_cam:
		return
	_current_cam = cam

	if home_cam:
		home_cam.set("priority", active_priority if cam == home_cam else inactive_priority)
	if plaza_cam:
		plaza_cam.set("priority", active_priority if cam == plaza_cam else inactive_priority)

	if player:
		player.mouse_input_enabled = false
		player.velocity = Vector3.ZERO
		player._target_position = player.global_position
		if cam.has_signal("tween_completed"):
			if cam.tween_completed.is_connected(_on_tween_completed):
				cam.tween_completed.disconnect(_on_tween_completed)
			cam.tween_completed.connect(_on_tween_completed, CONNECT_ONE_SHOT)
		get_tree().create_timer(3.0).timeout.connect(_restore_input)


func _on_tween_completed() -> void:
	_restore_input()


func _restore_input() -> void:
	if player and not player.mouse_input_enabled:
		player._target_position = player.global_position
		player.mouse_input_enabled = true


func _is_player(body: Node3D) -> bool:
	return body.is_in_group("player") or body.name == "Player"
