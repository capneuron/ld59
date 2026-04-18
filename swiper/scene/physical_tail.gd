extends Node3D

@export var tail_scene: PackedScene
@export var player: Node3D
@export var segment_count: int = 4
@export var segment_spacing: float = 1.16
@export var joint_bias: float = 0.99
@export var joint_damping: float = 4.0
@export var max_distance: float = 6.0
@export var max_velocity: float = 200.0
@export var tube_sides: int = 6
@export var tube_color: Color = Color(1.0, 0.64, 0.0)

@export_group("Taper")
## Base (near player) and tip values. Interpolated per segment using taper_curve.
@export var base_radius: float = 0.4
@export var tip_radius: float = 0.12
@export var base_height: float = 1.0
@export var tip_height: float = 0.4
@export var base_mass: float = 20.0
@export var tip_mass: float = 2.0
## Controls falloff shape from base (0) to tip (1). Linear if unset.
@export var taper_curve: Curve

var _tails: Array[RigidBody3D] = []
var _radii: PackedFloat32Array = []
var _tube_mesh: ImmediateMesh
var _tube_instance: MeshInstance3D
var _tube_material: StandardMaterial3D


func _sample_taper(t: float) -> float:
	if taper_curve:
		return taper_curve.sample(t)
	return t


func _ready() -> void:
	if not tail_scene or not player:
		return

	# Create the visual tube
	_tube_mesh = ImmediateMesh.new()
	_tube_instance = MeshInstance3D.new()
	_tube_instance.mesh = _tube_mesh
	_tube_instance.top_level = true
	_tube_material = StandardMaterial3D.new()
	_tube_material.albedo_color = tube_color
	_tube_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tube_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_tube_instance.material_override = _tube_material
	add_child(_tube_instance)

	# Store radii for tube rendering (player ring + each segment)
	_radii.append(base_radius)

	for i in segment_count:
		var t: float = float(i) / maxf(segment_count - 1, 1)
		var taper: float = _sample_taper(t)
		var x_pos: float = segment_spacing * 0.5 + segment_spacing * i

		var radius: float = lerpf(base_radius, tip_radius, taper)
		var height: float = lerpf(base_height, tip_height, taper)
		var mass: float = lerpf(base_mass, tip_mass, taper)

		_radii.append(radius)

		# Create tail segment
		var tail: RigidBody3D = tail_scene.instantiate()
		tail.name = "Tail%d" % i
		tail.position = Vector3(x_pos, 0.0, 0.0)
		tail.mass = mass
		tail.max_velocity = max_velocity
		tail.max_distance = max_distance
		# Collision height spans the full spacing so there are no gaps
		var col_height: float = maxf(height, segment_spacing + radius * 2.0)
		tail.set_size(radius, height, col_height)

		add_child(tail)

		# Set anchor to previous tail or player
		if i == 0:
			tail.anchor = player
		else:
			tail.anchor = _tails[i - 1]

		_tails.append(tail)

		# Create joint
		var joint := PinJoint3D.new()
		joint.name = "Join%d" % i
		var joint_x: float
		if i == 0:
			joint_x = 0.0
		else:
			joint_x = (x_pos + _tails[i - 1].position.x) / 2.0
		joint.position = Vector3(joint_x, 0.0, 0.0)
		joint.set("params/bias", joint_bias)
		joint.set("params/damping", joint_damping)
		joint.exclude_nodes_from_collision = false
		add_child(joint)

		if i == 0:
			joint.node_a = joint.get_path_to(player)
		else:
			joint.node_a = joint.get_path_to(_tails[i - 1])
		joint.node_b = joint.get_path_to(tail)


func get_tip_speed() -> float:
	if _tails.is_empty():
		return 0.0
	return _tails[_tails.size() - 1].linear_velocity.length()


func get_tail_speeds() -> PackedFloat32Array:
	var speeds := PackedFloat32Array()
	for tail in _tails:
		speeds.append(tail.linear_velocity.length())
	return speeds


func _process(_delta: float) -> void:
	if _tails.is_empty():
		return
	_rebuild_tube()


func _rebuild_tube() -> void:
	_tube_mesh.clear_surfaces()

	# Build point list: player position + all tail positions
	var points: Array[Vector3] = []
	points.append(player.global_position)
	for tail in _tails:
		points.append(tail.global_position)

	if points.size() < 2:
		return

	# Precompute rings
	var ring_count := points.size()
	var rings: Array[PackedVector3Array] = []

	for i in ring_count:
		var radius: float = _radii[i]
		var center: Vector3 = points[i]

		# Direction along the tail
		var forward: Vector3
		if i < ring_count - 1:
			forward = (points[i + 1] - points[i]).normalized()
		else:
			forward = (points[i] - points[i - 1]).normalized()

		# Build a local coordinate frame
		var up := Vector3.UP
		if absf(forward.dot(up)) > 0.99:
			up = Vector3.FORWARD
		var right := forward.cross(up).normalized()
		up = right.cross(forward).normalized()

		var ring := PackedVector3Array()
		ring.resize(tube_sides)
		for j in tube_sides:
			var angle: float = TAU * j / tube_sides
			var offset: Vector3 = right * cos(angle) * radius + up * sin(angle) * radius
			ring[j] = center + offset
		rings.append(ring)

	# Draw triangle strips between consecutive rings
	_tube_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in ring_count - 1:
		var ring_a: PackedVector3Array = rings[i]
		var ring_b: PackedVector3Array = rings[i + 1]

		for j in tube_sides:
			var j_next: int = (j + 1) % tube_sides

			_tube_mesh.surface_add_vertex(ring_a[j])
			_tube_mesh.surface_add_vertex(ring_b[j])
			_tube_mesh.surface_add_vertex(ring_b[j_next])

			_tube_mesh.surface_add_vertex(ring_a[j])
			_tube_mesh.surface_add_vertex(ring_b[j_next])
			_tube_mesh.surface_add_vertex(ring_a[j_next])

	# Cap the tip
	var last_center: Vector3 = points[ring_count - 1]
	var last_ring: PackedVector3Array = rings[ring_count - 1]
	for j in tube_sides:
		var j_next: int = (j + 1) % tube_sides
		_tube_mesh.surface_add_vertex(last_ring[j])
		_tube_mesh.surface_add_vertex(last_center)
		_tube_mesh.surface_add_vertex(last_ring[j_next])

	_tube_mesh.surface_end()
