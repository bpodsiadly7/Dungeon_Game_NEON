shader_type spatial;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform sampler2D normal_texture : hint_normal;
uniform float normal_scale = -10.0;
uniform vec4 albedo_tint : source_color = vec4(1.0);

void fragment() {
	vec4 albedo = texture(albedo_texture, UV);
	vec3 c = albedo.rgb;
	float br = dot(c, vec3(0.299, 0.587, 0.114));
	float sat = max(max(abs(c.r - c.g), abs(c.g - c.b)), abs(c.r - c.b));
	bool is_pip = c.r > 0.45 && c.g < 0.38 && c.b < 0.38 && (c.r - c.g) > 0.12;
	bool is_wire = br > 0.20 && br < 0.82 && sat < 0.20 && !is_pip;
	// Szare linie siatki UV na arkuszu tekstury
	is_wire = is_wire || (!is_pip && br > 0.12 && br < 0.92 && sat < 0.12);

	if (is_wire) {
		albedo.rgb = vec3(0.11, 0.10, 0.09);
	}

	ALBEDO = albedo.rgb * albedo_tint.rgb;
	NORMAL_MAP = texture(normal_texture, UV).rgb;
	NORMAL_MAP_DEPTH = normal_scale;
}
