extends CharacterBody3D

enum MoveMode { WALKING, FLOATING }

signal fuel_changed(current: float, maximum: float)
signal oxygen_changed(current: float, maximum: float)
signal mode_changed(mode: MoveMode)
signal oxygen_depleted
signal grab_changed(is_grabbing: bool, can_grab: bool)

@export var move_mode: MoveMode = MoveMode.FLOATING

# Walking
@export var walk_speed: float = 5.0
@export var gravity: float = 9.8

# Floating / jetpack
@export var float_accel: float = 8.0
@export var float_max_speed: float = 6.0
@export var float_damping: float = 0.6

# Newtonian roll
@export var roll_accel: float = 2.5
@export var roll_damping: float = 0.0
@export var roll_fuel_rate: float = 5.0

# Jetpack fuel (no auto recharge)
@export var fuel_max: float = 1000
@export var fuel_burn_rate: float = 10.0

# Oxygen
@export var oxygen_max: float = 100.0
@export var oxygen_drain_rate: float = 2.5
@export var oxygen_refill_rate: float = 10.0

# Interaction
@export var interact_range: float = 2.5

@export var mouse_sensitivity: float = 0.002

var fuel: float = 250.0
var oxygen: float = 100.0
var ui_open: bool = false
var roll_velocity: float = 0.0
var is_grabbing: bool = false
var current_interactable: Node = null

@onready var head: Node3D = find_child("Head", true, false)
@onready var camera: Camera3D = find_child("Camera3D", true, false)
@onready var head_lamp: SpotLight3D = find_child("HeadLamp", true, false)

var grab_cast: ShapeCast3D
var interact_ray: RayCast3D

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	fuel = fuel_max
	oxygen = oxygen_max

	if head_lamp:
		head_lamp.visible = false

	if camera:
		grab_cast = ShapeCast3D.new()
		var sphere = SphereShape3D.new()
		sphere.radius = 0.6
		grab_cast.shape = sphere
		grab_cast.target_position = Vector3(0, 0, -1.5)
		grab_cast.collision_mask = 4294967295
		camera.add_child(grab_cast)
		grab_cast.add_exception(self)

		interact_ray = RayCast3D.new()
		interact_ray.target_position = Vector3(0, 0, -interact_range)
		interact_ray.collision_mask = 4294967295
		interact_ray.enabled = true
		camera.add_child(interact_ray)
		interact_ray.add_exception(self)
	else:
		push_error("PLAYER ERROR: Could not find 'Camera3D' node! Cannot build grab tool.")

	fuel_changed.emit(fuel, fuel_max)
	oxygen_changed.emit(oxygen, oxygen_max)
	mode_changed.emit(move_mode)

func _process(_delta: float) -> void:
	# Track what interactable (if any) we're aiming at
	current_interactable = null
	if not ui_open and interact_ray and interact_ray.is_colliding():
		var collider: Object = interact_ray.get_collider()
		if collider and collider.is_in_group("interactable"):
			current_interactable = collider

	# ===== TEMPORARY DIAGNOSTIC - remove once the canister works =====
	if interact_ray and interact_ray.is_colliding():
		var hit := interact_ray.get_collider()
		print("RAY HIT: ", hit.name, "  | in group: ", hit.is_in_group("interactable"))
	# =================================================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if move_mode == MoveMode.WALKING:
			rotate_y(-event.relative.x * mouse_sensitivity)
			if head:
				head.rotate_x(-event.relative.y * mouse_sensitivity)
				head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))
		else:
			rotate_object_local(Vector3.UP, -event.relative.x * mouse_sensitivity)
			rotate_object_local(Vector3.RIGHT, -event.relative.y * mouse_sensitivity)

	# Interact: R by default, or the object's own key (e.g. T for the terminal)
	if current_interactable and not ui_open:
		var wants: String = "interact"
		var custom = current_interactable.get("interact_action")
		if custom:
			wants = custom
		if event.is_action_pressed(wants):
			current_interactable.interact(self)

	# F toggles the headlamp
	if event.is_action_pressed("toggle_lamp") and head_lamp:
		head_lamp.visible = not head_lamp.visible

	if not ui_open:
		if event.is_action_pressed("ui_cancel"):
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if event is InputEventMouseButton and event.pressed \
				and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	match move_mode:
		MoveMode.WALKING:
			_walk(delta)
		MoveMode.FLOATING:
			_float(delta)

	_update_oxygen(delta)

func _walk(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * walk_speed
		velocity.z = direction.z * walk_speed
	else:
		velocity.x = move_toward(velocity.x, 0, walk_speed)
		velocity.z = move_toward(velocity.z, 0, walk_speed)

	move_and_slide()

func _float(delta: float) -> void:
	var cast_hitting := false
	if grab_cast:
		grab_cast.force_shapecast_update()
		cast_hitting = grab_cast.is_colliding()

	var grab_held := Input.is_action_pressed("grab")
	var was_grabbing := is_grabbing
	is_grabbing = (cast_hitting or was_grabbing) and grab_held
	grab_changed.emit(is_grabbing, cast_hitting)

	if was_grabbing and not is_grabbing:
		velocity = Vector3.ZERO
		roll_velocity = 0.0

	if is_grabbing:
		velocity = Vector3.ZERO
		roll_velocity = 0.0
		return

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var vertical := Input.get_axis("float_down", "float_up")
	var thrust := (transform.basis * Vector3(input_dir.x, vertical, input_dir.y))

	var thrusting := thrust.length() > 0.01 and fuel > 0.0

	if thrusting:
		velocity += thrust.normalized() * float_accel * delta
		velocity = velocity.limit_length(float_max_speed)
		_burn_fuel(fuel_burn_rate * delta)
	else:
		velocity = velocity.move_toward(Vector3.ZERO, float_damping * delta)

	var roll_input := Input.get_axis("roll_left", "roll_right")
	if roll_input != 0.0 and fuel > 0.0:
		roll_velocity += roll_input * roll_accel * delta
		_burn_fuel(roll_fuel_rate * delta)
	if roll_input == 0.0 and roll_damping > 0.0:
		roll_velocity = move_toward(roll_velocity, 0.0, roll_damping * delta)
	rotate_object_local(Vector3.FORWARD, roll_velocity * delta)

	move_and_slide()
	transform.basis = transform.basis.orthonormalized()

func _update_oxygen(delta: float) -> void:
	if move_mode == MoveMode.FLOATING:
		var before := oxygen
		oxygen = max(oxygen - oxygen_drain_rate * delta, 0.0)
		oxygen_changed.emit(oxygen, oxygen_max)
		if before > 0.0 and oxygen <= 0.0:
			oxygen_depleted.emit()
	else:
		if oxygen < oxygen_max:
			oxygen = min(oxygen + oxygen_refill_rate * delta, oxygen_max)
			oxygen_changed.emit(oxygen, oxygen_max)

func _burn_fuel(amount: float) -> void:
	fuel = max(fuel - amount, 0.0)
	fuel_changed.emit(fuel, fuel_max)

func add_fuel(amount: float) -> void:
	fuel = min(fuel + amount, fuel_max)
	fuel_changed.emit(fuel, fuel_max)

func add_oxygen(amount: float) -> void:
	oxygen = min(oxygen + amount, oxygen_max)
	oxygen_changed.emit(oxygen, oxygen_max)

func set_floating(floating: bool) -> void:
	move_mode = MoveMode.FLOATING if floating else MoveMode.WALKING
	if not floating:
		var yaw := rotation.y
		rotation = Vector3(0, yaw, 0)
		if head:
			head.rotation = Vector3.ZERO
		roll_velocity = 0.0
		is_grabbing = false
	mode_changed.emit(move_mode)
