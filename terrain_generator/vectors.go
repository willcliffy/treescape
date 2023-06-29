package main

import (
	"fmt"
	"math"
)

type Vector3 struct {
	X, Y, Z float64
}

// func (v Vector3) MarshalJSON() ([]byte, error) {
// 	x := strconv.FormatFloat(v.X, 'f', -1, 64)
// 	y := strconv.FormatFloat(v.Y, 'f', -1, 64)
// 	z := strconv.FormatFloat(v.Z, 'f', -1, 64)
// 	if x == "NaN" || y == "NaN" || z == "NaN" {
// 		fmt.Printf("NaN detected! %v\n", v)
// 	}
// 	return json.Marshal(&struct {
// 		X string `json:"x"`
// 		Y string `json:"y"`
// 		Z string `json:"z"`
// 	}{
// 		X: x,
// 		Y: y,
// 		Z: z,
// 	})
// }

func (v1 Vector3) Subtract(v2 Vector3) Vector3 {
	return Vector3{
		X: v1.X - v2.X,
		Y: v1.Y - v2.Y,
		Z: v1.Z - v2.Z,
	}
}

func (v1 Vector3) Cross(v2 Vector3) Vector3 {
	return Vector3{v1.Y*v2.Z - v1.Z*v2.Y, v1.Z*v2.X - v1.X*v2.Z, v1.X*v2.Y - v1.Y*v2.X}
}

func (v Vector3) Normalize() Vector3 {
	mag := math.Sqrt(v.X*v.X + v.Y*v.Y + v.Z*v.Z)

	// If the magnitude is zero then return the zero vector
	if mag == 0 {
		return Vector3{0, 0, 0}
	}

	return Vector3{v.X / mag, v.Y / mag, v.Z / mag}
}

type Vector2 struct {
	X, Z float64
}

func (v Vector2) ToKey() string {
	return fmt.Sprintf("%f:%f", v.X, v.Z)
}

func (v1 Vector2) Distance(v2 Vector2) float64 {
	dx := v2.X - v1.X
	dz := v2.Z - v1.Z
	return math.Sqrt(dx*dx + dz*dz)
}

func (v1 Vector2) DistanceToV2i(v2 Vector2i) float64 {
	dx := float64(v2.X) - v1.X
	dz := float64(v2.Z) - v1.Z
	return math.Sqrt(dx*dx + dz*dz)
}

type Vector2i struct {
	X, Z int
}

func (v1 Vector2i) Distance(v2 Vector2i) float64 {
	dx := v2.X - v1.X
	dz := v2.Z - v1.Z
	return math.Sqrt(float64(dx*dx + dz*dz))
}

func (v1 Vector2i) DistanceToV2(v2 Vector2) float64 {
	return v2.DistanceToV2i(v1)
}
