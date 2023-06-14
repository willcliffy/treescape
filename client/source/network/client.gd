extends Node

@onready var peer_id_label = get_node("../UI/NetworkInfo/UniquePeerID")
@onready var menu = get_node("../UI/Menu")

@onready var blue_spawn = get_node("../Map/BlueSpawn")
@onready var red_spawn = get_node("../Map/RedSpawn")

@onready var camera_base = get_node("../CameraBase")
@onready var camera = get_node("../CameraBase/Camera3D")
const RAY_CAST_LENGTH = 150

var local_player
var local_player_team
var local_player_spawn

const ADDRESS = "wss://stingray-app-amhyr.ondigitalocean.app"
var multiplayer_peer = WebSocketMultiplayerPeer.new()

var rng = RandomNumberGenerator.new()


func _unhandled_input(event):
	if local_player == null:
		return
	if not event is InputEventMouseButton or not event.pressed or event.button_index != 1:
		return

	var from = camera.project_ray_origin(event.position)
	var to = from + camera.project_ray_normal(event.position) * RAY_CAST_LENGTH
	var params = PhysicsRayQueryParameters3D.create(from, to, 4294967295, [local_player])
	var raycast_result = get_parent().get_world_3d().direct_space_state.intersect_ray(params)
	if raycast_result == null or not raycast_result.has("position"):
		return

	local_player.rpc_set_moving.rpc(raycast_result.position)


func spawn(player):
	local_player = player
	local_player.position = local_player_spawn
	local_player.rpc_set_team.rpc(local_player_team)
	local_player.get_node("Follow").remote_path = camera_base.get_path()


func _on_join_blue_pressed():
	local_player_team = "blue"
	local_player_spawn = blue_spawn.position + Vector3(rng.randf_range(-10, 10), 0, rng.randf_range(-10, 10))
	on_join_button_pressed()


func _on_join_red_pressed():
	local_player_team = "red"
	local_player_spawn = red_spawn.position + Vector3(rng.randf_range(-10, 10), 0, rng.randf_range(-10, 10))
	on_join_button_pressed()


func on_join_button_pressed():
	menu.visible = false
	var err = multiplayer_peer.create_client(ADDRESS)
	if err != OK:
		printerr("Failed to connect to game server: %s" % err)
		return

	print("Connected")
	multiplayer.multiplayer_peer = multiplayer_peer
	peer_id_label.text = "UID: " + str(multiplayer.get_unique_id())


func _on_message_input_text_submitted(new_text):
	if local_player == null:
		return

	local_player.rpc_display_message.rpc(new_text)
	$MessageInput.text = ""
	$MessageInput.release_focus()


func _on_red_resource_input_event(_camera, event, position, _normal, _shape_idx):
	if not event is InputEventMouseButton or not event.pressed:
		return

	local_player.rpc_set_moving.rpc(position)
	local_player.queue_action("collect_red", position)


func _on_blue_resource_input_event(_camera, event, position, _normal, _shape_idx):
	if not event is InputEventMouseButton or not event.pressed:
		return

	local_player.rpc_set_moving.rpc(position)
	local_player.queue_action("collect_blue", position)
