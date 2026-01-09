extends CharacterBody3D

@export var acceleration := 22.0
@export var max_speed := 20.0
@export var steering_speed := 3.0
@export var grip := 9.0
@export var drift_grip := 3.5
@export var boost_force := 35.0
@export var drag := 4.0

@export var wall_speed_loss := 0.85   # NEW: how hard walls kill speed
@export var min_stop_speed := 0.6     # NEW: snap to zero below this

@export var controllable := true
@export var can_be_eliminated := true

var current_speed := 0.0
var steering_input := 0.0
var throttle := 0.0

@onready var warning_node := $Warning/Sprite3D

@export var gravity : float = ProjectSettings.get_setting("physics/3d/default_gravity")

var vertical_velocity := 0.0

@export var align_speed := 8.0





func _physics_process(delta: float) -> void:
	if not controllable:
		return

	handle_input(delta)
	apply_movement(delta)
	velocity.y = vertical_velocity
	move_and_slide()
	align_to_floor(delta)

	vertical_velocity = velocity.y


	handle_wall_collisions()   # NEW


# ---------------- INPUT ----------------

func handle_input(delta: float) -> void:
	var accel_input := (
		Input.get_action_strength("accelerate")
		- Input.get_action_strength("brake")
	)
	throttle = accel_input

	steering_input = (
		Input.get_action_strength("steer_left")
		- Input.get_action_strength("steer_right")
	)

	# --- SPEED CONTROL ---
	if abs(accel_input) > 0.01:
		current_speed += accel_input * acceleration * delta
	else:
		# Passive drag only when no throttle
		current_speed = move_toward(current_speed, 0.0, drag * delta)

	current_speed = clamp(current_speed, -max_speed * 0.5, max_speed)

	# Boost
	if Input.is_action_pressed("boost"):
		current_speed = min(
			current_speed + boost_force * delta,
			max_speed * 1.5
		)


# ---------------- MOVEMENT ----------------

func apply_movement(delta: float) -> void:
	var on_floor := is_on_floor()

	# Gravity
	if not on_floor:
		vertical_velocity -= gravity * delta
	else:
		if vertical_velocity < 0.0:
			vertical_velocity = 0.0

	# Rotation (grounded steering)
	if on_floor and abs(current_speed) > 0.1:
		var speed_ratio : float = abs(current_speed) / max_speed
		var steer_dir : float = sign(current_speed)
		rotation.y += steering_input * steering_speed * delta * speed_ratio * steer_dir

	# Forward direction
	var forward := -transform.basis.z.normalized()
	var target_velocity := forward * current_speed

	# Lateral drift
	var lateral := velocity - velocity.project(forward)
	lateral.y = 0.0  # IMPORTANT: never keep Y drift

	var grip_value := drift_grip if Input.is_action_pressed("boost") else grip

	if abs(throttle) < 0.1:
		grip_value *= 2.5

	lateral = lateral.move_toward(Vector3.ZERO, grip_value * delta)

	# Combine (X/Z only)
	velocity.x = target_velocity.x + lateral.x
	velocity.z = target_velocity.z + lateral.z
	
	# --- HARD HORIZONTAL SPEED CAP ---
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var h_speed := horizontal_velocity.length()

	var max_allowed := max_speed
	if Input.is_action_pressed("boost"):
		max_allowed = max_speed * 1.5

	if h_speed > max_allowed:
		horizontal_velocity = horizontal_velocity.normalized() * max_allowed
		velocity.x = horizontal_velocity.x
		velocity.z = horizontal_velocity.z




# ---------------- COLLISIONS ----------------

func handle_wall_collisions() -> void:
	if get_slide_collision_count() == 0:
		return

	var forward := -transform.basis.z.normalized()

	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var normal := collision.get_normal()

		# Detect frontal impact
		var frontal_hit := normal.dot(forward) < -0.5

		if frontal_hit:
			# Kill stored speed
			current_speed *= (1.0 - wall_speed_loss)

			# Prevent rebound acceleration
			velocity = velocity.slide(normal)

			# Snap to full stop if slow enough
			if abs(current_speed) < min_stop_speed:
				current_speed = 0.0
				velocity = Vector3.ZERO


# ---------------- WARNINGS ----------------

func show_warning() -> void:
	if warning_node:
		warning_node.visible = true


func hide_warning() -> void:
	if warning_node:
		warning_node.visible = false


func align_to_floor(delta: float) -> void:
	if not is_on_floor():
		return

	var normal := get_floor_normal()

	# Desired orientation: forward stays forward, up matches floor
	var forward := -transform.basis.z
	var right := forward.cross(normal).normalized()
	forward = normal.cross(right).normalized()

	var target_basis := Basis(right, normal, -forward)

	$Visual.global_transform.basis = (
		$Visual.global_transform.basis
		.slerp(target_basis, align_speed * delta)
	)
