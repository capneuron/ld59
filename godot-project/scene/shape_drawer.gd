# shape_drawer.gd
class_name ShapeDrawer
extends Node3D

## Attach to any Node3D (NPC, etc.) to make it draw shapes on the ground.
## Call draw_shape() to start an animated drawing at the node's position.

signal drawing_started(shape_name: String)
signal drawing_finished(shape_name: String)

@export var draw_speed: float = 8.0  ## Points per second
@export var draw_scale: float = 3.0  ## Size of the drawn shape in world units
@export var trail_color: Color = Color(1.0, 0.8, 0.2, 1.0)
@export var trail_width: float = 0.3
@export var trail_lifetime: float = 6.0  ## How long the trail stays visible after drawing
@export var y_offset: float = 0.02

var _shape_points: Array[Vector2] = []  ## 2D template points for current shape
var _draw_index: float = 0.0  ## Current progress (fractional index into _shape_points)
var _draw_origin: Vector3 = Vector3.ZERO  ## World position center of drawing
var _is_drawing := false
var _current_shape_name := ""

var _trail_points: Array[Vector3] = []  ## Built up during drawing
var _fading_trails: Array[Dictionary] = []

var _mesh: ImmediateMesh
var _mesh_instance: MeshInstance3D
var _material: StandardMaterial3D


func _ready() -> void:
	_mesh = ImmediateMesh.new()
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = _mesh
	_mesh_instance.top_level = true
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.vertex_color_use_as_albedo = true

	_mesh_instance.material_override = _material
	add_child(_mesh_instance)


## Start drawing a shape. shape_name must be one of: "square", "star", "circle", "heart", "triangle"
## Optionally pass an origin position; defaults to this node's global_position.
func draw_shape(shape_name: String, origin := Vector3.ZERO) -> void:
	_shape_points = _get_shape_points(shape_name)
	if _shape_points.is_empty():
		push_warning("ShapeDrawer: unknown shape '%s'" % shape_name)
		return

	if origin == Vector3.ZERO:
		_draw_origin = global_position
	else:
		_draw_origin = origin
	_draw_origin.y = y_offset

	_current_shape_name = shape_name
	_draw_index = 0.0
	_trail_points.clear()
	_is_drawing = true
	drawing_started.emit(shape_name)


func is_drawing() -> bool:
	return _is_drawing


func _process(delta: float) -> void:
	# Animate drawing
	if _is_drawing:
		_draw_index += draw_speed * delta
		var target_index := mini(int(_draw_index), _shape_points.size() - 1)

		# Add new points up to current index
		while _trail_points.size() <= target_index:
			var idx := _trail_points.size()
			var pt := _shape_points[idx]
			var world_pos := Vector3(
				_draw_origin.x + pt.x * draw_scale,
				y_offset,
				_draw_origin.z + pt.y * draw_scale
			)
			_trail_points.append(world_pos)

		# Move parent node to the latest trail point
		var parent := get_parent() as Node3D
		if parent and not _trail_points.is_empty():
			var target_pos := _trail_points[_trail_points.size() - 1]
			parent.global_position.x = target_pos.x
			parent.global_position.z = target_pos.z

			# Face movement direction (ginnie model faces +X, offset +90°)
			if _trail_points.size() >= 2:
				var prev := _trail_points[_trail_points.size() - 2]
				var dir := target_pos - prev
				dir.y = 0.0
				if dir.length_squared() > 0.001:
					parent.global_rotation.y = atan2(dir.x, dir.z) + PI / 2.0

		# Check if done
		if target_index >= _shape_points.size() - 1:
			_is_drawing = false
			_fading_trails.append({"points": _trail_points.duplicate(), "age": 0.0, "color": trail_color})
			_trail_points.clear()
			drawing_finished.emit(_current_shape_name)

	# Age fading trails
	var i := _fading_trails.size() - 1
	while i >= 0:
		_fading_trails[i]["age"] += delta
		if _fading_trails[i]["age"] >= trail_lifetime:
			_fading_trails.remove_at(i)
		i -= 1

	_rebuild_mesh()


func _rebuild_mesh() -> void:
	_mesh.clear_surfaces()

	# Draw active trail (being drawn)
	if _trail_points.size() >= 2:
		_draw_trail_strip(_trail_points, 1.0, trail_color)

	# Draw fading trails
	for trail in _fading_trails:
		var alpha: float = 1.0 - float(trail["age"]) / trail_lifetime
		var color: Color = trail.get("color", trail_color) as Color
		_draw_trail_strip(trail["points"], alpha, color)


func _draw_trail_strip(points: Array[Vector3], alpha: float, color: Color) -> void:
	if points.size() < 2:
		return

	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in range(points.size() - 1):
		var p0 := points[i]
		var p1 := points[i + 1]

		var forward := (p1 - p0).normalized()
		var right := forward.cross(Vector3.UP).normalized() * trail_width * 0.5

		var c := color
		c.a = alpha

		var a := p0 + right
		var b := p0 - right
		var d := p1 + right
		var e := p1 - right

		_mesh.surface_set_color(c)
		_mesh.surface_add_vertex(a)
		_mesh.surface_set_color(c)
		_mesh.surface_add_vertex(b)
		_mesh.surface_set_color(c)
		_mesh.surface_add_vertex(d)

		_mesh.surface_set_color(c)
		_mesh.surface_add_vertex(b)
		_mesh.surface_set_color(c)
		_mesh.surface_add_vertex(e)
		_mesh.surface_set_color(c)
		_mesh.surface_add_vertex(d)

	_mesh.surface_end()


func _get_shape_points(shape_name: String) -> Array[Vector2]:
	match shape_name:
		"square":
			return _make_square()
		"star":
			return _make_star()
		"circle":
			return _make_circle()
		"heart":
			return _make_heart()
		"triangle":
			return _make_triangle()
	return []


## --- Shape generators (centered around origin, normalized to ~[-0.5, 0.5]) ---

func _make_square() -> Array[Vector2]:
	var pts: Array[Vector2] = []
	var steps := 16
	for i in steps:
		pts.append(Vector2(float(i) / steps - 0.5, -0.5))
	for i in steps:
		pts.append(Vector2(0.5, float(i) / steps - 0.5))
	for i in steps:
		pts.append(Vector2(0.5 - float(i) / steps, 0.5))
	for i in steps:
		pts.append(Vector2(-0.5, 0.5 - float(i) / steps))
	pts.append(Vector2(-0.5, -0.5))
	return pts


func _make_star() -> Array[Vector2]:
	var pts: Array[Vector2] = []
	var steps := 12
	var verts: Array[Vector2] = []
	for i in 5:
		var angle := TAU * float(i) / 5.0 - PI / 2.0
		verts.append(Vector2(cos(angle) * 0.5, sin(angle) * 0.5))
	var order := [0, 2, 4, 1, 3, 0]
	for seg in range(order.size() - 1):
		var from := verts[order[seg]]
		var to := verts[order[seg + 1]]
		for j in steps:
			pts.append(from.lerp(to, float(j) / steps))
	pts.append(verts[order[0]])
	return pts


func _make_circle() -> Array[Vector2]:
	var pts: Array[Vector2] = []
	var steps := 64
	for i in steps:
		var t := TAU * float(i) / steps
		pts.append(Vector2(cos(t) * 0.5, sin(t) * 0.5))
	pts.append(pts[0])
	return pts


func _make_heart() -> Array[Vector2]:
	var pts: Array[Vector2] = []
	var steps := 64
	for i in steps:
		var t := TAU * float(i) / steps
		var x := 16.0 * pow(sin(t), 3)
		var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		pts.append(Vector2(-y / 34.0, x / 34.0))
	pts.append(pts[0])
	return pts


func _make_triangle() -> Array[Vector2]:
	var pts: Array[Vector2] = []
	var steps := 16
	var a := Vector2(0.0, -0.5)
	var b := Vector2(0.5, 0.5)
	var c := Vector2(-0.5, 0.5)
	for i in steps:
		pts.append(a.lerp(b, float(i) / steps))
	for i in steps:
		pts.append(b.lerp(c, float(i) / steps))
	for i in steps:
		pts.append(c.lerp(a, float(i) / steps))
	pts.append(a)
	return pts
