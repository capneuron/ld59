extends Node3D

## Attach as a child of TrailSystem. Spawns rising scent particles along trails.

@export var emit_interval: float = 0.06  ## Seconds between particle spawns
@export var particle_lifetime: float = 2.0
@export var rise_speed: float = 0.6
@export var drift_strength: float = 0.15
@export var start_scale: float = 0.4
@export var end_scale: float = 0.05
@export var particle_color: Color = Color(0.3, 1.0, 0.5, 0.6)
@export var max_particles: int = 300

var _particles: Array[Dictionary] = []  ## {"pos", "vel", "age", "lifetime"}
var _mesh: ImmediateMesh
var _mesh_instance: MeshInstance3D
var _material: StandardMaterial3D
var _trail_system: Node
var _emit_timer: float = 0.0


func _ready() -> void:
	_trail_system = get_parent()

	_mesh = ImmediateMesh.new()
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = _mesh
	_mesh_instance.top_level = true
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.vertex_color_use_as_albedo = true
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	_mesh_instance.material_override = _material
	add_child(_mesh_instance)


func _process(delta: float) -> void:
	_emit_timer += delta

	if _emit_timer >= emit_interval:
		_emit_timer = 0.0
		_spawn_from_trails()

	# Update existing particles
	var i := _particles.size() - 1
	while i >= 0:
		var p := _particles[i]
		p["age"] += delta
		if p["age"] >= p["lifetime"]:
			_particles.remove_at(i)
		else:
			p["pos"] += p["vel"] * delta
		i -= 1

	_rebuild_mesh()


func _spawn_from_trails() -> void:
	if _particles.size() >= max_particles:
		return

	# Spawn along active trail
	var active_trail: Array = _trail_system.get("_active_trail")
	if active_trail and active_trail.size() >= 2:
		_spawn_at(active_trail[active_trail.size() - 1])

	# Spawn along fading trails
	var fading_trails: Array = _trail_system.get("_fading_trails")
	if not fading_trails:
		return
	for trail in fading_trails:
		var points: Array = trail["points"]
		var age: float = trail["age"]
		var lifetime: float = _trail_system.get("trail_lifetime")
		if points.size() < 2 or age > lifetime * 0.7:
			continue
		var idx := randi() % points.size()
		_spawn_at(points[idx])


func _spawn_at(pos: Vector3) -> void:
	if _particles.size() >= max_particles:
		return
	var drift_x := randf_range(-drift_strength, drift_strength)
	var drift_z := randf_range(-drift_strength, drift_strength)
	var vel := Vector3(drift_x, rise_speed, drift_z)
	var lt := particle_lifetime * randf_range(0.7, 1.3)
	_particles.append({"pos": pos, "vel": vel, "age": 0.0, "lifetime": lt})


func _rebuild_mesh() -> void:
	_mesh.clear_surfaces()
	if _particles.is_empty():
		return

	# Get camera basis for proper billboarding
	var cam := _find_camera()
	var cam_right := Vector3.RIGHT
	var cam_up := Vector3.UP
	if cam:
		cam_right = cam.global_basis.x
		cam_up = cam.global_basis.y

	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)

	for p in _particles:
		var t: float = p["age"] / p["lifetime"]
		var alpha: float = particle_color.a * (1.0 - t * t)
		var s: float = lerpf(start_scale, end_scale, t)
		var pos: Vector3 = p["pos"]
		var color := particle_color
		color.a = alpha

		var right := cam_right * s
		var up := cam_up * s

		var a := pos - right - up
		var b := pos + right - up
		var c := pos + right + up
		var d := pos - right + up

		_mesh.surface_set_color(color)
		_mesh.surface_add_vertex(a)
		_mesh.surface_set_color(color)
		_mesh.surface_add_vertex(b)
		_mesh.surface_set_color(color)
		_mesh.surface_add_vertex(c)

		_mesh.surface_set_color(color)
		_mesh.surface_add_vertex(a)
		_mesh.surface_set_color(color)
		_mesh.surface_add_vertex(c)
		_mesh.surface_set_color(color)
		_mesh.surface_add_vertex(d)

	_mesh.surface_end()


func _find_camera() -> Camera3D:
	var cam := get_viewport().get_camera_3d()
	if cam:
		return cam
	var current_scene := get_tree().current_scene
	if current_scene:
		var sub_vp := _find_subviewport(current_scene)
		if sub_vp:
			return sub_vp.get_camera_3d()
	return null

func _find_subviewport(node: Node) -> SubViewport:
	if node is SubViewport:
		return node
	for child in node.get_children():
		if child is Node:
			var result := _find_subviewport(child)
			if result:
				return result
	return null
