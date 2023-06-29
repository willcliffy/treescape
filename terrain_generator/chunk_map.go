package main

import (
	"encoding/json"
	"os"
)

type ChunkMap map[string]MeshArrays

type MeshArraysProperties struct {
	HasWater bool `json:"has_water"`
}

type MeshArrays struct {
	Vertices   []Vector3            `json:"vertices"`
	Normals    []Vector3            `json:"normals"`
	UVs        []Vector2i           `json:"uvs"`
	Indices    []int                `json:"indices"`
	Properties MeshArraysProperties `json:"properties"`
}

func BuildMeshArrays(position Vector2, tg TerrainGenerator) MeshArrays {
	var arr MeshArrays
	var hasWater bool
	for x := 0.0; x <= RENDER_CHUNK_DENSITY; x++ {
		for z := 0.0; z <= RENDER_CHUNK_DENSITY; z++ {
			vert := Vector3{position.X + x*RENDER_VERT_STEP, 0, position.Z + z*RENDER_VERT_STEP}
			uv := Vector2i{int(1.0 - x*RENDER_UV_STEP), int(1.0 - z*RENDER_UV_STEP)}

			y, vertUnderWater := tg.Sample(vert.X, vert.Z)
			vert.Y = y

			if !hasWater && vertUnderWater {
				hasWater = true
			}

			// var top = vert - Vector3(vert.x, sample_terrain_noise(vert.x, vert.z + RENDER_VERT_STEP), vert.z + RENDER_VERT_STEP)
			// var right = vert - Vector3(vert.x + RENDER_VERT_STEP, sample_terrain_noise(vert.x + RENDER_VERT_STEP, vert.z), vert.z)
			// var norm = top.cross(right).normalized()

			topSample, _ := tg.Sample(vert.X, vert.Z+RENDER_VERT_STEP)
			top := vert.Subtract(Vector3{
				vert.X,
				topSample,
				vert.Z + RENDER_VERT_STEP,
			})

			rightSample, _ := tg.Sample(vert.X+RENDER_VERT_STEP, vert.Z)
			right := vert.Subtract(Vector3{
				vert.X + RENDER_VERT_STEP,
				rightSample,
				vert.Z,
			})

			norm := top.Cross(right).Normalize()

			arr.Vertices = append(arr.Vertices, vert)
			arr.Normals = append(arr.Normals, norm)
			arr.UVs = append(arr.UVs, uv)

			if x < RENDER_CHUNK_DENSITY && z < RENDER_CHUNK_DENSITY {
				a := int(z + x*(RENDER_CHUNK_DENSITY+1))
				b := int(a + 1)
				d := int((RENDER_CHUNK_DENSITY+1)*(x+1) + z)
				c := int(d + 1)

				arr.Indices = append(arr.Indices, d, b, a, d, c, b)
			}
		}
	}

	arr.Properties.HasWater = hasWater

	return arr
}

func (cm ChunkMap) WriteToFile(filename string) error {
	file, err := os.Create(filename)
	if err != nil {
		return err
	}
	defer file.Close()

	encoder := json.NewEncoder(file)
	err = encoder.Encode(cm)
	if err != nil {
		return err
	}

	return nil
}
