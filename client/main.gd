extends Node3D

@onready var cameraBase = $CameraBase/Collider
@onready var camera = $CameraBase/Collider/Camera
@onready var treesContainer = $Map/NavRegion/Trees

var camera_height : float = 2.0
var camera_rotation_speed : float = 50.0

const RAY_CAST_LENGTH = 500


#func _ready():
#	$Map.map_loaded.connect(
#		func(playerSpawn):
#			$Player.rpc_set_position.rpc(playerSpawn)
#	)


func _input(event):
	if not event is InputEventMouseButton: return

	if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var from = camera.project_ray_origin(event.position)
		var to = from + camera.project_ray_normal(event.position) * RAY_CAST_LENGTH
		var params := PhysicsRayQueryParameters3D.create(from, to, 4294967295, [$Player, treesContainer])
		var raycast_result = get_parent().get_world_3d().direct_space_state.intersect_ray(params)
		var map = get_parent().get_world_3d().navigation_map
		var target_point := NavigationServer3D.map_get_closest_point_to_segment(map, from, to)

		if raycast_result.size() > 0:
			$Player.rpc_set_moving.rpc(target_point)

	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		camera.position.y -= 1
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		camera.position.y += 1


func _physics_process(delta):
	if not Input.is_anything_pressed():
		return

	if Input.is_key_pressed(KEY_Q):
		$Player.rpc_attempt_portal_activation.rpc()
		return

	var rotate_horizontal := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var rotate_vertical := Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")

	var new_rotation = cameraBase.rotation_degrees
	new_rotation.y += rotate_horizontal * delta * camera_rotation_speed
	# Rotate on X by "move_up" - "move_down". Clamped between -90 (top view) and 0 (side view).
	new_rotation.x = clamp(new_rotation.x + rotate_vertical * delta * camera_rotation_speed, 5, 85)
	cameraBase.rotation_degrees = new_rotation
