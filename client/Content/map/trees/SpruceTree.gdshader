shader_type spatial;


uniform float speed : hint_range(0.0, 10.0) = 0.5; // Speed of the wind.
uniform float intensity : hint_range(0.0, 10.0) = 0.5; // Intensity or strength of the wind.
uniform float scale : hint_range(0.0, 10.0) = 0.5; // Scale to control which vertices are affected more.
uniform vec4 tint_color = vec4(0.0, 0.2, 0.05, 0);

void vertex() {
    float sway = sin(TIME * speed + VERTEX.x * scale) * intensity;
    VERTEX.z += sway;

}

void fragment() {
    ALBEDO = tint_color.rgb;
}
