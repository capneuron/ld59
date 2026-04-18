extends Node3D

@export var segment_count: int = 4
@export var segment_spacing: float = 0.15
@export var segment_size: float = 0.1
@export var size_curve: Curve
@export var stiffness: float = 30.0
@export var damping: float = 8.0
@export var gravity: float = 4.0
@export var tail_color: Color = Color(1.0, 0.64, 0.0)

var _positions: PackedVector3Array
var _velocities: PackedVector3Array
var _segments: Array[MeshInstance3D]
var _material: StandardMaterial3D


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = tail_color
	_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	_positions.resize(segment_count)
	_velocities.resize(segment_count)

	var anchor := global_position
	for i in segment_count:
		var pos := anchor + Vector3(segment_spacing * (i + 1), 0.0, 0.0)
		_positions[i] = pos
		_velocities[i] = Vector3.ZERO

		var mesh_instance := MeshInstance3D.new()
		var box := BoxMesh.new()
		var t: float = float(i) / maxf(segment_count - 1, 1)
		var scale_factor: float = size_curve.sample(t) if size_curve else lerpf(1.0, 0.3, t)
		var s: float = segment_size * scale_factor
		box.size = Vector3(s, s, s)
		box.material = _material
		mesh_instance.mesh = box
		mesh_instance.top_level = true
		add_child(mesh_instance)
		_segments.append(mesh_instance)


func _physics_process(delta: float) -> void:
	var anchor := global_position

	for i in segment_count:
		var target: Vector3
		if i == 0:
			target = anchor
		else:
			target = _positions[i - 1]

		var current := _positions[i]
		var diff := target - current
		var dist := diff.length()
		var rest := segment_spacing

		# Spring force toward parent segment
		var spring_force := diff.normalized() * (dist - rest) * stiffness

		# Gravity pulls tail down
		var gravity_force := Vector3(0.0, -gravity, 0.0)

		# Apply forces
		_velocities[i] += (spring_force + gravity_force) * delta
		_velocities[i] *= 1.0 - damping * delta
		_positions[i] += _velocities[i] * delta

		# Enforce max distance constraint
		diff = _positions[i] - target
		if diff.length() > rest * 1.5:
			_positions[i] = target + diff.normalized() * rest * 1.5

		# Keep tail above ground
		if _positions[i].y < 0.05:
			_positions[i].y = 0.05
			_velocities[i].y = 0.0

	# Update visuals
	for i in segment_count:
		_segments[i].global_position = _positions[i]
