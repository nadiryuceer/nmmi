extends Node3D

@export var height := 12.0
@export var follow_speed := 6.0

# Zoom settings
@export var base_zoom := 12.0
@export var min_zoom := 10.0
@export var max_zoom := 26.0
@export var zoom_margin := 3.0
@export var zoom_speed := 4.0

@export var elimination_margin := 1.2   # world units outside screen
@export var elimination_delay := 1.0    # seconds allowed off-screen

@export var forward_screen_bias := 3.0


@export var players: Array[Node3D] = []


@onready var cam: Camera3D = $Camera3D

var offscreen_time := {}


func _ready():
	# Lock camera angle
	rotation = Vector3(deg_to_rad(-60), 0, 0)
	cam.size = base_zoom

func _physics_process(delta):
	if players.is_empty():
		return

	_update_position(delta)
	_update_zoom(delta)
	_update_elimination(delta)


func _update_zoom(delta: float) -> void:
	var min_x: float = INF
	var max_x: float = -INF
	var min_z: float = INF
	var max_z: float = -INF

	for p in players:
		var pos: Vector3 = p.global_position
		min_x = min(min_x, pos.x)
		max_x = max(max_x, pos.x)
		min_z = min(min_z, pos.z)
		max_z = max(max_z, pos.z)

	var width: float = max_x - min_x
	var height_span: float = max_z - min_z

	var viewport: Vector2 = get_viewport().get_visible_rect().size
	var aspect: float = viewport.x / viewport.y

	var needed_zoom_x: float = (width * 0.5) / aspect
	var needed_zoom_z: float = height_span * 0.5

	var target_zoom: float = max(needed_zoom_x, needed_zoom_z)
	target_zoom += zoom_margin
	target_zoom = clamp(target_zoom, min_zoom, max_zoom)

	cam.size = lerp(cam.size, target_zoom, zoom_speed * delta)


	
func is_target_offscreen(node: Node3D) -> bool:
	var cam_transform := cam.global_transform

	var half_size: float = cam.size
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var aspect: float = viewport_size.x / viewport_size.y

	var half_width: float = half_size * aspect
	var half_height: float = half_size

	var local_pos: Vector3 = cam_transform.affine_inverse() * node.global_position

	if local_pos.x > half_width + elimination_margin:
		return true
	if local_pos.x < -half_width - elimination_margin:
		return true
	if local_pos.z > half_height + elimination_margin:
		return true
	if local_pos.z < -half_height - elimination_margin:
		return true

	return false



func _update_elimination(delta):
	for p in players:
		if not offscreen_time.has(p):
			offscreen_time[p] = 0.0

		if is_target_offscreen(p):
			offscreen_time[p] += delta
			if p.has_method("set_warning"):
				p.set_warning(true)

			if offscreen_time[p] >= elimination_delay:
				eliminate(p)
		else:
			offscreen_time[p] = 0.0
			if p.has_method("set_warning"):
				p.set_warning(false)


func eliminate(node: Node3D):
	print("ELIMINATED:", node.name)

	# TEMP behavior: reset car to center
	node.global_position = Vector3.ZERO
	node.velocity = Vector3.ZERO
	offscreen_time[node] = 0.0
	
func _update_position(delta: float) -> void:
	var center: Vector3 = Vector3.ZERO

	for p in players:
		center += p.global_position

	center /= float(players.size())

	# Lift camera
	center.y += height

	# Push framing forward (screen-space bias)
	var forward: Vector3 = -transform.basis.z
	center += forward * forward_screen_bias

	global_position = global_position.lerp(
		center,
		follow_speed * delta
	)
