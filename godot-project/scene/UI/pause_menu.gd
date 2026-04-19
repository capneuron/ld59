extends CanvasLayer

var enabled: bool = true
var _is_open: bool = false

@onready var _panel: ColorRect = $Panel
@onready var _bgm_slider: HSlider = $Panel/VBoxContainer/BGMRow/BGMSlider
@onready var _sfx_slider: HSlider = $Panel/VBoxContainer/SFXRow/SFXSlider
@onready var _close_btn: TextureButton = $Panel/VBoxContainer/ButtonRow/CloseButton
@onready var _exit_btn: TextureButton = $Panel/VBoxContainer/ButtonRow/ExitButton
@onready var _quit_btn: Button = $Panel/VBoxContainer/QuitButton
@onready var _sfx_button: AudioStreamPlayer = $SFXButton

var _bgm_bus: int
var _sfx_bus: int

## Set this to a scene path to enable the exit button
var exit_scene: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.visible = false
	_bgm_bus = AudioServer.get_bus_index("BGM")
	_sfx_bus = AudioServer.get_bus_index("SFX")
	_bgm_slider.value = db_to_linear(AudioServer.get_bus_volume_db(_bgm_bus))
	_sfx_slider.value = db_to_linear(AudioServer.get_bus_volume_db(_sfx_bus))
	_bgm_slider.value_changed.connect(_on_bgm_volume_changed)
	_sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	_setup_button_hover(_close_btn)
	_close_btn.pressed.connect(close_menu)
	_setup_button_hover(_exit_btn)
	_exit_btn.pressed.connect(_on_exit)
	_quit_btn.pressed.connect(func() -> void: _sfx_button.play(); _on_quit())
	
	_sfx_button.bus = "SFX"
	_sfx_button.stream = preload("res://audio/short_piano5.wav")


func enable_exit(scene_path: String) -> void:
	exit_scene = scene_path
	_exit_btn.visible = true


func _setup_button_hover(btn: TextureButton) -> void:
	btn.pivot_offset = btn.size / 2.0
	btn.mouse_entered.connect(func() -> void:
		var tw := btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(1.2, 1.2), 0.15)
	)
	btn.mouse_exited.connect(func() -> void:
		var tw := btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15)
	)
	btn.button_down.connect(func() -> void:
		_sfx_button.play()
		var tw := btn.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(0.9, 0.9), 0.08)
	)
	btn.button_up.connect(func() -> void:
		var tw := btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(1.2, 1.2), 0.1)
	)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and enabled:
			if _is_open:
				close_menu()
			else:
				open_menu()
			get_viewport().set_input_as_handled()


func open_menu() -> void:
	_is_open = true
	_panel.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_menu() -> void:
	_is_open = false
	_panel.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_bgm_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(_bgm_bus, linear_to_db(value))


func _on_sfx_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(_sfx_bus, linear_to_db(value))


func _on_exit() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(exit_scene)


func _on_quit() -> void:
	get_tree().quit()
