extends CharacterBody3D

signal activated_portal

@onready var navigation_agent = $NavAgent
@onready var character = $Character
@onready var animationPlayer = $Character/AnimationPlayer

const SPEED = 4000.0
const TURN_SPEED = 20.0

var moving = false
var hasKey = false
var withinPortalRange = false


func _ready():
	$Follow.remote_path = get_parent().get_node("CameraBase").get_path()
	navigation_agent.velocity_computed.connect(
		func(safe_velocity: Vector3):
			velocity = safe_velocity
			move_and_slide()
	)


func _physics_process(delta):
	if not moving:
		return

	if navigation_agent.is_navigation_finished():
		animationPlayer.play("idle")
		moving = false
		return

	var next : Vector3 = navigation_agent.get_next_path_position()

	var direction := global_position.direction_to(next)
	if direction.length() > 1:
		direction = direction.normalized()

	var current_dir = character.transform.basis.z
	var angle = current_dir.angle_to(direction)

	# Determine the direction of rotation
	var cross_product = current_dir.cross(direction)
	if cross_product.y < 0:
		angle *= -1

	var current_rotation = character.rotation.y
	var new_rotation = lerp_angle(current_rotation, current_rotation + angle, TURN_SPEED * delta)
	character.rotation.y = new_rotation

	navigation_agent.set_velocity(direction * delta * SPEED)
	move_and_slide()


@rpc("unreliable", "call_local")
func rpc_set_moving(target):
	navigation_agent.target_position = target
	animationPlayer.play("walk")
	moving = true


@rpc("reliable", "call_local")
func rpc_set_position(authority_position):
	global_position = authority_position


@rpc("reliable", "call_local")
func rpc_key_acquired(color):
	hasKey = true
	$Light.visible = true
	$Light.light_color = color
	$Light.light_energy = 10


@rpc("reliable", "call_local")
func rpc_entered_portal_range():
	withinPortalRange = true


@rpc("reliable", "call_local")
func rpc_exited_portal_range():
	withinPortalRange = false


@rpc("reliable", "call_local")
func rpc_attempt_portal_activation():
	if not hasKey:
		return
	if withinPortalRange:
		activated_portal.emit()
		$Light.visible = false

