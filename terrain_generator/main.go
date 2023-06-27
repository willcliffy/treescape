package main

import (
	"encoding/json"
	"fmt"
	"math/rand"
	"os"

	"github.com/aquilax/go-perlin"
	"github.com/ojrac/opensimplex-go"
)

type Vector3 struct {
	X, Y, Z float64
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

func main() {
	// Read the configuration
	confData, _ := os.ReadFile("config.json")
	var conf NoiseConfig
	_ = json.Unmarshal([]byte(confData), &conf)

	// Initialize the noises
	simplexNoise := opensimplex.New(conf.Simplex.Seed)
	perlinNoise := perlin.NewPerlinRandSource(2, 2, 2, rand.NewSource(conf.Perlin.Seed))
	worleyNoise := perlin.NewPerlinRandSource(2, 2, 2, rand.NewSource(conf.Worley.Seed)) // This is a placeholder for Worley noise

	// Generate the terrain
	var terrain []Vector3
	for i := 0.0; i < conf.TerrainSize; i++ {
		for j := 0.0; j < conf.TerrainSize; j++ {
			simplex := conf.Simplex.Amplitude * simplexNoise.Eval2(i*conf.Simplex.Frequency, j*conf.Simplex.Frequency)
			worley := conf.Worley.Amplitude * worleyNoise.Noise2D(i*conf.Worley.Frequency, j*conf.Worley.Frequency)
			perlin := conf.Perlin.Amplitude * perlinNoise.Noise2D(i*conf.Perlin.Frequency, j*conf.Perlin.Frequency)

			z := simplex + worley + perlin
			terrain = append(terrain, Vector3{i, j, z})
		}
	}

	// Print the terrain
	terrainData, _ := json.MarshalIndent(terrain, "", "  ")
	fmt.Println(string(terrainData))
	_ = os.WriteFile("terrain.json", terrainData, 0644)
}
