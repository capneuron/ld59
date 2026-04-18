extends Node3D

## true = use PhysicalTail (independent physics tail)
## false = use ginnie's built-in Tail (visual tail)
@export var use_physical_tail: bool = false


@onready var signal_manager: Node = $SignalManager


func _ready() -> void:
	set_tail_mode(use_physical_tail)

	signal_manager.vibe_changed.connect(_on_vibe_changed)
	signal_manager.vibe_expired.connect(_on_vibe_expired)
	signal_manager.signal_triggered.connect(_on_signal_triggered)
	signal_manager.shape_recognized.connect(_on_shape_recognized)
	signal_manager.shape_unrecognized.connect(_on_shape_unrecognized)


func set_tail_mode(physical: bool) -> void:
	use_physical_tail = physical
	var physical_tail := $PhysicalTail
	var visual_tail := $Player/ginnie/Tail

	if physical:
		physical_tail.visible = true
		physical_tail.set_physics_process(true)
		physical_tail.set_process(true)
		_set_tail_collision(physical_tail, true)
		visual_tail.visible = false
		visual_tail.set_physics_process(false)
		visual_tail.set_process(false)
	else:
		physical_tail.visible = false
		physical_tail.set_physics_process(false)
		physical_tail.set_process(false)
		_set_tail_collision(physical_tail, false)
		visual_tail.visible = true
		visual_tail.set_physics_process(true)
		visual_tail.set_process(true)


func _set_tail_collision(tail_root: Node, enabled: bool) -> void:
	for child in tail_root.get_children():
		if child is RigidBody3D:
			child.set_deferred("freeze", not enabled)


func _on_vibe_changed(vibe_name: String) -> void:
	print("[Main] Vibe changed: %s" % vibe_name)


func _on_vibe_expired() -> void:
	print("[Main] Vibe expired")


func _on_signal_triggered(vibe_name: String, signal_name: String) -> void:
	print("[Main] Signal triggered: %s (vibe: %s)" % [signal_name, vibe_name])


func _on_shape_recognized(shape_name: String, shape_type: String) -> void:
	print("[Main] Shape recognized: %s (%s)" % [shape_name, shape_type])


func _on_shape_unrecognized() -> void:
	print("[Main] Shape unrecognized")


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T:
			set_tail_mode(not use_physical_tail)
			print("Tail mode: %s" % ("Physical" if use_physical_tail else "Visual"))
