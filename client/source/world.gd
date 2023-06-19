extends Node3D

@onready var map = get_node("Map")


func _process(_delta):
	if multiplayer.get_unique_id() == 0:
		return

	var player = get_parent().get_node(str(multiplayer.get_unique_id()))
	if not player:
		return

	map.link_local_player(player)
	set_process(false)
