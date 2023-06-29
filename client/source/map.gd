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


func _exit_tree():
	for chunk_key in _loaded_chunks:
		remove_chunk(chunk_key)


func link_local_player(player):
	target = player


### Terrain generation ###

func generate_all() :
	var f = FileAccess.open("res://output.json", FileAccess.READ)
	var data = f.get_as_text()
	f.close()

	var json = JSON.parse_string(data)

	for key in json.keys():
		var chunk_mesh = create_chunk_mesh(mesh_array_from_dictionary(json[key]))
		_loaded_chunks[key] = chunk_mesh
		create_navigation_region(chunk_mesh)

func mesh_array_from_dictionary(chunk_data: Dictionary) -> Array:
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)

	var verts = PackedVector3Array()
	for vertex in chunk_data["vertices"]:
		verts.push_back(Vector3(vertex["X"], vertex["Y"], vertex["Z"]))
	
	var norms = PackedVector3Array()
	for normal in chunk_data["normals"]:
		norms.push_back(Vector3(normal["X"], normal["Y"], normal["Z"]))
	
	var uvs = PackedVector2Array()
	for uv in chunk_data["uvs"]:
		uvs.push_back(Vector2(uv["X"], uv["Z"]))

	var inds = PackedInt32Array()
	for index in chunk_data["indices"]:
		inds.push_back(index)

	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX]  = inds

	return arr

func create_chunk_mesh(arr) -> MeshInstance3D:
	var chunk_mesh = MeshInstance3D.new()
	chunk_mesh.mesh = ArrayMesh.new()
	chunk_mesh.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	chunk_mesh.mesh.surface_set_material(0, terrain_material)

	chunk_mesh.create_trimesh_collision()
	add_child(chunk_mesh)
	chunk_mesh.set_owner(self)

	return chunk_mesh


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

func remove_chunk(key: String) -> void:
	var chunk = _loaded_chunks[key]
	var erased = _loaded_chunks.erase(key)
	# TODO - keep track of and clean up nav regions
	if erased: chunk.queue_free()


func make_chunk_key(chunk_position: Vector2) -> String:
	return str(chunk_position.x, ",", chunk_position.y)

func custom_smoothstep(x: float, smoothness: float) -> float:
	var mapped_smoothness = 1 / (1 - smoothness + 0.00001)  # A small number is added to prevent division by zero
	var t = pow(clamp(x, 0.0, 1.0), mapped_smoothness)
	return t * t * (3.0 - 2.0 * t)

