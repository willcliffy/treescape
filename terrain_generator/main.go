package main

import (
	"fmt"
	"math"

	"github.com/willcliffy/treescape/terrain/noise"
)

const (
	RENDER_DISTANCE      = 10.0
	RENDER_CHUNK_SIZE    = 50.0
	RENDER_CHUNK_DENSITY = 5.0
	RENDER_VERT_STEP     = RENDER_CHUNK_SIZE / RENDER_CHUNK_DENSITY
	RENDER_UV_STEP       = 1.0 / RENDER_CHUNK_DENSITY

	TERRAIN_AMPLITUDE    = 15.0
	RIVER_AMPLITUDE      = 10.0
	RIVER_THRESHOLD      = 0.5
	RIVER_BANK_THRESHOLD = 0.1
)

var flatAreas = []FlatArea{
	{
		center:     Vector2i{0, 0},
		radius:     30.0,
		smoothness: 0.8,
		height:     0.0,
	},
}

type TerrainGenerator struct {
	terrain *noise.FractalFBMNoise
	river   *noise.FractalRidgedNoise
}

func (tg TerrainGenerator) Sample(x, z float64) (float64, bool) {
	raw, hasWater := tg.sampleRaw(x, z)

	for _, area := range flatAreas {
		distanceToCenter := area.center.DistanceToV2(Vector2{x, z})
		if distanceToCenter >= area.radius {
			continue
		}

		normalizedDist := distanceToCenter / area.radius
		smoothedDist := customSmoothstep(normalizedDist, area.smoothness)
		return lerp(area.height, raw, smoothedDist), hasWater
	}

	return raw, hasWater
}

var samples []float64

func (tg TerrainGenerator) sampleRaw(x, z float64) (float64, bool) {
	hasWater := false
	terrainSample := TERRAIN_AMPLITUDE * tg.terrain.Eval2(x, z)

	riverSample := (tg.river.Eval2(x, z) - 0.5) * 2.0
	if riverSample > RIVER_THRESHOLD {
		hasWater = true
		terrainSample = lerp(-RIVER_AMPLITUDE, terrainSample, 0.25)
	} else if riverSample > RIVER_BANK_THRESHOLD {
		closenessToRiver := (riverSample - RIVER_BANK_THRESHOLD) / (RIVER_THRESHOLD - RIVER_BANK_THRESHOLD)
		if terrainSample < 0 {
			terrainSample = lerp(terrainSample, -1.5*terrainSample, closenessToRiver)
		} else {
			terrainSample = lerp(terrainSample, 1.5*terrainSample, closenessToRiver)
		}
	}

	samples = append(samples, riverSample)

	return terrainSample, hasWater
}

func customSmoothstep(x, smoothness float64) float64 {
	mappedSmoothness := 1 / (1 - smoothness + 0.00001)
	clampedX := math.Max(0.0, math.Min(x, 1.0))
	t := math.Pow(clampedX, mappedSmoothness)
	return t * t * (3.0 - 2.0*t)
}

func lerp(a, b, t float64) float64 {
	return a + (b-a)*t
}

func main() {
	// Initialize noise functions
	tg := TerrainGenerator{
		terrain: noise.NewDefaultFractalFBMNoise(0),
		river:   noise.NewDefaultFractalRidgedNoise(0),
	}

	chunkMap := make(ChunkMap)

	startingChunkCoordinate := -RENDER_DISTANCE * RENDER_CHUNK_SIZE
	endingChunkCoordinate := (RENDER_DISTANCE + 1) * RENDER_CHUNK_SIZE

	for ix := startingChunkCoordinate; ix < endingChunkCoordinate; ix += RENDER_CHUNK_SIZE {
		for iz := startingChunkCoordinate; iz < endingChunkCoordinate; iz += RENDER_CHUNK_SIZE {
			position := Vector2{ix, iz}
			meshArrays := BuildMeshArrays(position, tg)
			chunkMap[position.ToKey()] = meshArrays
		}
	}

	err := chunkMap.WriteToFile("../client/output.json")
	if err != nil {
		panic(err)
	}

	tot := 0.0
	max := -100.0
	min := 100.0

	for _, x := range samples {
		tot += x
		if x > max {
			max = x
		}
		if x < min {
			min = x
		}
	}

	fmt.Printf("%v avg, %v max, %v min\n", tot/float64(len(samples)), max, min)
}
