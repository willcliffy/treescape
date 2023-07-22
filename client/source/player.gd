extends CharacterBody3D

signal activated_portal

@onready var NavAgent = $NavAgent
@onready var Character = $Character
@onready var Animations = $Character/AnimationPlayer
@onready var CameraBase = $CameraBase/Collider
@onready var Camera = $CameraBase/Collider/Camera

const SPEED = 200.0
const TURN_SPEED = 20.0

const CAMERA_ROTATION_SPEED = 50.0

const RAY_CAST_LENGTH = 500

@export var moving := false

var hasKey := false
var withinPortalRange = false


func _enter_tree():
	set_multiplayer_authority(str(name).to_int())


func _ready():
	print(is_multiplayer_authority())
	if not is_multiplayer_authority(): return

	Camera.current = true
	NavAgent.velocity_computed.connect(
		func(safe_velocity: Vector3):
			velocity = safe_velocity
			move_and_slide()
	)


func _input(event):
	if not is_multiplayer_authority(): return
	if not event is InputEventMouseButton: return

	handle_camera_zoom_input(event)

	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return

	var from = Camera.project_ray_origin(event.position)
	var to = from + Camera.project_ray_normal(event.position) * RAY_CAST_LENGTH
	var params := PhysicsRayQueryParameters3D.create(from, to, 4294967295, [self])
	var raycast_result = get_parent().get_world_3d().direct_space_state.intersect_ray(params)

	if raycast_result.size() > 0:
		var map = get_parent().get_world_3d().navigation_map
		var target_position := NavigationServer3D.map_get_closest_point(map, raycast_result.position)
		NavAgent.target_position = target_position
		moving = true
		rpc_play_animation.rpc("walk")


func _physics_process(delta):
	if not is_multiplayer_authority(): return

	if Input.is_key_pressed(KEY_Q):
		#rpc_attempt_portal_activation.rpc()
		return

	if Input.is_anything_pressed():
		handle_camera_rotation_input(delta)

	if not moving:
		return

	if NavAgent.is_navigation_finished():
		moving = false
		velocity = Vector3.ZERO
		rpc_play_animation.rpc("idle")
		return

	handle_movement_physics(delta)


func handle_camera_zoom_input(event):
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and Camera.position.y > 2:
		Camera.position.y -= 1
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and Camera.position.y < 500:
		Camera.position.y += 1
		return

func handle_camera_rotation_input(delta):
	var rotate_horizontal := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var rotate_vertical := Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	if rotate_horizontal != 0 or rotate_vertical != 0:
		var new_rotation = CameraBase.rotation_degrees
		new_rotation.y += rotate_horizontal * delta * CAMERA_ROTATION_SPEED
		new_rotation.x = clamp(new_rotation.x + rotate_vertical * delta * CAMERA_ROTATION_SPEED, 5, 85)
		CameraBase.rotation_degrees = new_rotation


func handle_movement_physics(delta):
	var next : Vector3 = NavAgent.get_next_path_position()

	var direction := global_position.direction_to(next)
	if direction.length() > 1:
		direction = direction.normalized()

	var current_dir = Character.transform.basis.z
	var angle = current_dir.angle_to(Vector3(direction.x, 0, direction.z))

	var cross_product = current_dir.cross(direction)
	if cross_product.y < 0:
		angle *= -1

	var current_rotation = Character.rotation.y
	var new_rotation = lerp_angle(current_rotation, current_rotation + angle, TURN_SPEED * delta)
	Character.rotation.y = new_rotation

	NavAgent.set_velocity(direction * delta * SPEED)
	move_and_slide()


@rpc("call_local")
func rpc_play_animation(animation):
	Animations.play(animation)


#func key_acquired(color):
#	hasKey = true
#	$Light.visible = true
#	$Light.light_color = color
#	$Light.light_energy = 10
#
#
#func entered_portal_range():
#	withinPortalRange = true
#
#
#func exited_portal_range():
#	withinPortalRange = false
#
#
#func attempt_portal_activation():
#	if not hasKey:
#		return
#	if withinPortalRange:
#		activated_portal.emit()
#		$Light.visible = false

