extends WorldEnvironment


@export_range(0.0, 2400.0, 1.0) var time_of_day: float

## e.g. a value of 10 means that 1 minute in real-life is 10 min in game
@export_range(1.0, 100.0, 1.0) var time_multiplyer: float


func _ready():
	$Sun.rotation_degrees.x = time_of_day / 2400.0 * 360.0


func _process(delta):
	time_of_day += time_multiplyer * delta
	$Sun.rotation_degrees.x = time_of_day / 2400.0 * 360.0
	$Sun/SunLight.light_energy = 2
