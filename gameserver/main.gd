extends Node

@onready var player_scene = preload("res://player.tscn")

var connected_peers := []


func _ready():
	if "--server" in OS.get_cmdline_args():
		return

	var multiplayer_peer := WebSocketMultiplayerPeer.new()

	var err := multiplayer_peer.create_server(8080)
	if err != OK:
		printerr("Failed to connect to game server: %s" % err)
		return

	multiplayer.peer_connected.connect(
		func(peer_id):
			print("new player connected: %s" % peer_id)
			var pc := player_scene.instantiate()
			pc.set_multiplayer_authority(peer_id)
			add_child(pc)
			rpc_spawn_players.rpc([peer_id])
			rpc_spawn_players.rpc_id(peer_id, connected_peers)
			connected_peers.append(peer_id)
	)

	multiplayer.peer_disconnected.connect(
		func(peer_id):
			print("player disconnected %s" % peer_id)
			connected_peers.erase(peer_id)
	)

	multiplayer.multiplayer_peer = multiplayer_peer


@rpc
func rpc_spawn_players(_peer_ids): pass

@rpc
func rpc_despawn_players(_peer_ids): pass
