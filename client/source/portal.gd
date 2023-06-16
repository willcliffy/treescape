extends Node3D

@onready var player = $"../../../Player"
@onready var spirals = $Node3D

var enabled = false


var min_scale = 0.8
var max_scale = 0.9

var time: float = 0
var period: float = PI  # length of time for one complete cycle (in seconds)
var scale_range: float = (max_scale - min_scale) / 2  # amplitude of the wave
var average_scale: float = (max_scale + min_scale) / 2  # mid-point between max and min


func _process(delta):
	time += delta
	if not enabled: return

	spirals.rotate_z(delta)

	var scale_level = average_scale + scale_range * sin(time * 2 * PI / period)
	spirals.scale = Vector3(scale_level, scale_level, scale_level)
	
	print(scale_level)

func enable():
	enabled = true
	spirals.visible = true

func disable():
	enabled = false
	spirals.visible = false


func _on_area_3d_body_entered(body):
	if body == player:
		player.rpc_entered_portal_range.rpc()


func _on_area_3d_body_exited(body):
	if body == player:
		player.rpc_exited_portal_range.rpc()
