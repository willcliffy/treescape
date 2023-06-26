extends Node

@onready var world_scene = preload("res://world.tscn")
@onready var player_scene = preload("res://content/bishop.tscn")

const ADDRESS = "ws://localhost:8080"
var multiplayer_peer = WebSocketMultiplayerPeer.new()

var world
@onready var trees_container = $Map/Terrain
@onready var local_player
var connected_players = {}

@onready var cameraBase = get_node("CameraBase/Collider")
@onready var camera = cameraBase.get_node("Camera")


var camera_height : float = 2.0
var camera_rotation_speed : float = 50.0

const RAY_CAST_LENGTH = 500

func _ready():
	if "--server" in OS.get_cmdline_args():
		return

	multiplayer_peer.peer_connected.connect(
		func(peer_id):
			print("new player connected: %s" % peer_id)
	)

	multiplayer_peer.peer_disconnected.connect(
		func(peer_id):
			await get_tree().create_timer(.1).timeout # wat
			print("player disconnected %s" % peer_id)
	)

	var err = multiplayer_peer.create_client(ADDRESS)
	if err != OK:
		printerr("Failed to connect to game server: %s" % err)
		return

	multiplayer.multiplayer_peer = multiplayer_peer


func _input(event):
	if not event is InputEventMouseButton: return

	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		camera.position.y -= 1
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		camera.position.y += 1
		return

	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return

	var from = camera.project_ray_origin(event.position)
	var to = from + camera.project_ray_normal(event.position) * RAY_CAST_LENGTH
	var params := PhysicsRayQueryParameters3D.create(from, to, 4294967295, [local_player, trees_container])
	var raycast_result = get_parent().get_world_3d().direct_space_state.intersect_ray(params)
	var map = get_parent().get_world_3d().navigation_map
	var target_point := NavigationServer3D.map_get_closest_point_to_segment(map, from, to)

	if raycast_result.size() > 0:
		local_player.rpc_set_moving.rpc(target_point)


func _physics_process(delta):
	if not Input.is_anything_pressed():
		return

	if Input.is_key_pressed(KEY_Q):
		local_player.rpc_attempt_portal_activation.rpc()
		return

	var rotate_horizontal := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var rotate_vertical := Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")

	var new_rotation = cameraBase.rotation_degrees
	new_rotation.y += rotate_horizontal * delta * camera_rotation_speed
	new_rotation.x = clamp(new_rotation.x + rotate_vertical * delta * camera_rotation_speed, 5, 85)
	cameraBase.rotation_degrees = new_rotation


@rpc
func rpc_spawn_players(peer_ids):
	for peer_id in peer_ids:
		if peer_id in connected_players:
			continue
		print("rpc spawning player: %d" % peer_id)
		var player = player_scene.instantiate()
		add_child(player)
		connected_players[peer_id] = player


@rpc
func rpc_despawn_players(peer_ids):
	print("rpc despawn player: %d", peer_ids)
	pass

