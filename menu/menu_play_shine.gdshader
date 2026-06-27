shader_type canvas_item;
render_mode blend_mix;

uniform sampler2D play_tex : filter_linear, repeat_disable;
uniform float shine_strength : hint_range(0.0, 1.0) = 0.0;
uniform float shine_time = 0.0;

void fragment() {
	vec4 tex = texture(play_tex, UV);
	vec3 col = tex.rgb;
	float a = tex.a;

	float pulse = 0.55 + 0.45 * sin(shine_time * 5.5);
	vec3 gold = vec3(1.0, 0.78, 0.28);
	col += gold * shine_strength * pulse * 0.42 * a;

	float sweep_coord = UV.x * 0.85 + UV.y * 0.35 + shine_time * 0.45;
	float band = fract(sweep_coord);
	band = smoothstep(0.0, 0.06, band) * (1.0 - smoothstep(0.06, 0.14, band));
	col += vec3(1.0, 0.95, 0.72) * band * shine_strength * 1.1 * a;

	float sparkle = sin(UV.x * 48.0 + shine_time * 9.0) * sin(UV.y * 36.0 - shine_time * 7.0);
	sparkle = smoothstep(0.94, 1.0, sparkle) * shine_strength * a;
	col += vec3(1.0, 0.92, 0.65) * sparkle * 0.55;

	COLOR = vec4(col, a);
}
