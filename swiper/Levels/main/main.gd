extends Node3D

## true = use PhysicalTail (independent physics tail)
## false = use ginnie's built-in Tail (visual tail)
@export var use_physical_tail: bool = false


func _ready() -> void:
	set_tail_mode(use_physical_tail)
	# set_tail_mode(use_physical_tail)

	# $Enemy/ShapeDrawer.draw_shape("heart")


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


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T:
			set_tail_mode(not use_physical_tail)
			print("Tail mode: %s" % ("Physical" if use_physical_tail else "Visual"))
