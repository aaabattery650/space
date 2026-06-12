extends CanvasLayer

@onready var fuel_bar: ProgressBar = $FuelBar
@onready var oxygen_bar: ProgressBar = $OxygenBar
@onready var grab_label: Label = $GrabLabel
@onready var prompt_label: Label = $PromptLabel

var player: Node = null

func _ready() -> void:
	grab_label.text = ""
	prompt_label.text = ""
	player = get_tree().get_first_node_in_group("player")
	if player:
		player.fuel_changed.connect(_on_fuel_changed)
		player.oxygen_changed.connect(_on_oxygen_changed)
		player.oxygen_depleted.connect(_on_oxygen_depleted)
		player.grab_changed.connect(_on_grab_changed)
	else:
		push_warning("PlayerHUD: no node in group 'player' found")

func _process(_delta: float) -> void:
	# Pull the prompt straight from the player every frame
	if player == null:
		return
	var target: Node = player.current_interactable
	if target:
		prompt_label.text = target.interaction_prompt
	else:
		prompt_label.text = "NO TARGET"

func _on_fuel_changed(current: float, maximum: float) -> void:
	fuel_bar.max_value = maximum
	fuel_bar.value = current

func _on_oxygen_changed(current: float, maximum: float) -> void:
	oxygen_bar.max_value = maximum
	oxygen_bar.value = current

func _on_grab_changed(is_grabbing: bool, can_grab: bool) -> void:
	if is_grabbing:
		grab_label.text = "● GRABBED"
		grab_label.modulate = Color(0.4, 1.0, 0.4)
	elif can_grab:
		grab_label.text = "[RMB] Grab"
		grab_label.modulate = Color(1, 1, 1, 0.7)
	else:
		grab_label.text = ""

func _on_oxygen_depleted() -> void:
	print("OXYGEN DEPLETED")
