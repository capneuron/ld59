# trail_system.gd
extends Node3D

signal shape_closed(points: Array[Vector2])

@export var player: CharacterBody3D
@export var point_distance: float = 0.5  ## Min distance between recorded points
@export var min_points: int = 12  ## Min points needed for a valid shape
@export var trail_lifetime: float = 6.0  ## Seconds before trail fades
@export var trail_color: Color = Color(0.3, 1.0, 0.5, 1.0)
@export var trail_width: float = 0.3
@export var trail_y_offset: float = 0.02  ## Slight offset above ground to avoid z-fighting
@export var vibe_color: Color = Color(0.3, 0.5, 1.0, 1.0)  ## Blue for vibe
@export var signal_color: Color = Color(1.0, 0.6, 0.2, 1.0)  ## Orange for signal
@export var fail_color: Color = Color(1.0, 0.2, 0.2, 1.0)  ## Red for unrecognized

var _active_trail: Array[Vector3] = []  ## Current recording
var _fading_trails: Array[Dictionary] = []  ## {"points": Array[Vector3], "age": float}
var _drawing := false  ## Whether LMB is held

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
	_material.albedo_color = trail_color
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.vertex_color_use_as_albedo = true

	_mesh_instance.material_override = _material
	add_child(_mesh_instance)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Start drawing
			_drawing = true
			_active_trail.clear()
		else:
			# Stop drawing, submit trail
			_drawing = false
			_submit_trail()


func _physics_process(_delta: float) -> void:
	if not player or not _drawing:
		return

	var pos := player.global_position
	pos.y = trail_y_offset

	# Only add point if player moved enough
	if _active_trail.is_empty() or pos.distance_to(_active_trail[_active_trail.size() - 1]) >= point_distance:
		_active_trail.append(pos)


func _submit_trail() -> void:
	# Always leave a fading trail, even if too short to recognize
	if _active_trail.size() >= 2:
		_fading_trails.append({"points": _active_trail.duplicate(), "age": 0.0})

	if _active_trail.size() < min_points:
		_active_trail.clear()
		return

	# Convert to 2D (x/z) and emit
	var points_2d: Array[Vector2] = []
	for p in _active_trail:
		points_2d.append(Vector2(p.x, p.z))
	_active_trail.clear()

	shape_closed.emit(points_2d)


func _process(delta: float) -> void:
	# Age fading trails
	var i := _fading_trails.size() - 1
	while i >= 0:
		_fading_trails[i]["age"] += delta
		if _fading_trails[i]["age"] >= trail_lifetime:
			_fading_trails.remove_at(i)
		i -= 1

	_rebuild_mesh()


func flash_last_trail(color: Color) -> void:
	## Call after shape_closed to color the most recent fading trail.
	if _fading_trails.is_empty():
		return
	_fading_trails[_fading_trails.size() - 1]["color"] = color


func _rebuild_mesh() -> void:
	_mesh.clear_surfaces()

	# Draw active trail
	if _active_trail.size() >= 2:
		_draw_trail_strip(_active_trail, 1.0)

	# Draw fading trails
	for trail in _fading_trails:
		var alpha: float = 1.0 - float(trail["age"]) / trail_lifetime
		var override_color := trail.get("color", Color(-1, -1, -1, -1)) as Color
		_draw_trail_strip(trail["points"], alpha, override_color)


func _draw_trail_strip(points: Array[Vector3], alpha: float, color_override := Color(-1, -1, -1, -1)) -> void:
	if points.size() < 2:
		return

	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in range(points.size() - 1):
		var p0 := points[i]
		var p1 := points[i + 1]

		var forward := (p1 - p0).normalized()
		var right := forward.cross(Vector3.UP).normalized() * trail_width * 0.5

		var color: Color
		if color_override.r >= 0.0:
			color = color_override
		else:
			color = trail_color
		color.a = alpha

		# Quad as two triangles
		var a := p0 + right
		var b := p0 - right
		var c := p1 + right
		var d := p1 - right

		_mesh.surface_set_color(color)
		_mesh.surface_add_vertex(a)
		_mesh.surface_set_color(color)
		_mesh.surface_add_vertex(b)
		_mesh.surface_set_color(color)
		_mesh.surface_add_vertex(c)

		_mesh.surface_set_color(color)
		_mesh.surface_add_vertex(b)
		_mesh.surface_set_color(color)
		_mesh.surface_add_vertex(d)
		_mesh.surface_set_color(color)
		_mesh.surface_add_vertex(c)

	_mesh.surface_end()
