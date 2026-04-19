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

## Spawn boom effect on swipe
@export var boom_on_swipe: bool = false
## Destroy parent after swipe (-1 = don't destroy)
@export var destroy_delay: float = -1.0

var _boom_scene: PackedScene = preload("res://scene/boom.tscn")

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
	if destroy_delay >= 0.0:
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

	if boom_on_swipe:
		_spawn_boom()
	if destroy_delay >= 0.0:
		_destroy_after_delay()


func _spawn_boom() -> void:
	if not _rb:
		return
	var pos := _rb.global_position
	var boom := _boom_scene.instantiate()
	_rb.get_parent().add_child(boom)
	boom.global_position = pos
	var sprite: AnimatedSprite3D = boom.get_node("AnimatedSprite3D")
	sprite.animation_finished.connect(boom.queue_free)


func _destroy_after_delay() -> void:
	if not _rb:
		return
	get_tree().create_timer(destroy_delay).timeout.connect(func():
		if is_instance_valid(_rb):
			_rb.queue_free()
	)
