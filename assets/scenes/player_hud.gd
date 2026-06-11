extends CanvasLayer

@onready var fuel_bar: ProgressBar = $FuelBar
@onready var mode_label: Label = $ModeLabel

func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.fuel_changed.connect(_on_fuel_changed)
		player.mode_changed.connect(_on_mode_changed)
	else:
		push_warning("PlayerHUD: no node in group 'player' found")

func _on_fuel_changed(current: float, maximum: float) -> void:
	fuel_bar.max_value = maximum
	fuel_bar.value = current

func _on_mode_changed(mode: int) -> void:
	mode_label.text = "ZERO-G" if mode == 1 else "GRAVITY"
