extends CanvasLayer

@onready var _restart_btn: TextureButton = $RestartButton
@onready var _sfx_button: AudioStreamPlayer = $SFXButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_sfx_button.bus = "SFX"
	_sfx_button.stream = preload("res://audio/short_piano5.wav")
	_restart_btn.pivot_offset = _restart_btn.size / 2.0
	_restart_btn.pressed.connect(_on_restart)
	_restart_btn.mouse_entered.connect(func() -> void:
		var tw := _restart_btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_restart_btn, "scale", Vector2(1.2, 1.2), 0.15)
	)
	_restart_btn.mouse_exited.connect(func() -> void:
		var tw := _restart_btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_restart_btn, "scale", Vector2(1.0, 1.0), 0.15)
	)
	_restart_btn.button_down.connect(func() -> void:
		_sfx_button.play()
		var tw := _restart_btn.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(_restart_btn, "scale", Vector2(0.9, 0.9), 0.08)
	)
	_restart_btn.button_up.connect(func() -> void:
		var tw := _restart_btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_restart_btn, "scale", Vector2(1.2, 1.2), 0.1)
	)


func show_ending() -> void:
	visible = true
	_restart_btn.visible = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var tw := _restart_btn.create_tween()
	tw.tween_interval(3.0)
	tw.tween_callback(func() -> void: 
		_restart_btn.visible = true
	)


func _on_restart() -> void:
	get_tree().paused = false
	SceneManager.set_transition_scene(preload("res://scene/UI/Transition.tscn"))
	var fade_out := SceneManager.create_options(1.0, "crooked_tiles")
	var fade_in := SceneManager.create_options(1.0, "crooked_tiles")
	var general := SceneManager.create_general_options(Color.BLACK, 0.5, false, false)
	await SceneManager.change_scene("main2", fade_out, fade_in, general)
