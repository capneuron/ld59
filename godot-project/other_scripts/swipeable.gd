extends Area3D

## Add as a child of any Node3D. Detects tail swipe and launches parent.
## Parent should be a RigidBody3D with freeze=true.

signal swiped(hit_velocity: Vector3)
signal swiped_first_time(hit_velocity: Vector3)

@export var swipe_speed_threshold: float = 8.0
@export var detect_radius: float = 1.5
@export var detect_height: float = 2.0

## Knockback
@export var knockback_force: float = 12.0
@export var torque_force: float = 8.0
@export var recover_time: float = 3.0

var _rb: RigidBody3D
var _launched: bool = false
var _ever_swiped: bool = false
var _recover_timer: float = 0.0


func _ready() -> void:
	_rb = get_parent() as RigidBody3D
	if not _rb:
		return

	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)

	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = detect_radius
	cylinder.height = detect_height
	shape.shape = cylinder
	shape.position.y = detect_height * 0.5
	add_child(shape)


func _process(delta: float) -> void:
	if not _launched:
		return
	_recover_timer -= delta
	if _recover_timer <= 0.0:
		_launched = false
		if _rb:
			_rb.linear_velocity = Vector3.ZERO
			_rb.angular_velocity = Vector3.ZERO
			_rb.gravity_scale = 0.0
			_rb.freeze = true


func _on_body_entered(body: Node3D) -> void:
	if _launched:
		return
	if not body.is_in_group("tail"):
		return
	var tail_rb := body as RigidBody3D
	if not tail_rb or tail_rb.linear_velocity.length() < swipe_speed_threshold:
		return
	_launch(tail_rb.linear_velocity)


func _launch(hit_velocity: Vector3) -> void:
	_launched = true
	_recover_timer = recover_time
	swiped.emit(hit_velocity)
	if not _ever_swiped:
		_ever_swiped = true
		swiped_first_time.emit(hit_velocity)

	if not _rb:
		return

	# Unfreeze — same pattern as enemy.gd
	_rb.freeze = false
	_rb.gravity_scale = 1.0

	# Knockback impulse: hit direction + upward
	var hit_dir := hit_velocity.normalized()
	var impulse := hit_dir * knockback_force + Vector3.UP * knockback_force * 0.5
	_rb.apply_central_impulse(impulse)

	# Tumbling torque
	var torque_axis := hit_dir.cross(Vector3.UP).normalized()
	if torque_axis.length_squared() < 0.01:
		torque_axis = Vector3.RIGHT
	_rb.apply_torque_impulse(torque_axis * torque_force)
