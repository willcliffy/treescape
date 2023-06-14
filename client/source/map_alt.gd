class_name TerrainGenerator
extends Node

@onready var terrain_shader = preload("res://content/terrain.gdshader")

@onready var nav_map = get_parent().get_world_3d().get_navigation_map()

const GREEN = Color("#556B2F")
const BROWN = Color("#3D1F00")

## Noise
var terrain_undulation_noise: FastNoiseLite
const terrain_undulation_radius = 10.0

var terrain_river_noise: FastNoiseLite
const river_depth = 5.0

const bank_depth = 32.0
const bank_length = 72.0

## Rendering
var _render_distance: int
var _chunk_size: int
var _chunk_density: int


var _target: Node3D
var _loaded_chunks: Dictionary


## Terrain generation
var _needs_collider: bool

var terrain_material


func _ready():
	NavigationServer3D.map_set_edge_connection_margin(nav_map, 5)
	
	_target = get_parent().get_node("Player")
	_loaded_chunks = {}

	## render options
	_render_distance = 8
	_chunk_size = 32
	_chunk_density = 4

	## terrain generation options
	_needs_collider = true

	terrain_undulation_noise = FastNoiseLite.new()
	terrain_undulation_noise.fractal_octaves = 2
	terrain_undulation_noise.fractal_gain = 0.01
	terrain_undulation_noise.frequency = 0.01
	
	terrain_river_noise = FastNoiseLite.new()
	terrain_river_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	terrain_river_noise.fractal_octaves = 1
	terrain_river_noise.fractal_gain = 1
	terrain_river_noise.frequency = 0.02


	terrain_material = ShaderMaterial.new()
	terrain_material.shader = terrain_shader
	terrain_material.set_shader_parameter("height_low", -2.0)
	terrain_material.set_shader_parameter("height_high", 5.0)
	
	terrain_material.set_shader_parameter("color_low", BROWN)
	terrain_material.set_shader_parameter("color_high", GREEN)
	
	generate.call_deferred()

### Terrain generation ###

func generate() -> void:
	if not _target == null:
		var position = _target.transform.origin
		if position.x < 0: position.x -= _chunk_size
		if position.z < 0: position.z -= _chunk_size
		var chunk_x: int = int(position.x / _chunk_size)
		var chunk_z: int = int(position.z / _chunk_size)

		for ix in range(chunk_x - _render_distance, chunk_x + _render_distance + 1):
			for iz in range(chunk_z - _render_distance, chunk_z + _render_distance + 1):
				var chunk_position = Vector2(ix, iz)
				if chunk_position.distance_to(Vector2(chunk_x, chunk_z)) > _render_distance: 
					continue
				if _loaded_chunks.has(make_chunk_key(chunk_position)): 
					continue
				add_chunk(Vector2(ix, iz))

		for key in _loaded_chunks:
			var chunk_pos = parse_chunk_key(key)
			if chunk_pos.distance_to(Vector2(chunk_x, chunk_z)) > _render_distance:
				remove_chunk(key)


func add_chunk(chunk_position: Vector2) -> void:
	var position = Vector3(chunk_position.x * _chunk_size, 0, chunk_position.y * _chunk_size)

	var arr = []
	arr.resize(Mesh.ARRAY_MAX)

	var verts = PackedVector3Array()
	var norms = PackedVector3Array()
	var uvs   = PackedVector2Array()
	var inds  = PackedInt32Array()

	var vert_step = float(_chunk_size) / _chunk_density
	var uv_step   = 1.0 / _chunk_density 

	for x in _chunk_density + 1:
		for z in _chunk_density + 1:
			var vert = Vector3(position.x + x * vert_step, 0.0, position.z + z * vert_step)
			var uv = Vector2(1.0 - x * uv_step, 1.0 - z * uv_step)
			
			vert.y = sample_terrain_noise(vert.x, vert.z)

			var top = vert - Vector3(vert.x, sample_terrain_noise(vert.x, vert.z + vert_step), vert.z + vert_step)
			var right = vert - Vector3(vert.x + vert_step, sample_terrain_noise(vert.x + vert_step, vert.z), vert.z)
			var norm = top.cross(right).normalized()

			verts.push_back(vert)
			norms.push_back(norm)
			uvs.push_back(uv)

			# Make & index a clockwise face from verts a, b, c, d
			if x < _chunk_density and z < _chunk_density:
				var a = z + x * (_chunk_density + 1)
				var b = a + 1
				var d = (_chunk_density + 1) * (x + 1) + z
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

	var chunk_mesh = MeshInstance3D.new()
	chunk_mesh.mesh = ArrayMesh.new()
	chunk_mesh.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	chunk_mesh.mesh.surface_set_material(0, terrain_material)

	_loaded_chunks[make_chunk_key(chunk_position)] = chunk_mesh

	if not _needs_collider:
		add_child.call_deferred(chunk_mesh)
		return

	chunk_mesh.create_trimesh_collision()
	$Terrain.add_child(chunk_mesh)

	# TODO - keep track of and clean up nav regions
	var region: RID = NavigationServer3D.region_create()
	NavigationServer3D.region_set_transform(region, Transform3D())
	NavigationServer3D.region_set_map(region, nav_map)
	var nav_mesh: NavigationMesh = NavigationMesh.new()
	NavigationServer3D.region_set_navigation_mesh(region, nav_mesh)
	NavigationServer3D.region_bake_navigation_mesh(nav_mesh, chunk_mesh)


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


func sample_terrain_noise(x: int, z: int) -> float:
	var undulation_noise_sample = terrain_undulation_noise.get_noise_2d(x, z)

	var sample = undulation_noise_sample * terrain_undulation_radius

	var river_noise_sample = terrain_river_noise.get_noise_2d(x, z)
	if river_noise_sample > 0.6:
		var river_gradient = (river_noise_sample + 1.0) / 2.0
		sample -= (river_gradient - 0.6) * river_depth

	var dist_from_bank = 0.7 * _render_distance * _chunk_size - Vector2(x, z).length()
	if dist_from_bank < 0:
		sample += bank_depth * dist_from_bank / bank_length

	return sample

