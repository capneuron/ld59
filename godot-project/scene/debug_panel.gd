extends Control

@export var enemy_scene: PackedScene
@export var physical_tail_path: NodePath
@export var signal_manager_path: NodePath
@export var player_path: NodePath

var _physical_tail: Node3D
var _signal_manager: Node
var _player: Node3D
var _panel: PanelContainer
var _show_hud_speed := false
var _hud_speed_label: Label
var _hud_toggle: CheckButton
var _vibe_label: Label
var _recognition_label: Label
var _recognition_fade := 0.0


func _ready() -> void:
	# Debug panel disabled — early return to skip all setup
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	set_process_unhandled_key_input(false)
	
	return

	# if physical_tail_path:
	# 	_physical_tail = get_node(physical_tail_path)

	# if signal_manager_path:
	# 	_signal_manager = get_node(signal_manager_path)
	# 	_signal_manager.shape_recognized.connect(_on_shape_recognized)
	# 	_signal_manager.shape_unrecognized.connect(_on_shape_unrecognized)

	# if player_path:
	# 	_player = get_node(player_path)

	# _build_hud()
	# _build_panel()


func _build_hud() -> void:
	# Always-visible HUD label in upper right (independent of debug panel visibility)
	_hud_speed_label = Label.new()
	_hud_speed_label.anchor_left = 1.0
	_hud_speed_label.anchor_right = 1.0
	_hud_speed_label.anchor_top = 0.0
	_hud_speed_label.anchor_bottom = 0.0
	_hud_speed_label.offset_left = -200.0
	_hud_speed_label.offset_right = -8.0
	_hud_speed_label.offset_top = 8.0
	_hud_speed_label.offset_bottom = 40.0
	_hud_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud_speed_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_speed_label.visible = false
	# Add to parent so it stays visible when debug panel is hidden
	call_deferred("_add_hud_to_parent")

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


func _add_hud_to_parent() -> void:
	get_parent().add_child(_hud_speed_label)


func _add_vibe_label_to_parent() -> void:
	get_parent().add_child(_vibe_label)


func _add_recognition_label_to_parent() -> void:
	get_parent().add_child(_recognition_label)


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.0
	_panel.anchor_top = 0.0
	_panel.anchor_right = 0.4
	_panel.anchor_bottom = 1.0
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	margin.add_child(vbox)

	# --- Spawn button ---
	var spawn_button := Button.new()
	spawn_button.text = "Spawn Enemy at Origin"
	spawn_button.pressed.connect(_on_spawn_enemy)
	vbox.add_child(spawn_button)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# --- HUD speed toggle ---
	_hud_toggle = CheckButton.new()
	_hud_toggle.text = "Show Tail Tip Speed on HUD"
	_hud_toggle.button_pressed = _show_hud_speed
	_hud_toggle.toggled.connect(_on_hud_toggle)
	vbox.add_child(_hud_toggle)

	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	# --- Emoji buttons ---
	var emoji_label := Label.new()
	emoji_label.text = "Player Emoji"
	vbox.add_child(emoji_label)

	var emoji_names: Array[String] = ["Note", "Heart", "Cross", "Dots", "Angry", "Question", "Alert"]
	var emoji_grid := GridContainer.new()
	emoji_grid.columns = 4
	vbox.add_child(emoji_grid)
	for i in emoji_names.size():
		var btn := Button.new()
		btn.text = emoji_names[i]
		btn.pressed.connect(_on_emoji_button.bind(i))
		emoji_grid.add_child(btn)

	var hide_btn := Button.new()
	hide_btn.text = "Hide Emoji"
	hide_btn.pressed.connect(_on_emoji_hide)
	vbox.add_child(hide_btn)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_QUOTELEFT:
			visible = not visible
			mouse_filter = Control.MOUSE_FILTER_STOP if visible else Control.MOUSE_FILTER_IGNORE
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _physical_tail and _show_hud_speed:
		_hud_speed_label.text = "Tip: %.1f" % _physical_tail.get_tip_speed()

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


func _on_hud_toggle(toggled_on: bool) -> void:
	_show_hud_speed = toggled_on
	_hud_speed_label.visible = toggled_on


func _on_shape_recognized(shape_name: String, shape_type: String) -> void:
	var display: String = _signal_manager.SHAPE_DISPLAY.get(shape_name, shape_name)
	_recognition_label.text = "%s: %s" % [shape_type.to_upper(), display]
	_recognition_fade = 2.0


func _on_shape_unrecognized() -> void:
	_recognition_label.text = "???"
	_recognition_fade = 1.5


func _on_emoji_button(frame_index: int) -> void:
	if not _player:
		return
	var emoji := _player.get_node_or_null("Emoji")
	if emoji:
		emoji.flash_emoji(frame_index)


func _on_emoji_hide() -> void:
	if not _player:
		return
	var emoji := _player.get_node_or_null("Emoji")
	if emoji:
		emoji.hide_emoji()


func _on_spawn_enemy() -> void:
	if not enemy_scene:
		return
	var enemy := enemy_scene.instantiate()
	enemy.position = Vector3.ZERO
	get_tree().current_scene.add_child(enemy)
