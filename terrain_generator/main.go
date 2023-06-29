package main

import (
	"math"
)

const (
	RENDER_DISTANCE      = 10.0
	RENDER_CHUNK_SIZE    = 50.0
	RENDER_CHUNK_DENSITY = 8.0
	RENDER_VERT_STEP     = RENDER_CHUNK_SIZE / RENDER_CHUNK_DENSITY
	RENDER_UV_STEP       = 1.0 / RENDER_CHUNK_DENSITY

	TERRAIN_AMPLITUDE = 20.0
	RIVER_AMPLITUDE   = 12.0
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
	terrain *FractalFBMNoise
	river   *FractalFBMNoise
}

func (tg TerrainGenerator) Sample(x, z float64) float64 {
	raw := tg.sampleRaw(x, z)

	for _, area := range flatAreas {
		distanceToCenter := area.center.DistanceToV2(Vector2{x, z})
		if distanceToCenter >= area.radius {
			continue
		}

		normalizedDist := distanceToCenter / area.radius
		smoothedDist := customSmoothstep(normalizedDist, area.smoothness)
		return lerp(area.height, raw, smoothedDist)
	}

	return raw
}

func (tg TerrainGenerator) sampleRaw(x, z float64) float64 {
	terrainSample := TERRAIN_AMPLITUDE * tg.terrain.Eval2(x, z)

	// riverSample := tg.river.Eval2(x, z)
	// if riverSample > 0 {
	// 	terrainSample -= RIVER_AMPLITUDE * riverSample
	// }

	return terrainSample
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
		terrain: NewDefaultFractalFBMNoise(0),
		river:   NewDefaultFractalFBMNoise(0),
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
}
