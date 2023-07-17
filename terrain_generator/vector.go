package main

import "math"

type Vector3 struct {
	X float64 `json:"x"`
	Y float64 `json:"y"`
	Z float64 `json:"z"`
}

// Sub subtracts two vectors.
func (v Vector3) Sub(u Vector3) Vector3 {
	return Vector3{
		X: v.X - u.X,
		Y: v.Y - u.Y,
		Z: v.Z - u.Z,
	}
}

// Add adds two vectors.
func (v Vector3) Add(u Vector3) Vector3 {
	return Vector3{
		X: v.X + u.X,
		Y: v.Y + u.Y,
		Z: v.Z + u.Z,
	}
}

// Dot returns the dot product of two vectors.
func (v Vector3) Dot(u Vector3) float64 {
	return v.X*u.X + v.Y*u.Y + v.Z*u.Z
}

// Cross returns the cross product of two vectors.
func (v Vector3) Cross(u Vector3) Vector3 {
	return Vector3{
		X: v.Y*u.Z - v.Z*u.Y,
		Y: v.Z*u.X - v.X*u.Z,
		Z: v.X*u.Y - v.Y*u.X,
	}
}

// Normalize normalizes the vector.
func (v Vector3) Normalize() Vector3 {
	mag := math.Sqrt(v.X*v.X + v.Y*v.Y + v.Z*v.Z)
	return Vector3{
		X: v.X / mag,
		Y: v.Y / mag,
		Z: v.Z / mag,
	}
}
