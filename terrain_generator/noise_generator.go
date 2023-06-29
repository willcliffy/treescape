package main

import "github.com/ojrac/opensimplex-go"

type FractalFBMNoise struct {
	noise      opensimplex.Noise
	frequency  float64
	octaves    int
	lacunarity float64
	gain       float64
}

func NewDefaultFractalFBMNoise(seed int64) *FractalFBMNoise {
	return &FractalFBMNoise{
		noise:      opensimplex.New(seed),
		frequency:  0.01,
		octaves:    5,
		lacunarity: 2.0,
		gain:       0.5,
	}
}

func (fbm FractalFBMNoise) Eval2(x, y float64) float64 {
	amplitude := 1.0
	total := 0.0
	maxAmplitude := 0.0

	currentFrequency := fbm.frequency

	for i := 0; i < fbm.octaves; i++ {
		total += fbm.noise.Eval2(x*currentFrequency, y*currentFrequency) * amplitude
		currentFrequency *= fbm.lacunarity
		maxAmplitude += amplitude
		amplitude *= fbm.gain
	}

	// Normalization
	return total / maxAmplitude
}
