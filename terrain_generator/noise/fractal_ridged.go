package noise

import (
	"math"

	"github.com/ojrac/opensimplex-go"
)

type FractalRidgedNoise struct {
	noise      opensimplex.Noise
	frequency  float64
	octaves    int
	lacunarity float64
	gain       float64
}

func NewDefaultFractalRidgedNoise(seed int64) *FractalRidgedNoise {
	return &FractalRidgedNoise{
		noise:      opensimplex.New(seed),
		frequency:  0.002,
		octaves:    1,
		lacunarity: 1,
		gain:       1,
	}
}

func (frn FractalRidgedNoise) Eval2(x, y float64) float64 {
	amplitude := 1.0
	total := 0.0
	maxAmplitude := 0.0

	currentFrequency := frn.frequency

	for i := 0; i < frn.octaves; i++ {
		n := frn.noise.Eval2(x*currentFrequency, y*currentFrequency)
		n = 1.0 - math.Abs(n) // Invert and scale the absolute value of the noise
		total += n * amplitude

		currentFrequency *= frn.lacunarity
		maxAmplitude += amplitude
		amplitude *= frn.gain
	}

	// Normalization
	return total / maxAmplitude
}
