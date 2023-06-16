shader_type sky;

uniform vec4 sky_color: source_color;

void sky() {
	COLOR = sky_color.rgb;
}
