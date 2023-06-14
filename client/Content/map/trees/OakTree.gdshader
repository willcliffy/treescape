shader_type spatial;
render_mode diffuse_toon, specular_toon;

uniform float speed : hint_range(0.0, 10.0) = 0.5; // Speed of the wind.
uniform float intensity : hint_range(0.0, 10.0) = 0.5; // Intensity or strength of the wind.
uniform float scale : hint_range(0.0, 10.0) = 0.5; // Scale to control which vertices are affected more.
uniform vec4 tint_color = vec4(0.2, 0.7, 0.1, 0);

void vertex() {
    float sway = sin(TIME * speed + VERTEX.x * scale) * intensity;
    VERTEX.z += sway;
	VERTEX.x += sway;
}

void fragment() {
    ALBEDO = tint_color.rgb;
}
