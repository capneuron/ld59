extends RigidBody3D

signal killed

@export var swipe_speed_threshold: float = 8.0
@export var knockback_force: float = 12.0
@export var torque_force: float = 8.0
@export var cleanup_delay: float = 4.0

var _alive := true
var _time_since_death := 0.0


func _ready() -> void:
	$SwipeDetector.body_entered.connect(_on_swipe_detector_body_entered)


func _on_swipe_detector_body_entered(body: Node3D) -> void:
	if not _alive:
		return
	if not body.is_in_group("tail"):
		return

	if (body as RigidBody3D).linear_velocity.length() >= swipe_speed_threshold:
		_kill((body as RigidBody3D).linear_velocity)


func _kill(hit_velocity: Vector3) -> void:
	_alive = false

	# Unfreeze to let physics take over
	freeze = false

	# Disable swipe detector so it can't be hit again
	$SwipeDetector/CollisionShape3D.set_deferred("disabled", true)

	# Apply knockback impulse in hit direction + upward
	var hit_dir := hit_velocity.normalized()
	var impulse := hit_dir * knockback_force + Vector3.UP * knockback_force * 0.5
	apply_central_impulse(impulse)

	# Apply torque for tumbling rotation
	var torque_axis := hit_dir.cross(Vector3.UP).normalized()
	if torque_axis.length_squared() < 0.01:
		torque_axis = Vector3.RIGHT
	apply_torque_impulse(torque_axis * torque_force)

	killed.emit()


func _process(delta: float) -> void:
	if not _alive:
		_time_since_death += delta
		if _time_since_death >= cleanup_delay:
			queue_free()
