extends Node3D

@onready var localPlayer = get_parent().get_parent().get_node("Player")
@onready var lightEnergy = $Light.light_energy
@onready var fadeOutDimRate = lightEnergy / FADE_OUT_DURATION

const FADE_OUT_DURATION = 1.0

var fadingOut = false
var fadeOutLeft = FADE_OUT_DURATION

var color


func spawn(spawnColor: Color, spawnPosition: Vector3):
	color = spawnColor
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	$Mesh.material_override = material
	$Light.light_color = color
	
	position = spawnPosition


func _process(delta):
	if fadingOut:
		fadeOutLeft -= delta
		if fadeOutLeft <= 0:
			queue_free()
			return
		scale -= delta * Vector3.ONE / FADE_OUT_DURATION
		$Light.light_energy -= delta * fadeOutDimRate

	rotate_x(delta/4)
	rotate_y(delta)
	rotate_z(delta/2)


func _on_area_body_entered(body):
	if body == localPlayer:
		localPlayer.rpc_key_acquired.rpc(color)
		fadingOut = true
