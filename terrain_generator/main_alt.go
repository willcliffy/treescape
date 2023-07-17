package main

import (
	"encoding/json"
	"fmt"
	"math/rand"
	"os"

	"github.com/aquilax/go-perlin"
	"github.com/ojrac/opensimplex-go"
)

const (
	RENDER_CHUNK_SIZE    = 3.0
	RENDER_CHUNK_DENSITY = 1.0
	RENDER_VERT_STEP     = RENDER_CHUNK_SIZE / RENDER_CHUNK_DENSITY
	RENDER_UV_STEP       = 1.0 / RENDER_CHUNK_DENSITY
)

type Chunk struct {
	ChunkPosition Vector3   `json:"chunk_position"`
	Vertices      []Vector3 `json:"vertices"`
	Normals       []Vector3 `json:"normals"`
	UVs           []Vector3 `json:"uvs"`
}

type NoiseConfig struct {
	TerrainSize float64 `json:"terrainSize"`
	Simplex     struct {
		Frequency float64
		Amplitude float64
		Seed      int64
	} `json:"simplexNoise"`
	Worley struct {
		Frequency float64
		Amplitude float64
		Seed      int64
	} `json:"worleyNoise"`
	Perlin struct {
		Frequency float64
		Amplitude float64
		Seed      int64
	} `json:"perlinNoise"`
}

type TerrainGenerator struct {
	config  *NoiseConfig
	simplex opensimplex.Noise
	perlin  *perlin.Perlin
	worley  *perlin.Perlin
}

func main() {
	// Read the configuration
	confData, _ := os.ReadFile("terrain_config.json")
	var conf NoiseConfig
	err := json.Unmarshal([]byte(confData), &conf)
	if err != nil {
		panic(err)
	}

	gen := TerrainGenerator{
		config:  &conf,
		simplex: opensimplex.New(conf.Simplex.Seed),
		perlin:  perlin.NewPerlinRandSource(2, 2, 2, rand.NewSource(conf.Perlin.Seed)),
		worley:  perlin.NewPerlinRandSource(2, 2, 2, rand.NewSource(conf.Worley.Seed)),
	}

	// Generate the terrain
	var chunks []Chunk
	for ix := 0.0; ix < conf.TerrainSize; ix++ {
		for iz := 0.0; iz < conf.TerrainSize; iz++ {
			chunks = append(chunks, gen.createChunk(Vector3{X: ix, Z: iz}))
		}
	}

	// Print the terrain
	terrainData, err := json.MarshalIndent(chunks, "", "  ")
	if err != nil {
		panic(err)
	}
	//fmt.Println(string(terrainData))
	_ = os.WriteFile("../client/terrain.json", terrainData, 0644)
}

func (t TerrainGenerator) createChunk(position Vector3) Chunk {
	var verts []Vector3
	var norms []Vector3
	var uvs []Vector3

	for x := 0.0; x < RENDER_CHUNK_DENSITY+1; x++ {
		for z := 0.0; z < RENDER_CHUNK_DENSITY+1; z++ {
			// Calculate vert
			fmt.Printf("%v, %v, %v\n", position, x, z)
			vert := Vector3{
				X: position.X + x*RENDER_VERT_STEP,
				Y: t.sampleTerrainNoise(x, z),
				Z: position.Z + z*RENDER_VERT_STEP,
			}
			fmt.Printf("\t%v\n", vert)
			verts = append(verts, vert)

			// Calculate norm
			nextX := vert.X + RENDER_VERT_STEP
			nextZ := vert.Z + RENDER_VERT_STEP
			top := vert.Sub(Vector3{vert.X, t.sampleTerrainNoise(vert.X, nextZ), nextZ})
			right := vert.Sub(Vector3{nextX, t.sampleTerrainNoise(nextX, vert.Z), vert.Z})
			norm := top.Cross(right).Normalize()
			norms = append(norms, norm)

			// Calculate uvs
			uv := Vector3{X: 1.0 - x*RENDER_UV_STEP, Z: 1.0 - z*RENDER_UV_STEP}
			uvs = append(uvs, uv)
		}
	}

	return Chunk{
		ChunkPosition: position,
		Vertices:      verts,
		Normals:       norms,
		UVs:           uvs,
	}
}

func (t TerrainGenerator) sampleTerrainNoise(x, z float64) float64 {
	simplex := t.config.Simplex.Amplitude * t.simplex.Eval2(x*t.config.Simplex.Frequency, z*t.config.Simplex.Frequency)
	worley := t.config.Worley.Amplitude * t.worley.Noise2D(x*t.config.Worley.Frequency, z*t.config.Worley.Frequency)
	perlin := t.config.Perlin.Amplitude * t.perlin.Noise2D(x*t.config.Perlin.Frequency, z*t.config.Perlin.Frequency)

	return simplex + worley + perlin
}
