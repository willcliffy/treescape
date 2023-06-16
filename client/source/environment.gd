extends WorldEnvironment

@export_range(0.0, 2400.0, 1.0) var time_of_day: float

# Called when the node enters the scene tree for the first time.
func _ready():
	$Sun.rotation_degrees.x = time_of_day / 2400.0 * 360.0
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	time_of_day += 100 * delta
	$Sun.rotation_degrees.x = time_of_day / 2400.0 * 360.0
