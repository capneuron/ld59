# shape_recognizer.gd
class_name ShapeRecognizer
extends RefCounted

## $1 Unistroke Recognizer adapted for GDScript.
## Input: Array of Vector2 points (x/z from 3D).
## Output: best matching shape name + score.

const SAMPLE_COUNT := 64
const SQUARE_SIZE := 250.0
const HALF_DIAGONAL := 0.5 * sqrt(2.0) * SQUARE_SIZE
const ANGLE_RANGE := deg_to_rad(45.0)
const ANGLE_STEP := deg_to_rad(2.0)
const PHI := 0.5 * (sqrt(5.0) - 1.0)  # golden ratio for search

var _templates: Array[Dictionary] = []


func _init() -> void:
	_register_defaults()


func add_template(shape_name: String, points: Array[Vector2]) -> void:
	var processed := _process_points(points)
	_templates.append({"name": shape_name, "points": processed})


func recognize(points: Array[Vector2], min_score: float = 0.75) -> Dictionary:
	## Returns {"name": String, "score": float} or {"name": "", "score": 0.0} if no match.
	if points.size() < 8:
		return {"name": "", "score": 0.0}

	var processed := _process_points(points)
	var best_distance := INF
	var best_name := ""

	for template in _templates:
		var tmpl_points: Array[Vector2] = template["points"]
		var d: float = _distance_at_best_angle(processed, tmpl_points)
		if d < best_distance:
			best_distance = d
			best_name = template["name"]

	var score := 1.0 - best_distance / HALF_DIAGONAL
	if score < min_score:
		return {"name": "", "score": score}
	return {"name": best_name, "score": score}


func _process_points(raw: Array[Vector2]) -> Array[Vector2]:
	var resampled := _resample(raw, SAMPLE_COUNT)
	var rotated := _rotate_to_zero(resampled)
	var scaled := _scale_to_square(rotated)
	var translated := _translate_to_origin(scaled)
	return translated


func _resample(points: Array[Vector2], n: int) -> Array[Vector2]:
	var total_len := 0.0
	for i in range(1, points.size()):
		total_len += points[i].distance_to(points[i - 1])

	var interval := total_len / (n - 1)
	var accumulated := 0.0
	var result: Array[Vector2] = [points[0]]
	var src: Array[Vector2] = points.duplicate()
	var i := 1

	while i < src.size():
		var d := src[i].distance_to(src[i - 1])
		if accumulated + d >= interval:
			var t := (interval - accumulated) / d
			var new_point := src[i - 1].lerp(src[i], t)
			result.append(new_point)
			src.insert(i, new_point)
			accumulated = 0.0
		else:
			accumulated += d
		i += 1

	# Edge case: rounding errors may leave us one point short
	while result.size() < n:
		result.append(src[src.size() - 1])

	return result


func _rotate_to_zero(points: Array[Vector2]) -> Array[Vector2]:
	var centroid := _centroid(points)
	var angle := atan2(centroid.y - points[0].y, centroid.x - points[0].x)
	return _rotate_by(points, -angle)


func _rotate_by(points: Array[Vector2], angle: float) -> Array[Vector2]:
	var centroid := _centroid(points)
	var cos_a := cos(angle)
	var sin_a := sin(angle)
	var result: Array[Vector2] = []
	for p in points:
		var dx := p.x - centroid.x
		var dy := p.y - centroid.y
		result.append(Vector2(
			dx * cos_a - dy * sin_a + centroid.x,
			dx * sin_a + dy * cos_a + centroid.y
		))
	return result


func _scale_to_square(points: Array[Vector2]) -> Array[Vector2]:
	var min_pt := Vector2(INF, INF)
	var max_pt := Vector2(-INF, -INF)
	for p in points:
		min_pt.x = minf(min_pt.x, p.x)
		min_pt.y = minf(min_pt.y, p.y)
		max_pt.x = maxf(max_pt.x, p.x)
		max_pt.y = maxf(max_pt.y, p.y)

	var box_size := max_pt - min_pt
	var result: Array[Vector2] = []
	for p in points:
		result.append(Vector2(
			p.x * (SQUARE_SIZE / maxf(box_size.x, 0.001)),
			p.y * (SQUARE_SIZE / maxf(box_size.y, 0.001))
		))
	return result


func _translate_to_origin(points: Array[Vector2]) -> Array[Vector2]:
	var centroid := _centroid(points)
	var result: Array[Vector2] = []
	for p in points:
		result.append(p - centroid)
	return result


func _centroid(points: Array[Vector2]) -> Vector2:
	var sum := Vector2.ZERO
	for p in points:
		sum += p
	return sum / points.size()


func _distance_at_best_angle(points: Array[Vector2], template: Array[Vector2]) -> float:
	var a := -ANGLE_RANGE
	var b := ANGLE_RANGE
	var x1 := PHI * a + (1.0 - PHI) * b
	var x2 := (1.0 - PHI) * a + PHI * b
	var f1 := _distance_at_angle(points, template, x1)
	var f2 := _distance_at_angle(points, template, x2)

	while absf(b - a) > ANGLE_STEP:
		if f1 < f2:
			b = x2
			x2 = x1
			f2 = f1
			x1 = PHI * a + (1.0 - PHI) * b
			f1 = _distance_at_angle(points, template, x1)
		else:
			a = x1
			x1 = x2
			f1 = f2
			x2 = (1.0 - PHI) * a + PHI * b
			f2 = _distance_at_angle(points, template, x2)

	return minf(f1, f2)


func _distance_at_angle(points: Array[Vector2], template: Array[Vector2], angle: float) -> float:
	var rotated := _rotate_by(points, angle)
	return _path_distance(rotated, template)


func _path_distance(a: Array[Vector2], b: Array[Vector2]) -> float:
	var total := 0.0
	var n := mini(a.size(), b.size())
	for i in n:
		total += a[i].distance_to(b[i])
	return total / n


func _register_defaults() -> void:
	# Register each template in both directions for better recognition
	_add_with_reverse("square", _make_square())
	_add_with_reverse("star", _make_star())
	_add_with_reverse("heart", _make_heart())
	_add_with_reverse("triangle", _make_triangle())
	_add_with_reverse("circle", _make_circle())


func _add_with_reverse(shape_name: String, pts: Array[Vector2]) -> void:
	add_template(shape_name, pts)
	var reversed: Array[Vector2] = []
	for i in range(pts.size() - 1, -1, -1):
		reversed.append(pts[i])
	add_template(shape_name, reversed)


func _make_square() -> Array[Vector2]:
	var pts: Array[Vector2] = []
	var steps := 16
	# Right edge
	for i in steps:
		pts.append(Vector2(float(i) / steps, 0.0))
	# Top edge
	for i in steps:
		pts.append(Vector2(1.0, float(i) / steps))
	# Left edge (backwards)
	for i in steps:
		pts.append(Vector2(1.0 - float(i) / steps, 1.0))
	# Bottom edge (backwards)
	for i in steps:
		pts.append(Vector2(0.0, 1.0 - float(i) / steps))
	pts.append(Vector2(0.0, 0.0))
	return pts


func _make_star() -> Array[Vector2]:
	## 5-pointed star drawn as a single stroke (connecting every other vertex)
	var pts: Array[Vector2] = []
	var steps := 12
	var verts: Array[Vector2] = []
	for i in 5:
		var angle := TAU * float(i) / 5.0 - PI / 2.0
		verts.append(Vector2(cos(angle), sin(angle)))
	# Draw in star order: 0 → 2 → 4 → 1 → 3 → 0
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
		pts.append(Vector2(cos(t), sin(t)))
	pts.append(pts[0])
	return pts


func _make_heart() -> Array[Vector2]:
	var pts: Array[Vector2] = []
	var steps := 64
	for i in steps:
		var t := TAU * float(i) / steps
		var x := 16.0 * pow(sin(t), 3)
		var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		pts.append(Vector2(-y / 17.0, x / 17.0))
	pts.append(pts[0])
	return pts


func _make_triangle() -> Array[Vector2]:
	var pts: Array[Vector2] = []
	var steps := 16
	var a := Vector2(0.5, 0.0)
	var b := Vector2(1.0, 1.0)
	var c := Vector2(0.0, 1.0)
	for i in steps:
		pts.append(a.lerp(b, float(i) / steps))
	for i in steps:
		pts.append(b.lerp(c, float(i) / steps))
	for i in steps:
		pts.append(c.lerp(a, float(i) / steps))
	pts.append(a)
	return pts
