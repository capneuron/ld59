extends CharacterBody3D

@export var move_speed: float = 8.0
@export var turn_speed: float = 10.0
@export var backward_angle: float = 120.0
@export var mouse_sensitivity: float = 0.015
@export var marker_color: Color = Color(1.0, 1.0, 1.0, 0.4)
@export var marker_radius: float = 0.3

var mouse_input_enabled: bool = true
var _camera: Camera3D
var _target_position: Vector3
var _facing_direction := Vector3.FORWARD
var _marker: MeshInstance3D
var _bounce_vel: Vector3 = Vector3.ZERO
var _is_bouncing: bool = false
const _BOUNCE_GRAVITY: float = 25.0


func _ready() -> void:
	_camera = get_node("%Camera3D")
	_target_position = global_position
	_create_marker()


func _create_marker() -> void:
	_marker = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = marker_radius
	disc.bottom_radius = marker_radius
	disc.height = 0.02
	_marker.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.albedo_color = marker_color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_marker.material_override = mat
	_marker.top_level = true
	add_child(_marker)


func _unhandled_input(event: InputEvent) -> void:
	if not mouse_input_enabled:
		return
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
	if event is InputEventMouseMotion:
		var delta_px: Vector2 = event.relative
		# Convert screen-space mouse offset to world-space XZ offset
		# Camera basis: right = basis.x, up = basis.y, forward = -basis.z
		var cam_right := _camera.global_basis.x
		var cam_up := _camera.global_basis.y
		# Project camera right/up onto XZ plane
		var world_right := Vector3(cam_right.x, 0.0, cam_right.z).normalized()
		var world_up := Vector3(cam_up.x, 0.0, cam_up.z).normalized()
		var offset := world_right * delta_px.x + world_up * (-delta_px.y)
		_target_position += offset * mouse_sensitivity
		_target_position.y = 0.0


func bounce(horizontal_dir: Vector3, horizontal_speed: float = 10.0, vertical_speed: float = 12.0) -> void:
	_is_bouncing = true
	var flat_dir := Vector3(horizontal_dir.x, 0.0, horizontal_dir.z).normalized()
	_bounce_vel = flat_dir * horizontal_speed + Vector3.UP * vertical_speed


func _physics_process(delta: float) -> void:
	# Update marker position
	if _marker:
		_marker.global_position = _target_position + Vector3(0.0, 0.02, 0.0)

	# During bounce: use parabolic arc velocity, ignore normal movement
	if _is_bouncing:
		_bounce_vel.y -= _BOUNCE_GRAVITY * delta
		velocity = _bounce_vel
		move_and_slide()
		if global_position.y <= 0.0:
			global_position.y = 0.0
			_bounce_vel = Vector3.ZERO
			_is_bouncing = false
			_target_position = global_position
		return

	var current := global_position
	var direction := _target_position - current
	direction.y = 0.0
	var distance := direction.length()

	if distance < 0.05:
		velocity = Vector3.ZERO
		return

	var move_dir := direction.normalized()
	var angle_to_target := rad_to_deg(_facing_direction.angle_to(move_dir))
	var moving_backward := angle_to_target > backward_angle

	var speed := minf(move_speed, distance / delta)
	velocity = move_dir * speed

	move_and_slide()

	if moving_backward:
		pass
	else:
		_facing_direction = _facing_direction.slerp(move_dir, clampf(turn_speed * delta, 0.0, 1.0)).normalized()

	var look_target := global_position + _facing_direction
	look_at(look_target, Vector3.UP)
