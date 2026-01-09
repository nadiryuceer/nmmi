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
@export var elimination_distance := 12.0

@export var forward_screen_bias := 3.0


@export var players: Array[Node3D] = []


@onready var cam: Camera3D = $Camera3D

@export var warning_ratio := 0.85
@export var elimination_ratio := 0.95

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
	if players.size() < 2:
		return

	var max_dist := _get_max_pairwise_distance()

	# Required orthographic size is half the spread
	var desired_size: float = (max_dist * 0.5) + zoom_margin

	desired_size = clamp(desired_size, min_zoom, max_zoom)

	var t := 1.0 - exp(-zoom_speed * delta)
	cam.size = lerp(cam.size, desired_size, t)



	
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



func _update_elimination(delta: float) -> void:
	var pack_center := _get_pack_center()
	var leader := _get_leader()

	for p in players:
		if not p.can_be_eliminated:
			continue

		# Leader is immune
		if p == leader:
			continue

		var dist := p.global_position.distance_to(pack_center)

		if dist > elimination_distance:
			offscreen_time[p] += delta
			p.show_warning()
		else:
			offscreen_time[p] = 0.0
			p.hide_warning()

		if offscreen_time[p] > elimination_delay:
			_eliminate(p)



func _eliminate(node: Node3D):
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

	# HARD LOCK Y
	center.y = height

	# Push framing forward (screen-space bias)
	var track_forward := Vector3.FORWARD
	center += track_forward * forward_screen_bias

	var t := 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(center, t)


func _get_camera_bounds() -> Rect2:
	var size: Vector2 = get_viewport().get_visible_rect().size
	var half_w := size.x * 0.5 * elimination_ratio
	var half_h := size.y * 0.5 * elimination_ratio

	return Rect2(
		Vector2(-half_w, -half_h),
		Vector2(half_w * 2, half_h * 2)
	)

func _get_leader() -> Node3D:
	var leader := players[0]
	var best_z := leader.global_position.z

	for p in players:
		if p.global_position.z > best_z:
			best_z = p.global_position.z
			leader = p

	return leader

func _get_pack_center() -> Vector3:
	var center := Vector3.ZERO

	for p in players:
		center += p.global_position

	return center / float(players.size())

func _get_max_pairwise_distance() -> float:
	var max_dist := 0.0

	for i in range(players.size()):
		for j in range(i + 1, players.size()):
			var a: Vector3 = players[i].global_position
			var b: Vector3 = players[j].global_position

			# Ground-plane distance (ignore Y)
			var dist := Vector2(a.x, a.z).distance_to(
				Vector2(b.x, b.z)
			)

			if dist > max_dist:
				max_dist = dist

	return max_dist
