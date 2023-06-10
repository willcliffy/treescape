extends Node3D

var terrainWidth = 50
var terrainLength = 50

var blockSize = 1.0
var cubeScene = preload("res://Content/Cube.tscn")
var treeMeshes = [
	preload("res://Content/Trees/OBJ/Low_Poly_Forest_tree01.obj"),
	preload("res://Content/Trees/OBJ/Low_Poly_Forest_tree02.obj"),
	preload("res://Content/Trees/OBJ/Low_Poly_Forest_tree03.obj"),
	preload("res://Content/Trees/OBJ/Low_Poly_Forest_treeBlob01.obj"),
	preload("res://Content/Trees/OBJ/Low_Poly_Forest_treeBlob02.obj"),
	preload("res://Content/Trees/OBJ/Low_Poly_Forest_treeBlob03.obj"),
]

func _ready():
	var terrainNoise = FastNoiseLite.new()
	terrainNoise.frequency = 0.01
	terrainNoise.fractal_octaves = 4
	terrainNoise.fractal_gain = 0.5

	var treeNoise = FastNoiseLite.new()
	treeNoise.seed = randi()
	treeNoise.frequency = 0.005
	treeNoise.fractal_octaves = 4
	treeNoise.fractal_gain = 0.5

	for x in range(terrainWidth):
		for z in range(terrainLength):
			var height = terrainNoise.get_noise_2d(x, z) * 5.0

			var cubeInstance = cubeScene.instantiate()
			cubeInstance.transform.origin = Vector3(x*blockSize, height, z*blockSize)
			add_child(cubeInstance)

			var treeValue = treeNoise.get_noise_2d(x, z)
			if treeValue > 0.5:
				print("tree?")
				var treeMesh = treeMeshes[randi() % treeMeshes.size()]  # Randomly select a tree mesh
				var treeInstance = MeshInstance3D.new()
				treeInstance.mesh = treeMesh
				treeInstance.transform.origin = Vector3(x * blockSize, height + 1, z * blockSize)  # Place the tree slightly above the cube to avoid intersecting with it
				treeInstance.transform.scale = Vector3(0.1, 0.1, 0.1)  # Scale down the tree
				add_child(treeInstance)
