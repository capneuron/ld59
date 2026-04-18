# grass_field.gd
extends MultiMeshInstance3D

## Scatters simple upright grass blades across a flat area.
## Blades are small quads that stand up from the ground, giving a 3D grass feel.

@export var area_size: float = 50.0  ## Size of the square area to cover
@export var blade_count: int = 3000  ## Number of grass blades
@export var blade_width: float = 0.3  ## Width of each blade
@export var blade_height_min: float = 0.4  ## Min height
@export var blade_height_max: float = 0.8  ## Max height
@export var grass_color: Color = Color(0.2, 0.451, 0.102, 1.0)
@export var color_variation: float = 0.08  ## Random color shift per blade
@export var seed_value: int = 42


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_generate()


func _generate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	# Create blade mesh: two crossed quads for each blade (X shape from above)
	var mesh := _create_blade_mesh()

	# Set up MultiMesh
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = blade_count

	var half := area_size * 0.5

	for i in blade_count:
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half)
		var rot := rng.randf() * TAU
		var h := rng.randf_range(blade_height_min, blade_height_max)
		var scale_y := h / blade_height_max

		var xform := Transform3D.IDENTITY
		xform = xform.scaled(Vector3(1.0, scale_y, 1.0))
		xform = xform.rotated(Vector3.UP, rot)
		xform.origin = Vector3(x, 0.0, z)

		mm.set_instance_transform(i, xform)

		# Color variation
		var shift := rng.randf_range(-color_variation, color_variation)
		var c := Color(
			clampf(grass_color.r + shift, 0.0, 1.0),
			clampf(grass_color.g + shift * 1.5, 0.0, 1.0),
			clampf(grass_color.b + shift * 0.5, 0.0, 1.0),
			1.0
		)
		mm.set_instance_color(i, c)

	multimesh = mm


func _create_blade_mesh() -> ArrayMesh:
	var arr_mesh := ArrayMesh.new()
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var normals := PackedVector3Array()

	var hw := blade_width * 0.5
	var h := blade_height_max

	# Two crossed quads forming an X from above
	for angle_offset in [0.0, PI * 0.5]:
		var dx := cos(angle_offset) * hw
		var dz := sin(angle_offset) * hw

		# Bottom-left, top-left, top-right, bottom-left, top-right, bottom-right
		var bl := Vector3(-dx, 0.0, -dz)
		var tl := Vector3(-dx * 0.3, h, -dz * 0.3)  # Narrower at top
		var br := Vector3(dx, 0.0, dz)
		var tr := Vector3(dx * 0.3, h, dz * 0.3)

		# Darker at bottom, lighter at top
		var c_bottom := Color(1.0, 1.0, 1.0, 1.0)
		var c_top := Color(1.0, 1.0, 1.0, 1.0)

		# Triangle 1
		verts.append(bl); colors.append(c_bottom); normals.append(Vector3.BACK)
		verts.append(tl); colors.append(c_top); normals.append(Vector3.BACK)
		verts.append(tr); colors.append(c_top); normals.append(Vector3.BACK)
		# Triangle 2
		verts.append(bl); colors.append(c_bottom); normals.append(Vector3.BACK)
		verts.append(tr); colors.append(c_top); normals.append(Vector3.BACK)
		verts.append(br); colors.append(c_bottom); normals.append(Vector3.BACK)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_NORMAL] = normals

	# Material: flat color + receive shadows, double-sided, vertex colors
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://grass_blade.gdshader")

	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	arr_mesh.surface_set_material(0, mat)

	return arr_mesh
