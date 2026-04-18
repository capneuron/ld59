extends Node3D

@export var move_speed: float = 8.0
@export var turn_speed: float = 10.0
@export var backward_angle: float = 120.0

var _camera: Camera3D
var _target_position: Vector3
var _ground_plane := Plane(Vector3.UP, 0.0)
var _facing_direction := Vector3.FORWARD


func _ready() -> void:
	_camera = get_node("%Camera3D")
	_target_position = global_position


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		# Convert root viewport mouse pos to SubViewport coordinates
		var root_vp := get_viewport()
		var mouse_pos := root_vp.get_mouse_position()
		var root_size := root_vp.get_visible_rect().size
		var sub_vp := _camera.get_viewport()
		var sub_size := Vector2(sub_vp.size)
		var scaled_mouse := mouse_pos * sub_size / root_size
		var ray_origin := _camera.project_ray_origin(scaled_mouse)
		var ray_dir := _camera.project_ray_normal(scaled_mouse)
		var intersection = _ground_plane.intersects_ray(ray_origin, ray_dir)
		if intersection != null:
			_target_position = intersection as Vector3
			_target_position.y = 0.0


func _process(delta: float) -> void:
	var current := global_position
	var direction := _target_position - current
	direction.y = 0.0
	var distance := direction.length()

	if distance < 0.05:
		return

	var move_dir := direction.normalized()
	var angle_to_target := rad_to_deg(_facing_direction.angle_to(move_dir))
	var moving_backward := angle_to_target > backward_angle

	var move_delta := move_speed * delta
	if move_delta > distance:
		move_delta = distance

	global_position += move_dir * move_delta

	if moving_backward:
		# Walk backward: keep current facing, don't rotate
		pass
	else:
		# Smoothly rotate toward movement direction
		_facing_direction = _facing_direction.slerp(move_dir, clampf(turn_speed * delta, 0.0, 1.0)).normalized()

	var look_target := global_position + _facing_direction
	look_at(look_target, Vector3.UP)
