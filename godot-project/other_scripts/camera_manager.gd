extends Node

## Auto-discovers Area3D children under each camera node.
## Export only the camera nodes — their child Area3D is found automatically.

@export var cams: Array[Node3D] = []
@export var player: CharacterBody3D
@export var active_priority: int = 20
@export var inactive_priority: int = 0

var _current_cam: Node3D
var _cam_areas: Dictionary = {}  # Node3D -> Area3D


func _ready() -> void:
	for cam in cams:
		if not cam:
			continue
		var area: Area3D = _find_area(cam)
		if area:
			_cam_areas[cam] = area
			area.body_entered.connect(_on_area_entered.bind(cam))
	if cams.size() > 0 and cams[0]:
		_switch_to(cams[0])


func _find_area(node: Node3D) -> Area3D:
	for child in node.get_children():
		if child is Area3D:
			return child
	return null


func _on_area_entered(body: Node3D, cam: Node3D) -> void:
	if _is_player(body):
		_switch_to(cam)


func _switch_to(cam: Node3D) -> void:
	if cam == _current_cam:
		return
	_current_cam = cam

	for c in cams:
		if not c:
			continue
		c.set("priority", active_priority if c == cam else inactive_priority)

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
