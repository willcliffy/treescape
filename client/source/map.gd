extends Node3D

signal map_loaded(playerLocation)

@onready var nav_region = $NavRegion
@onready var terrain_container = $NavRegion/Terrain
@onready var trees_container = $NavRegion/Trees
@onready var player = $"../Player"

@onready var portal_scene = preload("res://content/map/portal.tscn")
@onready var cube_scene = preload("res://content/cube.tscn")
@onready var key_scene = preload("res://content/key.tscn")

@onready var tree_scenes = [
	preload("res://content/map/trees_alt/tree_01.tscn"),
	preload("res://content/map/trees_alt/tree_02.tscn"),
	preload("res://content/map/trees_alt/tree_03.tscn"),
	preload("res://content/map/trees_alt/tree_04.tscn"),
	preload("res://content/map/trees_alt/tree_05.tscn"),
	preload("res://content/map/trees_alt/tree_blob_01.tscn"),
	preload("res://content/map/trees_alt/tree_blob_02.tscn"),
	preload("res://content/map/trees_alt/tree_blob_03.tscn"),
	preload("res://content/map/trees_alt/tree_blob_04.tscn"),
	preload("res://content/map/trees_alt/tree_round_top_01.tscn"),
	preload("res://content/map/trees_alt/tree_round_top_02.tscn"),
	preload("res://content/map/trees_alt/tree_round_top_03.tscn"),
	preload("res://content/map/trees_alt/tree_round_top_04.tscn"),
	preload("res://content/map/trees_alt/tree_tall_01.tscn"),
	preload("res://content/map/trees_alt/tree_tall_02.tscn"),
	preload("res://content/map/trees_alt/tree_tall_03.tscn"),
	preload("res://content/map/trees_alt/tree_tall_04.tscn"),
	preload("res://content/map/trees_alt/tree_tall_05.tscn"),
]

const GREEN = Color("#556B2F")
const BROWN = Color("#3D1F00")
const TAN = Color("#d2b48c")
const DEEP_BLUE = Color("#0000ff")

# Terrain noise
const TERRAIN_NOISE_SEED = 0
const TERRAIN_NOISE_FREQUENCY = 0.01
const TERRAIN_NOISE_FRACTAL_OCTIVES = 2
const TERRAIN_NOISE_FRACTAL_GAIN = 0.01

# River noise
const RIVER_NOISE_SEED = 0
const RIVER_NOISE_FREQUENCY = 0.012
const RIVER_NOISE_FRACTAL_OCTIVES = 1
const RIVER_NOISE_FRACTAL_GAIN = 1

# Terrain config
const TERRAIN_RADIUS = 200.0
const TERRAIN_UNDULATION_DEPTH = 0.9

# River config
const CHANNEL_THRESHOLD = 0.60
const CHANNEL_BANK_THRESHOLD = 0.55
const CHANNEL_DEPTH = 7.0

# Tree config
const TREE_DISTANCE = 7.0 # Minimum distance between trees

# Outer bank config
const BANK_START_DISTANCE = 0.9 * TERRAIN_RADIUS
const MAX_BANK_DEPTH = CHANNEL_DEPTH

# Landing area config
const LANDING_AREA_RADIUS = 17.5
const LANDING_AREA_HEIGHT = -0.25


# Class fields
var tree_locations = []
var landing_location


func lerp_float(a: float, b: float, t: float) -> float:
	return (1.0 - t) * a + t * b


func _ready():
	# Generate base terrain, including channels for water
	var terrain = generate_terrain()

	# Add the spawn area
	var magic_value = round(0.5 * TERRAIN_RADIUS + LANDING_AREA_RADIUS / 2.0)
	
	landing_location = Vector3(magic_value, 4 * LANDING_AREA_HEIGHT, magic_value)
	var portal_location = landing_location - Vector3(LANDING_AREA_RADIUS / 4.0, 0, LANDING_AREA_RADIUS / 4.0)
	var player_location = landing_location + Vector3(LANDING_AREA_RADIUS / 4.0, 0, LANDING_AREA_RADIUS / 4.0)

	terrain = generate_landing_area(landing_location, terrain[0], terrain[1])

	# Place objects like trees, bushes, and other obstacles.
	place_terrain_objects(terrain[0], terrain[1])

	# Instantiate Portal
	var portal_instance = portal_scene.instantiate()
	portal_instance.transform.origin = portal_location
	nav_region.add_child(portal_instance)
	portal_instance.set_owner(self)

	player.activated_portal.connect(portal_instance.enable)

	# Bake Navigation Mesh
	var start_time = Time.get_ticks_msec()
	nav_region.bake_finished.connect(
		func():
			var elapsed = (Time.get_ticks_usec() - start_time) / 1000000.0
			print("NavMesh bake finished after %f seconds" % elapsed)
			map_loaded.emit(player_location)
	)
	nav_region.bake_navigation_mesh()
	
	var red_key_instance = key_scene.instantiate()
	var red_key_spawn = landing_location + Vector3(LANDING_AREA_RADIUS/2, 1, 0) 
	red_key_instance.spawn(Color("red"), red_key_spawn)
	add_child(red_key_instance)
	red_key_instance.set_owner(self)
	
	var green_key_instance = key_scene.instantiate()
	var green_key_spawn = landing_location + Vector3(LANDING_AREA_RADIUS/2, 1, LANDING_AREA_RADIUS/2) 
	green_key_instance.spawn(Color("green"), green_key_spawn)
	add_child(green_key_instance)
	green_key_instance.set_owner(self)

	var blue_key_instance = key_scene.instantiate()
	var blue_key_spawn = landing_location + Vector3(0, 1, LANDING_AREA_RADIUS/2)
	blue_key_instance.spawn(Color("blue"), blue_key_spawn)
	add_child(blue_key_instance)
	blue_key_instance.set_owner(self)
	
	var packedScene = PackedScene.new()
	packedScene.pack(self)
	ResourceSaver.save(packedScene,"res://maps/map_seed_0_0_0.tscn")



func generate_terrain():
	var terrain_dictionary = {}
	var max_height = float("-inf")

	var terrain_noise = FastNoiseLite.new()
	terrain_noise.seed = TERRAIN_NOISE_SEED
	terrain_noise.frequency = TERRAIN_NOISE_FREQUENCY
	terrain_noise.fractal_octaves = TERRAIN_NOISE_FRACTAL_OCTIVES
	terrain_noise.fractal_gain = TERRAIN_NOISE_FRACTAL_GAIN

	var river_noise = FastNoiseLite.new()
	river_noise.seed = RIVER_NOISE_SEED
	river_noise.frequency = RIVER_NOISE_FREQUENCY
	river_noise.fractal_octaves = RIVER_NOISE_FRACTAL_OCTIVES
	river_noise.fractal_gain = RIVER_NOISE_FRACTAL_OCTIVES
	river_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED

	for x in range(-TERRAIN_RADIUS, TERRAIN_RADIUS):
		for z in range(-TERRAIN_RADIUS, TERRAIN_RADIUS):
			var dist_to_center = Vector2(x, z).length()
			if dist_to_center > TERRAIN_RADIUS:
				continue

			var terrain_noise_sample = terrain_noise.get_noise_2d(x, z)
			var height = terrain_noise_sample * TERRAIN_UNDULATION_DEPTH 

			var color_gradient = (terrain_noise_sample + 1.01) / 2
			var color = BROWN.lerp(GREEN, color_gradient)

			var channel_gradient = (river_noise.get_noise_2d(x, z) + 0.99) / 2.0
			if channel_gradient > CHANNEL_THRESHOLD:
				var channelDepth = max((channel_gradient - CHANNEL_THRESHOLD) * CHANNEL_DEPTH, 0)
				height -= channelDepth

			# Create bank around the island
			if dist_to_center > BANK_START_DISTANCE:
				var bank_gradient = (dist_to_center - BANK_START_DISTANCE) / (TERRAIN_RADIUS - BANK_START_DISTANCE)
				height -= bank_gradient * MAX_BANK_DEPTH
				color = color.lerp(DEEP_BLUE, bank_gradient)

			terrain_dictionary[Vector2(x, z)] = {"height": height, "color": color, "channel": channel_gradient}

			# update max height
			if height > max_height:
				max_height = height

	return [terrain_dictionary, max_height]

func generate_landing_area(center, terrain_dictionary, max_height):
	for x in range(center.x - LANDING_AREA_RADIUS, center.x + LANDING_AREA_RADIUS):
		for z in range(center.z - LANDING_AREA_RADIUS, center.z + LANDING_AREA_RADIUS):
			var dist_from_center = Vector3(x, 0, z) - center
			if dist_from_center.length() > LANDING_AREA_RADIUS:
				continue
			
			var location = Vector2(x, z)
			var height = LANDING_AREA_HEIGHT
			
			var magic_cutoff_for_blending_terrain = 0.885 * BANK_START_DISTANCE
			
			if location in terrain_dictionary:
				if location.length() <= magic_cutoff_for_blending_terrain:
					height = lerp_float(height, terrain_dictionary[location]["height"], dist_from_center.length() / LANDING_AREA_RADIUS)

			terrain_dictionary[Vector2(x, z)] = {"height": height, "color": Color("black"), "channel": 0}

	return [terrain_dictionary, max_height]


func place_terrain_objects(terrain_dictionary, max_height):
	for key in terrain_dictionary.keys():
		var x = key.x
		var z = key.y

		var terrain_height = terrain_dictionary[key]["height"] - max_height
		var terrain_color = terrain_dictionary[key]["color"]
		var channel_gradient = terrain_dictionary[key]["channel"]

		var cube_instance = cube_scene.instantiate()

		cube_instance.transform.origin = Vector3(x, terrain_height, z)

		var cube_mesh = cube_instance.get_node("Mesh")
		cube_mesh.material_override = StandardMaterial3D.new()
		cube_mesh.material_override.albedo_color = terrain_color

		terrain_container.add_child(cube_instance)
		cube_instance.set_owner(self)

		if channel_gradient > CHANNEL_BANK_THRESHOLD:
			continue

		var tree_location = Vector3(x, terrain_height, z)
		if tree_location.length() > BANK_START_DISTANCE:
			continue

		# Check if the new tree is far enough from existing structures
		if tree_location.distance_to(landing_location) < LANDING_AREA_RADIUS:
			continue

		var too_close = false
		for pos in tree_locations:
			if pos.distance_to(tree_location) < TREE_DISTANCE:
				too_close = true
				break

		if not too_close:
			var tree_type = randi() % len(tree_scenes) # Randomly select a type of tree
			var tree_instance = tree_scenes[tree_type].instantiate() # Instantiate the selected tree
			tree_instance.transform.origin = tree_location # Place the tree on top of the terrain block
			var random_rotation = Quaternion(Vector3.UP, randf_range(0, 360)) # Generate a random rotation quaternion
			tree_instance.transform.basis = Basis(random_rotation) # Set the rotation of the tree instance
			trees_container.add_child(tree_instance) # Add the tree to the scene
			tree_instance.set_owner(self)
			tree_locations.append(tree_location)

