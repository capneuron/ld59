extends RigidBody3D


func first_met_cut() -> void:
	# Pause any AnimationPlayer that might be overriding our position
	var anim := _find_animation_player()
	if anim:
		anim.pause()
	$ShapeDrawer.draw_shape("heart", global_position)
	$ShapeDrawer.drawing_finished.connect(func(_s: String):
		$Emoji.flash_emoji(1)
		await get_tree().create_timer(1.5).timeout
		get_node_or_null("/root/Main/L/Emoji").flash_emoji(2)
		await get_tree().create_timer(1.5).timeout
		$Emoji.flash_emoji(4)
		await get_tree().create_timer(1.5).timeout
		if anim:
			anim.play()
	, CONNECT_ONE_SHOT)


func _find_animation_player() -> AnimationPlayer:
	# Check parent and siblings for an AnimationPlayer
	var parent := get_parent()
	if parent:
		for child in parent.get_children():
			if child is AnimationPlayer:
				return child
	return get_node_or_null("AnimationPlayer") as AnimationPlayer
