extends Node


@onready var Player = preload("res://content/Player.tscn")

const PORT = 8080

var multiplayer_peer = WebSocketMultiplayerPeer.new()


func _ready():
	if "--server" in OS.get_cmdline_args():
		start_server()


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
			add_child(player)
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
