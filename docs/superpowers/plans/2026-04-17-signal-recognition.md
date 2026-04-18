# Signal Recognition System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a trail drawing and shape recognition system so the player can draw closed shapes on the ground to trigger vibes and signals.

**Architecture:** Three new GDScript files — a trail renderer that records and displays the player's movement path, a shape recognizer implementing the $1 Unistroke algorithm, and a vibe/signal state manager that interprets recognized shapes. The trail system attaches to the player and emits events when a closed shape is detected. The recognizer is a pure-logic class with no scene dependencies. The state manager receives recognition results and manages vibe state + signal dispatch.

**Tech Stack:** Godot 4.6, GDScript, ImmediateMesh for trail rendering

---

### Task 1: Shape Recognizer (Pure Logic)

**Files:**
- Create: `swiper/scene/shape_recognizer.gd`

This is a standalone class with no scene dependencies. It implements the $1 Unistroke Recognizer algorithm.

- [ ] **Step 1: Create the shape recognizer script**

```gdscript
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
		var d := _distance_at_best_angle(processed, template["points"])
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
	var src := points.duplicate()
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
	# Square (vibe: sincere)
	add_template("square", _make_square())
	# Figure-8 (vibe: confident)
	add_template("figure8", _make_figure8())
	# S-curve (vibe: gentle)
	add_template("scurve", _make_scurve())
	# Heart (signal: court)
	add_template("heart", _make_heart())
	# Triangle (signal: warn)
	add_template("triangle", _make_triangle())
	# Zigzag (signal: greet)
	add_template("zigzag", _make_zigzag())


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


func _make_figure8() -> Array[Vector2]:
	var pts: Array[Vector2] = []
	var steps := 64
	for i in steps:
		var t := TAU * float(i) / steps
		pts.append(Vector2(sin(t), sin(2.0 * t) * 0.5))
	pts.append(pts[0])
	return pts


func _make_scurve() -> Array[Vector2]:
	var pts: Array[Vector2] = []
	var steps := 64
	for i in steps:
		var t := float(i) / steps
		# S-curve: sine wave over one full period, traced top to bottom
		pts.append(Vector2(sin(t * TAU) * 0.5, t))
	# Close the loop by returning along a straight-ish path
	for i in steps:
		var t := 1.0 - float(i) / steps
		pts.append(Vector2(sin(t * TAU) * 0.5 + 0.05, t))
	return pts


func _make_heart() -> Array[Vector2]:
	var pts: Array[Vector2] = []
	var steps := 64
	for i in steps:
		var t := TAU * float(i) / steps
		var x := 16.0 * pow(sin(t), 3)
		var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		pts.append(Vector2(x / 17.0, -y / 17.0))
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


func _make_zigzag() -> Array[Vector2]:
	var pts: Array[Vector2] = []
	var steps := 8
	var zag_count := 4
	for z in zag_count:
		var y_start := float(z) / zag_count
		var y_end := float(z + 1) / zag_count
		var x_target := 1.0 if z % 2 == 0 else 0.0
		for i in steps:
			var t := float(i) / steps
			pts.append(Vector2(
				lerpf(1.0 - x_target, x_target, t),
				lerpf(y_start, y_end, t)
			))
	# Close by returning back
	for z in zag_count:
		var idx := zag_count - 1 - z
		var y_start := float(idx + 1) / zag_count
		var y_end := float(idx) / zag_count
		var x_target := 1.0 if idx % 2 == 0 else 0.0
		for i in steps:
			var t := float(i) / steps
			pts.append(Vector2(
				lerpf(x_target, 1.0 - x_target, t) + 0.05,
				lerpf(y_start, y_end, t)
			))
	return pts
```

- [ ] **Step 2: Verify the script parses without errors**

Open the Godot editor or run the project. The `ShapeRecognizer` class should be available as a type via `class_name`. No scene integration needed yet.

- [ ] **Step 3: Commit**

```bash
git add swiper/scene/shape_recognizer.gd
git commit -m "feat: add $1 unistroke shape recognizer with 6 templates"
```

---

### Task 2: Trail System (Recording + Rendering)

**Files:**
- Create: `swiper/scene/trail_system.gd`

Attaches to the player. Records movement trail, renders it on the ground, detects closure, and emits a signal with the closed shape points.

- [ ] **Step 1: Create the trail system script**

```gdscript
# trail_system.gd
extends Node3D

signal shape_closed(points: Array[Vector2])

@export var player: CharacterBody3D
@export var point_distance: float = 0.5  ## Min distance between recorded points
@export var closure_distance: float = 2.0  ## Max start-end distance to consider closed
@export var min_points: int = 12  ## Min points needed for a valid shape
@export var trail_lifetime: float = 6.0  ## Seconds before trail fades
@export var trail_color: Color = Color(0.3, 1.0, 0.5, 1.0)
@export var trail_width: float = 0.15
@export var trail_y_offset: float = 0.02  ## Slight offset above ground to avoid z-fighting

var _active_trail: Array[Vector3] = []  ## Current recording
var _fading_trails: Array[Dictionary] = []  ## {"points": Array[Vector3], "age": float}

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


func _physics_process(_delta: float) -> void:
	if not player:
		return

	var pos := player.global_position
	pos.y = trail_y_offset

	# Only add point if player moved enough
	if _active_trail.is_empty() or pos.distance_to(_active_trail[_active_trail.size() - 1]) >= point_distance:
		_active_trail.append(pos)
		_check_closure()


func _check_closure() -> void:
	if _active_trail.size() < min_points:
		return

	var start := _active_trail[0]
	var end := _active_trail[_active_trail.size() - 1]

	if start.distance_to(end) < closure_distance:
		# Convert to 2D (x/z) and emit
		var points_2d: Array[Vector2] = []
		for p in _active_trail:
			points_2d.append(Vector2(p.x, p.z))

		# Move to fading trails for visual
		_fading_trails.append({"points": _active_trail.duplicate(), "age": 0.0})
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


func _rebuild_mesh() -> void:
	_mesh.clear_surfaces()

	# Draw active trail
	if _active_trail.size() >= 2:
		_draw_trail_strip(_active_trail, 1.0)

	# Draw fading trails
	for trail in _fading_trails:
		var alpha := 1.0 - trail["age"] / trail_lifetime
		_draw_trail_strip(trail["points"], alpha)


func _draw_trail_strip(points: Array[Vector3], alpha: float) -> void:
	if points.size() < 2:
		return

	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in range(points.size() - 1):
		var p0 := points[i]
		var p1 := points[i + 1]

		var forward := (p1 - p0).normalized()
		var right := forward.cross(Vector3.UP).normalized() * trail_width * 0.5

		var color := trail_color
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
```

- [ ] **Step 2: Verify the script parses without errors**

Open Godot editor. The script should load without parse errors.

- [ ] **Step 3: Commit**

```bash
git add swiper/scene/trail_system.gd
git commit -m "feat: add trail system with ground rendering and closure detection"
```

---

### Task 3: Signal Manager (Vibe State + Signal Dispatch)

**Files:**
- Create: `swiper/scene/signal_manager.gd`

Connects to the trail system's `shape_closed` signal. Uses ShapeRecognizer to identify shapes. Manages vibe state and emits combined (vibe, signal) events.

- [ ] **Step 1: Create the signal manager script**

```gdscript
# signal_manager.gd
extends Node

## Manages vibe state and signal dispatch.
## Connect trail_system.shape_closed to on_shape_closed().

signal vibe_changed(vibe_name: String)
signal vibe_expired()
signal signal_triggered(vibe_name: String, signal_name: String)
signal shape_recognized(shape_name: String, shape_type: String)
signal shape_unrecognized()

@export var vibe_duration: float = 18.0  ## Seconds a vibe lasts

## Shape name -> type mapping
const SHAPE_TYPES := {
	"square": "vibe",
	"figure8": "vibe",
	"scurve": "vibe",
	"heart": "signal",
	"triangle": "signal",
	"zigzag": "signal",
}

## Shape name -> display name
const SHAPE_DISPLAY := {
	"square": "Sincere",
	"figure8": "Confident",
	"scurve": "Gentle",
	"heart": "Court",
	"triangle": "Warn",
	"zigzag": "Greet",
}

var _recognizer: ShapeRecognizer
var _current_vibe := ""  ## Empty = neutral
var _vibe_timer := 0.0


func _ready() -> void:
	_recognizer = ShapeRecognizer.new()


func _process(delta: float) -> void:
	if _current_vibe != "":
		_vibe_timer -= delta
		if _vibe_timer <= 0.0:
			_current_vibe = ""
			_vibe_timer = 0.0
			vibe_expired.emit()


func get_current_vibe() -> String:
	return _current_vibe


func get_current_vibe_display() -> String:
	if _current_vibe == "":
		return "Neutral"
	return SHAPE_DISPLAY.get(_current_vibe, _current_vibe)


func get_vibe_time_remaining() -> float:
	return maxf(_vibe_timer, 0.0)


func on_shape_closed(points: Array[Vector2]) -> void:
	var result := _recognizer.recognize(points)

	if result["name"] == "":
		shape_unrecognized.emit()
		return

	var shape_name: String = result["name"]
	var shape_type: String = SHAPE_TYPES.get(shape_name, "")

	shape_recognized.emit(shape_name, shape_type)

	if shape_type == "vibe":
		_current_vibe = shape_name
		_vibe_timer = vibe_duration
		vibe_changed.emit(shape_name)

	elif shape_type == "signal":
		signal_triggered.emit(_current_vibe, shape_name)
```

- [ ] **Step 2: Verify the script parses without errors**

Open Godot editor. The script should load without parse errors.

- [ ] **Step 3: Commit**

```bash
git add swiper/scene/signal_manager.gd
git commit -m "feat: add signal manager with vibe state machine"
```

---

### Task 4: Debug HUD for Signal System

**Files:**
- Modify: `swiper/scene/debug_panel.gd`

Add vibe status display and recognition feedback to the existing debug panel so you can see what's happening during development.

- [ ] **Step 1: Add signal debug display to debug_panel.gd**

Add the following export and variables at the top of the script (after existing vars):

```gdscript
@export var signal_manager_path: NodePath

var _signal_manager: Node
var _vibe_label: Label
var _recognition_label: Label
var _recognition_fade := 0.0
```

Add to `_ready()`, after the existing `if physical_tail_path:` block:

```gdscript
if signal_manager_path:
	_signal_manager = get_node(signal_manager_path)
	_signal_manager.shape_recognized.connect(_on_shape_recognized)
	_signal_manager.shape_unrecognized.connect(_on_shape_unrecognized)
	_signal_manager.vibe_changed.connect(_on_vibe_changed)
	_signal_manager.vibe_expired.connect(_on_vibe_expired)
```

Add to `_build_hud()`, after the existing `_hud_speed_label` setup:

```gdscript
# Vibe status label (bottom left)
_vibe_label = Label.new()
_vibe_label.anchor_left = 0.0
_vibe_label.anchor_right = 0.0
_vibe_label.anchor_top = 1.0
_vibe_label.anchor_bottom = 1.0
_vibe_label.offset_left = 8.0
_vibe_label.offset_right = 300.0
_vibe_label.offset_top = -60.0
_vibe_label.offset_bottom = -8.0
_vibe_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
_vibe_label.text = "Vibe: Neutral"
call_deferred("_add_vibe_label_to_parent")

# Recognition feedback (bottom center)
_recognition_label = Label.new()
_recognition_label.anchor_left = 0.5
_recognition_label.anchor_right = 0.5
_recognition_label.anchor_top = 1.0
_recognition_label.anchor_bottom = 1.0
_recognition_label.offset_left = -150.0
_recognition_label.offset_right = 150.0
_recognition_label.offset_top = -40.0
_recognition_label.offset_bottom = -8.0
_recognition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
_recognition_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
_recognition_label.modulate.a = 0.0
call_deferred("_add_recognition_label_to_parent")
```

Add these helper methods:

```gdscript
func _add_vibe_label_to_parent() -> void:
	get_parent().add_child(_vibe_label)


func _add_recognition_label_to_parent() -> void:
	get_parent().add_child(_recognition_label)


func _on_shape_recognized(shape_name: String, shape_type: String) -> void:
	var display: String = _signal_manager.SHAPE_DISPLAY.get(shape_name, shape_name)
	_recognition_label.text = "%s: %s" % [shape_type.to_upper(), display]
	_recognition_fade = 2.0


func _on_shape_unrecognized() -> void:
	_recognition_label.text = "???"
	_recognition_fade = 1.5


func _on_vibe_changed(_vibe_name: String) -> void:
	pass  # Updated in _process


func _on_vibe_expired() -> void:
	pass  # Updated in _process
```

Add to `_process()`, after the existing speed HUD update:

```gdscript
if _signal_manager:
	var vibe_display: String = _signal_manager.get_current_vibe_display()
	var remaining: float = _signal_manager.get_vibe_time_remaining()
	if remaining > 0.0:
		_vibe_label.text = "Vibe: %s (%.0fs)" % [vibe_display, remaining]
	else:
		_vibe_label.text = "Vibe: %s" % vibe_display

if _recognition_fade > 0.0:
	_recognition_fade -= delta
	_recognition_label.modulate.a = clampf(_recognition_fade, 0.0, 1.0)
```

Note: Change the existing `_process(_delta: float)` parameter name to `_process(delta: float)` since we now use it.

- [ ] **Step 2: Verify debug panel still works**

Run the project, press backtick to toggle debug panel. Verify no errors.

- [ ] **Step 3: Commit**

```bash
git add swiper/scene/debug_panel.gd
git commit -m "feat: add vibe status and recognition feedback to debug HUD"
```

---

### Task 5: Scene Integration

**Files:**
- Modify: `swiper/Levels/main/main.tscn` (via editor)

Wire everything together in the main scene.

- [ ] **Step 1: Add TrailSystem node to the scene**

In Godot editor:
1. Open `main.tscn`
2. Add a new `Node3D` node as a child of the root, name it `TrailSystem`
3. Attach `trail_system.gd` script to it
4. In the inspector, set `Player` to the player node
5. Adjust `Closure Distance`, `Point Distance`, and `Min Points` as needed

- [ ] **Step 2: Add SignalManager node to the scene**

1. Add a new `Node` as a child of the root, name it `SignalManager`
2. Attach `signal_manager.gd` script to it

- [ ] **Step 3: Connect TrailSystem to SignalManager**

In the TrailSystem node, go to the Node tab (signals panel), connect `shape_closed` to `SignalManager.on_shape_closed`.

Alternatively, add this to `main.tscn` via a small script on root, or connect in `_ready()` of a main script:

```gdscript
# If connecting via code in a main.gd or similar:
$TrailSystem.shape_closed.connect($SignalManager.on_shape_closed)
```

- [ ] **Step 4: Set debug panel signal_manager_path**

Select the DebugPanel node in the scene tree. In the inspector, set `Signal Manager Path` to point to the `SignalManager` node.

- [ ] **Step 5: Test the full pipeline**

1. Run the project
2. Move the player around in a square shape, closing the path
3. The trail should appear on the ground as you move
4. When the path closes, the debug HUD should show "VIBE: Sincere"
5. The vibe label should show "Vibe: Sincere (18s)" counting down
6. Try drawing other shapes — heart, triangle, zigzag
7. Draw a vibe first, then a signal — the `signal_triggered` event should fire (visible via print or debugger)

- [ ] **Step 6: Commit**

```bash
git add swiper/Levels/main/main.tscn
git commit -m "feat: integrate trail system and signal manager into main scene"
```

---

### Task 6: Trail Visual Polish — Color Feedback on Recognition

**Files:**
- Modify: `swiper/scene/trail_system.gd`

When a shape is recognized, flash the last fading trail a different color based on type.

- [ ] **Step 1: Add color feedback method to trail_system.gd**

Add export vars:

```gdscript
@export var vibe_color: Color = Color(0.3, 0.5, 1.0, 1.0)  ## Blue for vibe
@export var signal_color: Color = Color(1.0, 0.6, 0.2, 1.0)  ## Orange for signal
@export var fail_color: Color = Color(1.0, 0.2, 0.2, 1.0)  ## Red for unrecognized
```

Add method:

```gdscript
func flash_last_trail(color: Color) -> void:
	## Call after shape_closed to color the most recent fading trail.
	if _fading_trails.is_empty():
		return
	_fading_trails[_fading_trails.size() - 1]["color"] = color
```

Update `_draw_trail_strip` signature to accept an optional color override:

```gdscript
func _draw_trail_strip(points: Array[Vector3], alpha: float, color_override := Color(-1, -1, -1, -1)) -> void:
```

And in the body, change the color line:

```gdscript
		var color: Color
		if color_override.r >= 0.0:
			color = color_override
		else:
			color = trail_color
		color.a = alpha
```

Update the fading trails draw loop in `_rebuild_mesh()`:

```gdscript
	for trail in _fading_trails:
		var alpha := 1.0 - trail["age"] / trail_lifetime
		var override_color := trail.get("color", Color(-1, -1, -1, -1)) as Color
		_draw_trail_strip(trail["points"], alpha, override_color)
```

- [ ] **Step 2: Connect color feedback in the scene**

In the SignalManager or via the connection script, after recognition:

```gdscript
# Example: connect in main scene script or signal_manager
# After shape_recognized, call trail_system.flash_last_trail() with appropriate color
```

The simplest approach: add exports to signal_manager.gd:

```gdscript
@export var trail_system: Node3D
```

Then add to `on_shape_closed`, after `shape_recognized.emit()`:

```gdscript
	if trail_system:
		if shape_type == "vibe":
			trail_system.flash_last_trail(trail_system.vibe_color)
		elif shape_type == "signal":
			trail_system.flash_last_trail(trail_system.signal_color)
```

And after `shape_unrecognized.emit()`:

```gdscript
	if trail_system:
		trail_system.flash_last_trail(trail_system.fail_color)
```

- [ ] **Step 3: Test color feedback**

1. Run the project
2. Draw a square — trail should flash blue
3. Draw a zigzag — trail should flash orange
4. Draw random scribbles — trail should flash red

- [ ] **Step 4: Commit**

```bash
git add swiper/scene/trail_system.gd swiper/scene/signal_manager.gd
git commit -m "feat: add color feedback on shape recognition"
```
