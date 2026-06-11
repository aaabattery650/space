extends CharacterBody3D

enum MoveMode { WALKING, FLOATING }

@export var move_mode: MoveMode = MoveMode.WALKING

# Walking
@export var walk_speed: float = 5.0
@export var gravity: float = 9.8

# Floating
@export var float_accel: float = 8.0        # how hard your thrusters push
@export var float_max_speed: float = 6.0    # top drift speed
@export var float_damping: float = 0.6      # drag: 0 = drift forever, higher = stops sooner
@export var roll_speed: float = 1.5         # Q/E roll in float mode

@export var mouse_sensitivity: float = 0.002

@onready var head: Node3D = $Head

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if move_mode == MoveMode.WALKING:
			# Walking: body yaws, head pitches, body stays upright
			rotate_y(-event.relative.x * mouse_sensitivity)
			head.rotate_x(-event.relative.y * mouse_sensitivity)
			head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))
		else:
			# Floating: the whole body pitches and yaws freely - no "up" anymore
			rotate_object_local(Vector3.UP, -event.relative.x * mouse_sensitivity)
			rotate_object_local(Vector3.RIGHT, -event.relative.y * mouse_sensitivity)
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	match move_mode:
		MoveMode.WALKING:
			_walk(delta)
		MoveMode.FLOATING:
			_float(delta)

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
	# Build a 3D thrust direction from input, relative to where you're facing
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var vertical := Input.get_axis("float_down", "float_up")   # crouch/jump keys
	var thrust := (transform.basis * Vector3(input_dir.x, vertical, input_dir.y))

	if thrust.length() > 0.01:
		# Thrusters: accelerate, don't snap to a speed
		velocity += thrust.normalized() * float_accel * delta
		velocity = velocity.limit_length(float_max_speed)
	else:
		# Gentle drag so you eventually coast to a stop (set damping to 0 for pure Newtonian drift)
		velocity = velocity.move_toward(Vector3.ZERO, float_damping * delta)

	# Q/E roll - this is what sells "there is no up in space"
	var roll := Input.get_axis("roll_left", "roll_right")
	if roll != 0.0:
		rotate_object_local(Vector3.FORWARD, roll * roll_speed * delta)

	move_and_slide()

func set_floating(floating: bool) -> void:
	move_mode = MoveMode.FLOATING if floating else MoveMode.WALKING
	if not floating:
		# Re-level the body when gravity returns so you land upright
		var yaw := rotation.y
		rotation = Vector3(0, yaw, 0)
		head.rotation = Vector3.ZERO
