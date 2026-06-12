extends StaticBody3D

@export var interaction_prompt: String = "[T] Use computer"
@export var interact_action: String = "use_terminal"
@export var terminal_ui: CanvasLayer

func interact(player: Node) -> void:
	if terminal_ui:
		terminal_ui.open()
		player.ui_open = true
		terminal_ui.closed.connect(func() -> void: player.ui_open = false, CONNECT_ONE_SHOT)
