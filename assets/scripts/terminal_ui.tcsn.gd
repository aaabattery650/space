extends CanvasLayer

signal closed

@onready var settings_button: TextureButton = $Panel/MainMenu/SettingsButton
@onready var navigation_button: TextureButton = $Panel/MainMenu/NavigationButton
@onready var upgrades_button: TextureButton = $Panel/MainMenu/UpgradesButton

func _ready() -> void:
	visible = false
	settings_button.pressed.connect(_on_settings_pressed)
	navigation_button.pressed.connect(_on_navigation_pressed)
	upgrades_button.pressed.connect(_on_upgrades_pressed)

func open() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	# Esc exits the terminal - and consumes the press so the player's
	# Esc handler doesn't immediately free the mouse again
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _on_settings_pressed() -> void:
	print("Settings clicked")

func _on_navigation_pressed() -> void:
	print("Navigation clicked")

func _on_upgrades_pressed() -> void:
	print("Upgrades clicked")
