extends Node

const PORT = 8080

var multiplayer_peer

var connected_peers = []


func _ready():
	if "--server" not in OS.get_cmdline_args():
		return

	multiplayer_peer = WebSocketMultiplayerPeer.new()

	var err = multiplayer_peer.create_server(PORT)
	if err != OK:
		print("failed to start server %s" % err)
		return

	print("server listening on port %d" % PORT)
	multiplayer.multiplayer_peer = multiplayer_peer
	multiplayer_peer.peer_connected.connect(
		func(peer_id):
			await get_tree().create_timer(.1).timeout # wat
			print("new player connected: %s" % peer_id)
			rpc_spawn_players.rpc_id(peer_id, connected_peers)
			rpc_spawn_players.rpc([peer_id])
			get_parent().add_player_character(peer_id)
	)
	
	multiplayer_peer.peer_disconnected.connect(
		func(peer_id):
			await get_tree().create_timer(.1).timeout # wat
			print("player disconnected %s" % peer_id)
			rpc_despawn_players.rpc([peer_id])
	)

@rpc
func rpc_spawn_players(peer_ids):
	for peer_id in peer_ids:
		print("rpc spawning player: %d" % peer_ids)
		connected_peers.append(peer_id)
		get_parent().add_player_character(peer_id)

@rpc
func rpc_despawn_players(peer_ids):
	print("rpc despawn player: %d", peer_ids)
	pass
