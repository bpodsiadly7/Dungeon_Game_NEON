shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float shimmer_pos : hint_range(0.0, 1.5) = 0.0;
uniform float glow_strength : hint_range(0.0, 2.5) = 1.0;
uniform float softness : hint_range(0.1, 3.0) = 1.35;

void fragment() {
	vec2 uv = UV;
	vec2 centered = uv - vec2(0.5);

	float vert = 1.0 - smoothstep(0.0, 0.52 * softness, abs(centered.y));
	float horiz = 1.0 - smoothstep(0.0, 0.42 * softness, abs(centered.x));
	float mask = pow(vert * horiz, 1.15);

	vec3 core = base_color.rgb * mask * glow_strength;
	float shine_band = smoothstep(0.22, 0.0, abs(uv.x - shimmer_pos));
	float shine_vert = smoothstep(0.45, 0.0, abs(uv.y - 0.5));
	float shine = shine_band * shine_vert * mask;
	vec3 col = core + vec3(1.0) * shine * 0.55;

	float alpha = mask * base_color.a * glow_strength;
	COLOR = vec4(col, alpha);
}
