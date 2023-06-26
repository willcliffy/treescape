extends Node

@onready var player_scene = preload("res://player.tscn")

var connected_peers = {}


func _ready():
	if "--server" in OS.get_cmdline_args():
		return

	var multiplayer_peer = WebSocketMultiplayerPeer.new()

	multiplayer_peer.peer_connected.connect(
		func(peer_id):
			print("new player connected: %s" % peer_id)
			var pc = player_scene.instantiate()
			pc.set_multiplayer_authority(peer_id)
			add_child(pc)
	)

	multiplayer_peer.peer_disconnected.connect(
		func(peer_id):
			print("player disconnected %s" % peer_id)
	)

	var err = multiplayer_peer.create_server(8080)
	if err != OK:
		printerr("Failed to connect to game server: %s" % err)
		return

	multiplayer.multiplayer_peer = multiplayer_peer

@rpc
func rpc_spawn_players(peer_ids):
	for peer_id in peer_ids:
		print("rpc spawning player: %d" % peer_ids)
		connected_peers.append(peer_id)
		get_parent().add_player_character(peer_id)


@rpc
func rpc_despawn_players(peer_ids): pass
