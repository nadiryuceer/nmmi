extends CharacterBody3D

@export var acceleration := 22.0
@export var max_speed := 20.0
@export var steering_speed := 3.0
@export var grip := 9.0
@export var drift_grip := 3.5
@export var boost_force := 35.0

var current_speed := 0.0
var steering_input := 0.0
var forward := Vector3.FORWARD

@onready var warning := $Sprite3D


func _physics_process(delta):
	handle_input(delta)
	apply_movement(delta)
	move_and_slide()

func handle_input(delta):
	var accel_input := Input.get_action_strength("accelerate") - Input.get_action_strength("brake")
	steering_input = Input.get_action_strength("steer_left") - Input.get_action_strength("steer_right")

	# Acceleration
	current_speed += accel_input * acceleration * delta
	current_speed = clamp(current_speed, -max_speed * 0.5, max_speed)

	# Boost
	if Input.is_action_pressed("boost"):
		current_speed = min(current_speed + boost_force * delta, max_speed * 1.5)

func apply_movement(delta):
	# Rotate car visually
	rotation.y += steering_input * steering_speed * delta * (current_speed / max_speed)

	# Forward direction
	forward = -transform.basis.z

	# Target velocity
	var target_velocity := forward * current_speed

	# Drift & grip
	var lateral := velocity - velocity.project(forward)
	var current_grip := drift_grip if Input.is_action_pressed("boost") else grip
	lateral = lateral.move_toward(Vector3.ZERO, current_grip * delta)

	velocity = target_velocity + lateral


func set_warning(active: bool):
	if warning:
		warning.visible = active
