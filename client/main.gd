extends Node

@onready var performance_ui: Label = get_node("Debug/Performance")

@onready var Player = preload("res://content/Player.tscn")
@onready var World = preload("res://content/world/World.tscn")

const PORT = 8080

var multiplayer_peer = WebSocketMultiplayerPeer.new()


func _process(_delta):
	performance_ui.text = """%d FPS (%.2f mspf)

Currently rendering:
%d objects
%dK primitive indices
%d draw calls
""" % [
	Engine.get_frames_per_second(),
	1000.0 / Engine.get_frames_per_second(),
	RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
	RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) * 0.001,
	RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
]


func _ready():
	if "--server" in OS.get_cmdline_args():
		start_server()
	else:
		get_viewport().use_occlusion_culling = true
		get_viewport().mesh_lod_threshold = 0.0


func start_server():
	var err := multiplayer_peer.create_server(PORT)
	if err != OK:
		print("failed to start server: ", err)
		return

	multiplayer.peer_connected.connect(
		func(peer_id):
			print("player connected: ", peer_id)
			var player = Player.instantiate()
			player.name = str(peer_id)
			add_child(player) # replicated to all clients through MultiplayerSpawner
	)

	multiplayer.peer_disconnected.connect(
		func(peer_id):
			print("player disconnected: ", peer_id)
			var player = get_node_or_null(str(peer_id))
			if player:
				player.queue_free()
	)

	multiplayer.multiplayer_peer = multiplayer_peer
	print("server listening on port: ", PORT)


func start_client(address):
	print("loading world")
	var world = World.instantiate()
	add_child(world)

	print("attempting connection to ", address)
	var err = multiplayer_peer.create_client(address)
	if err != OK:
		printerr("Failed to connect to game server: %s" % err)
		return

	multiplayer.multiplayer_peer = multiplayer_peer


func _on_address_text_submitted(new_text):
	$UI.hide()
	start_client(new_text)


func _on_join_pressed():
	$UI.hide()
	start_client($UI/Address.text)


func _on_host_pressed():
	start_server()
