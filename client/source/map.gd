extends Node

## Scenes
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

## Resources (Materials, Noise functions, ...)
@onready var terrain_material = preload("res://content/world/terrain/terrain_material.tres")
@onready var river_noise = preload("res://content/world/river/river_noise.tres")
@onready var terrain_undulation_noise = preload("res://content/world/terrain/terrain_undulation_noise.tres")

## Misc
@onready var nav_map = get_parent().get_world_3d().get_navigation_map()


## Misc config
const TERRAIN_UNDULATION_RADIUS = 1.0

const RIVER_DEPTH_RADIUS = 3.5

const BANK_DEPTH = 10.0
const BANK_LENGTH = 20.0

const TREE_DISTANCE = 5.0 # Minimum distance between trees
const TREE_START_HEIGHT = 0.0

## Rendering
const RENDER_DISTANCE: float = 8.0
const RENDER_CHUNK_SIZE: float = 8.0
const RENDER_CHUNK_DENSITY: float = 2.0
const RENDER_VERT_STEP: float = RENDER_CHUNK_SIZE / RENDER_CHUNK_DENSITY
const RENDER_UV_STEP: float = 1.0 / RENDER_CHUNK_DENSITY 


## Terrain generation
var _needs_collider: bool = true

var tree_locations = []

var _loaded_chunks: Dictionary = {}
var last_generation_location


func _ready():
	NavigationServer3D.map_set_edge_connection_margin(nav_map, 5)

	# see: https://docs.godotengine.org/en/4.0/tutorials/navigation/navigation_using_navigationservers.html#waiting-for-synchronization
	await get_tree().physics_frame

	var s := Time.get_unix_time_from_system()
	generate()
	var elapsed :=  Time.get_unix_time_from_system() - s
	print("Terrain generation completed in: ", elapsed)

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


### Terrain generation ###

func generate() -> void:
	var position = Vector3.ZERO
	if position.x < 0: position.x -= RENDER_CHUNK_SIZE
	if position.z < 0: position.z -= RENDER_CHUNK_SIZE
	var chunk_x: int = int(position.x / RENDER_CHUNK_SIZE)
	var chunk_z: int = int(position.z / RENDER_CHUNK_SIZE)

	for ix in range(chunk_x - RENDER_DISTANCE, chunk_x + RENDER_DISTANCE + 1):
		for iz in range(chunk_z - RENDER_DISTANCE, chunk_z + RENDER_DISTANCE + 1):
			var chunk_position = Vector2(ix, iz)
			if chunk_position.distance_to(Vector2(chunk_x, chunk_z)) > RENDER_DISTANCE: 
				continue
			if _loaded_chunks.has(make_chunk_key(chunk_position)): 
				continue
			add_chunk(Vector2(ix, iz))

	for key in _loaded_chunks:
		var chunk_pos = parse_chunk_key(key)
		if chunk_pos.distance_to(Vector2(chunk_x, chunk_z)) > RENDER_DISTANCE:
			remove_chunk(key)


func add_chunk(chunk_position: Vector2) -> void:
	var position = Vector3(chunk_position.x * RENDER_CHUNK_SIZE, 0, chunk_position.y * RENDER_CHUNK_SIZE)

	var arr = []
	arr.resize(Mesh.ARRAY_MAX)

	var verts = PackedVector3Array()
	var norms = PackedVector3Array()
	var uvs   = PackedVector2Array()
	var inds  = PackedInt32Array()

	var chunk_mesh = MeshInstance3D.new()
	chunk_mesh.mesh = ArrayMesh.new()

	for x in RENDER_CHUNK_DENSITY + 1:
		for z in RENDER_CHUNK_DENSITY + 1:
			var vert = Vector3(position.x + x * RENDER_VERT_STEP, 0.0, position.z + z * RENDER_VERT_STEP)
			var uv = Vector2(1.0 - x * RENDER_UV_STEP, 1.0 - z * RENDER_UV_STEP)

			vert.y = sample_terrain_noise(vert.x, vert.z)

			var tree_instance = try_place_tree(vert)
			if tree_instance:
				chunk_mesh.add_child(tree_instance)
				tree_instance.set_owner(chunk_mesh)

			var top = vert - Vector3(vert.x, sample_terrain_noise(vert.x, vert.z + RENDER_VERT_STEP), vert.z + RENDER_VERT_STEP)
			var right = vert - Vector3(vert.x + RENDER_VERT_STEP, sample_terrain_noise(vert.x + RENDER_VERT_STEP, vert.z), vert.z)
			var norm = top.cross(right).normalized()

			verts.push_back(vert)
			norms.push_back(norm)
			uvs.push_back(uv)

			# Make & index a clockwise face from verts a, b, c, d
			if x < RENDER_CHUNK_DENSITY and z < RENDER_CHUNK_DENSITY:
				var a = z + x * (RENDER_CHUNK_DENSITY + 1)
				var b = a + 1
				var d = (RENDER_CHUNK_DENSITY + 1) * (x + 1) + z
				var c = d + 1

				inds.push_back(d) 
				inds.push_back(b)
				inds.push_back(a)

				inds.push_back(d)
				inds.push_back(c)
				inds.push_back(b)

	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX]  = inds

	chunk_mesh.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	chunk_mesh.mesh.surface_set_material(0, terrain_material)

	_loaded_chunks[make_chunk_key(chunk_position)] = chunk_mesh

	if not _needs_collider:
		$Terrain.add_child(chunk_mesh)
		chunk_mesh.set_owner(self)
		return

	chunk_mesh.create_trimesh_collision()
	$Terrain.add_child(chunk_mesh)
	chunk_mesh.set_owner($Terrain)

	# TODO - keep track of and clean up nav regions
	var region: RID = NavigationServer3D.region_create()
	NavigationServer3D.region_set_transform(region, Transform3D())
	NavigationServer3D.region_set_map(region, nav_map)
	var nav_mesh: NavigationMesh = NavigationMesh.new()
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.agent_radius = 1
	nav_mesh.agent_height = 3
	nav_mesh.agent_max_slope = 30
	NavigationServer3D.region_set_navigation_mesh(region, nav_mesh)
	NavigationServer3D.region_bake_navigation_mesh(nav_mesh, chunk_mesh)


func try_place_tree(terrain_pos: Vector3) -> Node3D:
	if terrain_pos.y <= TREE_START_HEIGHT:
		return

	

	for pos in tree_locations:
		if pos.distance_to(terrain_pos) < TREE_DISTANCE:
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


func parse_chunk_key(key: String) -> Vector2:
	var arr_vec = key.split(",")
	#print(Vector2(int(arr_vec[0]), int(arr_vec[1])))
	return Vector2(int(arr_vec[0]), int(arr_vec[1]))


func sample_terrain_noise(x: float, z: float) -> float:
	var undulation_noise_sample = (terrain_undulation_noise.get_noise_2d(x, z) + 1.0) / 2.0
	var sample = undulation_noise_sample * TERRAIN_UNDULATION_RADIUS

	var river_noise_sample = river_noise.get_noise_2d(x, z)
	if river_noise_sample > 0:
		sample -= river_noise_sample * RIVER_DEPTH_RADIUS

	var dist_from_bank = 0.7 * RENDER_DISTANCE * RENDER_CHUNK_SIZE - Vector2(x, z).length()
	if dist_from_bank < 0:
		sample += BANK_DEPTH * dist_from_bank / BANK_LENGTH

	return sample

