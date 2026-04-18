extends RigidBody3D

func _ready() -> void:
	add_to_group("tail")

@export var max_velocity: float = 200.0
@export var anchor: Node3D
@export var max_distance: float = 6.0


func set_size(radius: float, height: float, collision_height: float = -1.0) -> void:
	var mesh_node: MeshInstance3D = $MeshInstance3D
	var col_node: CollisionShape3D = $CollisionShape3D

	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = radius
	capsule_mesh.height = height
	mesh_node.mesh = capsule_mesh

	var col_h: float = collision_height if collision_height > 0.0 else height
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = radius
	capsule_shape.height = col_h
	col_node.shape = capsule_shape


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	# Clamp velocity
	if state.linear_velocity.length() > max_velocity:
		state.linear_velocity = state.linear_velocity.normalized() * max_velocity

	if not anchor:
		return

	var pos := state.transform.origin
	var anchor_pos := anchor.global_position
	var offset := pos - anchor_pos
	var dist := offset.length()

	if dist > max_distance:
		# Snap position back to the boundary
		var clamped_pos := anchor_pos + offset.normalized() * max_distance
		var xform := state.transform
		xform.origin = clamped_pos
		state.transform = xform

		# Remove outward velocity
		var away := offset.normalized()
		var vel_away := state.linear_velocity.dot(away)
		if vel_away > 0.0:
			state.linear_velocity -= away * vel_away
