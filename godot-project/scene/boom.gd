extends Node3D

func _ready() -> void:
	$AnimatedSprite3D.animation_finished.connect(func(): queue_free())
	$AnimatedSprite3D.play("boom")
