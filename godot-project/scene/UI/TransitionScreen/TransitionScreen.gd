extends Control

@onready var tip_label: Label = $VBoxContainer/TipLabel
@onready var progress_bar: ProgressBar = $VBoxContainer/ProgressBar

var tips := [
	"Tomatoes fight back!",
	"Press J to attack",
	"Hold Shift to sprint",
]

func _ready() -> void:
	tip_label.text = tips.pick_random()
	SceneManager.load_percent_changed.connect(_on_load_percent_changed)

func _on_load_percent_changed(value: int) -> void:
	progress_bar.value = value
