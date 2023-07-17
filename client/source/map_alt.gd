@tool
extends Node

# Scenes
@onready var portal_scene = preload("res://content/objects/Portal.tscn")
@onready var tree_scenes = [
	preload("res://content/world/trees/tree_01.tscn"),
	preload("res://content/world/trees/tree_02.tscn"),
	preload("res://content/world/trees/tree_03.tscn"),
	preload("res://content/world/trees/tree_04.tscn"),
	preload("res://content/world/trees/tree_05.tscn"),
	preload("res://content/world/trees/tree_blob_01.tscn"),
	preload("res://content/world/trees/tree_blob_02.tscn"),
	preload("res://content/world/trees/tree_blob_03.tscn"),
	preload("res://content/world/trees/tree_blob_04.tscn"),
	preload("res://content/world/trees/tree_round_top_01.tscn"),
	preload("res://content/world/trees/tree_round_top_02.tscn"),
	preload("res://content/world/trees/tree_round_top_03.tscn"),
	preload("res://content/world/trees/tree_round_top_04.tscn"),
	preload("res://content/world/trees/tree_tall_01.tscn"),
	preload("res://content/world/trees/tree_tall_02.tscn"),
	preload("res://content/world/trees/tree_tall_03.tscn"),
	preload("res://content/world/trees/tree_tall_04.tscn"),
	preload("res://content/world/trees/tree_tall_05.tscn"),
]

# Noise
@onready var river_noise = preload("res://content/world/river/river_noise.tres")
@onready var terrain_undulation_noise = preload("res://content/world/terrain/terrain_undulation_noise.tres")
@onready var tree_placement_noise = preload("res://content/world/trees/placement_noise.tres")

# Materials
@onready var terrain_material = preload("res://content/world/terrain/terrain_material.tres")

# Meshes
@onready var water_mesh = preload("res://content/world/water/water_mesh.tres")


# Misc
@onready var nav_map = get_parent().get_world_3d().get_navigation_map()


# Config
const TERRAIN_UNDULATION_RADIUS: float = 10.0

const WATER_LEVEL: float = -1.0
const RIVER_DEPTH_RADIUS: float = 12.0

const BANK_DEPTH: float = 12.0
const BANK_LENGTH: float = 20.0

const TREE_PLACEMENT_THRESHOLD: float = 0.6
const TREE_DENSITY_THRESHOLD: float = 0.8
const TREE_DISTANCE_NORMAL: float = 5.0 # Minimum distance between trees
const TREE_DISTANCE_DENSE: float = 3.0
const TREE_START_HEIGHT: float = 0.0

const DISTANCE_TO_REGENERATE_MAP: float = 10.0

# Config Toggles
const BANK_AT_MAP_EDGE: bool = false;

# Rendering
const RENDER_DISTANCE: float = 5.0
const RENDER_CHUNK_SIZE: float = 100.0
const RENDER_CHUNK_DENSITY: float = 1.0
const RENDER_VERT_STEP: float = RENDER_CHUNK_SIZE / RENDER_CHUNK_DENSITY
const RENDER_UV_STEP: float = 1.0 / RENDER_CHUNK_DENSITY 


## Terrain generation
var tree_locations = []

var _loaded_chunks: Dictionary = {}
var last_generation_location = Vector3.ZERO
var target

var flat_areas = [
	{
		"center": Vector2(0, 0),
		"radius": 30.0,
		"smoothness": 0.8,
		"height": 0.0
	}
]


func _ready():
	for area in flat_areas:
		var total_height = 0.0
		var sample_count = 0

		# Define the resolution of the sampling. 
		# Lower values give more accurate results but are more computationally expensive
		var resolution = RENDER_CHUNK_DENSITY
		
		if area.has("height"):
			continue

		for x in range(int(area.center.x - area.radius), int(area.center.x + area.radius), resolution):
			for z in range(int(area.center.y - area.radius), int(area.center.y + area.radius), resolution):
				var dist = Vector2(x, z).distance_to(area.center)
				if dist <= area.radius:
					total_height += sample_terrain_noise_unmodified(x, z)
					sample_count += 1

		area.height = total_height / sample_count if sample_count != 0 else 0.0

	NavigationServer3D.map_set_edge_connection_margin(nav_map, 5)

	# see: https://docs.godotengine.org/en/4.0/tutorials/navigation/navigation_using_navigationservers.html#waiting-for-synchronization
	await get_tree().physics_frame

	var s := Time.get_unix_time_from_system()
	generate_all()
	last_generation_location = Vector3(0, 0, 0)
	var elapsed :=  Time.get_unix_time_from_system() - s
	print("Terrain generation completed in: ", elapsed)

	# save scene if needed
#	var packed_scene = PackedScene.new()
#	packed_scene.pack(get_tree().get_current_scene())
#	ResourceSaver.save(packed_scene, "res://my_scene.tscn")

	# Instantiate Portal
#	var portal_instance = portal_scene.instantiate()
#	add_child(portal_instance)
#	portal_instance.set_owner(self)
#	player.activated_portal.connect(portal_instance.enable)


func _physics_process(_delta):
	if not target:
		return

	var position = Vector3.ZERO
	if target:
		position = target.position
	if position.x < 0: position.x -= RENDER_CHUNK_SIZE
	if position.z < 0: position.z -= RENDER_CHUNK_SIZE
	var chunk_x: int = int(position.x / RENDER_CHUNK_SIZE)
	var chunk_z: int = int(position.z / RENDER_CHUNK_SIZE)

	if last_generation_location.distance_to(target.position) >= DISTANCE_TO_REGENERATE_MAP:
		last_generation_location = target.position
		generate(chunk_x, chunk_z)

	for key in _loaded_chunks:
		var chunk_pos = parse_chunk_key(key)
		if chunk_pos.distance_to(Vector2(chunk_x, chunk_z)) > RENDER_DISTANCE:
			remove_chunk(key)


func _exit_tree():
	for chunk_key in _loaded_chunks:
		remove_chunk(chunk_key)


func link_local_player(player):
	target = player


### Terrain generation ###

func generate_all() -> void:
	var terrain_data = load_terrain_data("res://terrain.json")
	for chunk_data in terrain_data:
		var chunk_position = chunk_data["chunk_position"]
		var position = Vector3(chunk_position.x * RENDER_CHUNK_SIZE, 0, chunk_position.y * RENDER_CHUNK_SIZE)
		var chunk_mesh = create_chunk_mesh(chunk_data, position)
		create_navigation_region(chunk_mesh)

func generate(x, z) -> void:
	for ix in range(x - RENDER_DISTANCE, x + RENDER_DISTANCE + 1):
		for iz in range(z - RENDER_DISTANCE, z + RENDER_DISTANCE + 1):
			var chunk_position = Vector2(ix, iz)
			if chunk_position.distance_to(Vector2(x, z)) > RENDER_DISTANCE: 
				continue
			if _loaded_chunks.has(make_chunk_key(chunk_position)): 
				continue
			add_chunk(chunk_position)


# Load the terrain data from the JSON file


func add_chunk(chunk_position):
	var _key := make_chunk_key(chunk_position)
#	var chunk_data = terrain_data[key]
#	if chunk_data:
#		var position = Vector3(chunk_position.x * RENDER_CHUNK_SIZE, 0, chunk_position.y * RENDER_CHUNK_SIZE)
#		var chunk_mesh = create_chunk_mesh(chunk_data, position, chunk_position)
#		create_navigation_region(chunk_mesh)

func create_chunk_mesh(data, chunk_position: Vector3) -> MeshInstance3D:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(terrain_material)

	# Reconstruct the mesh from the data
	for i in range(len(data["vertices"])):
		var vert = Vector3(data["vertices"][i]["x"], data["vertices"][i]["y"], data["vertices"][i]["z"])
		var norm = Vector3(data["normals"][i]["x"], data["normals"][i]["y"], data["normals"][i]["z"])
		var uv = Vector2(data["uvs"][i]["x"], data["uvs"][i]["y"])
		
		st.set_normal(norm)
		st.set_uv(uv)
		st.add_vertex(vert)

	# Add triangles
	#for i in range(0, len(data["indices"]), 3):
	#	st.add_triangle_fan([data["indices"][i], data["indices"][i + 1], data["indices"][i + 2]])

	var chunk_mesh = MeshInstance3D.new()

	chunk_mesh.mesh = st.commit()
	#chunk_mesh.create_trimesh_collision()

	add_child(chunk_mesh)
	chunk_mesh.set_owner(self)

	_loaded_chunks[make_chunk_key(chunk_position)] = chunk_mesh

	return chunk_mesh

# Helper function to load the terrain data from the JSON file
func load_terrain_data(file_path):
	var file := FileAccess.open(file_path, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	return data


func create_navigation_region(chunk_mesh: MeshInstance3D) -> void:
	var region = NavigationRegion3D.new()
	NavigationServer3D.region_set_map(region.get_region_rid(), nav_map)

	var nav_mesh: NavigationMesh = NavigationMesh.new()
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.agent_radius = 1
	nav_mesh.agent_height = 3
	nav_mesh.agent_max_slope = 30
	
	nav_mesh.create_from_mesh(chunk_mesh.mesh)
	NavigationServer3D.region_set_navigation_mesh(region.get_region_rid(), nav_mesh)
	add_child(region)
	region.set_owner(self)


func try_place_tree(terrain_pos: Vector3) -> Node3D:
	if terrain_pos.y <= TREE_START_HEIGHT:
		return
		
	for area in flat_areas:
		var distance_to_center = area.center.distance_to(Vector2(terrain_pos.x, terrain_pos.z))
		if distance_to_center < area.radius:
			return

	var distance_between_trees = TREE_DISTANCE_NORMAL

	var sample = tree_placement_noise.get_noise_2d(terrain_pos.x, terrain_pos.z)
	sample = (1.0 + sample) / 2.0
	if sample < TREE_PLACEMENT_THRESHOLD:
		return
	if sample > TREE_DENSITY_THRESHOLD:
		distance_between_trees = TREE_DISTANCE_DENSE

	for pos in tree_locations:
		if pos.distance_to(terrain_pos) < distance_between_trees:
			return null

	var tree_type = randi() % len(tree_scenes) # Randomly select a type of tree
	var tree_instance = tree_scenes[tree_type].instantiate() # Instantiate the selected tree
	tree_instance.transform.origin = terrain_pos - Vector3(0, 0.5, 0) # Place the tree on top of the terrain block
	var random_rotation = Quaternion(Vector3.UP, randf_range(0, 360)) # Generate a random rotation quaternion
	tree_instance.transform.basis = Basis(random_rotation) # Set the rotation of the tree instance
	tree_locations.append(terrain_pos)
	return tree_instance


func try_place_water():
	SurfaceTool.new()


func remove_chunk(key: String) -> void:
	var chunk = _loaded_chunks[key]
	var erased = _loaded_chunks.erase(key)
	# TODO - keep track of and clean up nav regions
	if erased: chunk.queue_free()


func make_chunk_key(chunk_position) -> String:
	return str(chunk_position.x, ",", chunk_position.y)


func parse_chunk_key(key: String) -> Vector2:
	var arr_vec = key.split(",")
	#print(Vector2(int(arr_vec[0]), int(arr_vec[1])))
	return Vector2(int(arr_vec[0]), int(arr_vec[1]))


func sample_terrain_noise(x: float, z: float) -> float:
	for area in flat_areas:
		var distance_to_center = area.center.distance_to(Vector2(x, z))
		if distance_to_center < area.radius:
			var normalized_distance = distance_to_center / area.radius
			var smoothed_distance = custom_smoothstep(normalized_distance, area.smoothness)
			return lerp(area.height, sample_terrain_noise_unmodified(x, z), smoothed_distance)

	return sample_terrain_noise_unmodified(x, z)


func sample_terrain_noise_unmodified(x: float, z: float) -> float:
	var undulation_noise_sample = terrain_undulation_noise.get_noise_2d(x, z)
	var sample = undulation_noise_sample * TERRAIN_UNDULATION_RADIUS

	var river_noise_sample = river_noise.get_noise_2d(x, z)
	if river_noise_sample > 0:
		sample -= river_noise_sample * RIVER_DEPTH_RADIUS

	if BANK_AT_MAP_EDGE:
		var dist_from_bank = 0.7 * RENDER_DISTANCE * RENDER_CHUNK_SIZE - Vector2(x, z).length()
		if dist_from_bank < 0:
			sample += BANK_DEPTH * dist_from_bank / BANK_LENGTH

	return sample


func custom_smoothstep(x: float, smoothness: float) -> float:
	var mapped_smoothness = 1 / (1 - smoothness + 0.00001)  # A small number is added to prevent division by zero
	var t = pow(clamp(x, 0.0, 1.0), mapped_smoothness)
	return t * t * (3.0 - 2.0 * t)

