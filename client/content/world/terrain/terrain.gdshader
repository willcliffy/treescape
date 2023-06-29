shader_type spatial;
render_mode diffuse_toon, specular_toon;

uniform vec4 color_low: source_color = vec4(0.396, 0.263, 0.129, 1.0); // Brown
uniform vec4 color_high: source_color = vec4(0.184, 0.63, 0.176, 1.0); // Green

// Uniforms to adjust the range of height over which the gradient occurs
uniform float height_low: hint_range(-10.0, 10.0) = -10.0;
uniform float height_high: hint_range(-10.0, 10.0) = 10.0;


varying vec3 world_position;
void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


void fragment() {
    float height = (world_position.y - height_low) / (height_high - height_low);
    height = clamp(height, 0.0, 1.0); // Ensure height is in the range 0.0 to 1.0
    vec4 final_color = mix(color_low, color_high, height);
    ALBEDO = final_color.rgb;
}
