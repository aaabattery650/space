extends StaticBody3D

@export var oxygen_capacity: float = 150.0
@export var oxygen_supply: float = 150.0
@export var transfer_rate: float = 8.0
@export var recharge_rate: float = 1.5
@export var transfer_range: float = 3.0

var interaction_prompt: String = "[R] Refill oxygen"

var _filling: bool = false
var _player: Node = null

func interact(player: Node) -> void:
	if _filling:
		_stop_filling()
	else:
		_player = player
		_filling = true

func _process(delta: float) -> void:
	if not _filling and oxygen_supply < oxygen_capacity:
		oxygen_supply = min(oxygen_supply + recharge_rate * delta, oxygen_capacity)
	_update_prompt()

	if not _filling or _player == null:
		return

	if global_position.distance_to(_player.global_position) > transfer_range:
		_stop_filling()
		return

	if _player.oxygen >= _player.oxygen_max:
		_stop_filling()
		return

	var amount: float = min(transfer_rate * delta, oxygen_supply)
	_player.add_oxygen(amount)
	oxygen_supply -= amount

	if oxygen_supply <= 0.0:
		_stop_filling()

func _stop_filling() -> void:
	_filling = false
	_player = null

func _update_prompt() -> void:
	if _filling:
		interaction_prompt = "[R] Stop refilling"
	elif oxygen_supply <= 0.0:
		interaction_prompt = "Oxygen canister (recharging...)"
	elif oxygen_supply < oxygen_capacity * 0.99:
		interaction_prompt = "[R] Refill oxygen (%d%%)" % int(oxygen_supply / oxygen_capacity * 100.0)
	else:
		interaction_prompt = "[R] Refill oxygen"	
