shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float time_scale = 1.0;

void fragment() {
	vec2 uv = UV;
	vec2 c = uv - 0.5;
	float dist = length(c);
	float vig = smoothstep(0.25, 0.92, dist);
	float flicker = 0.92 + 0.08 * sin(TIME * 7.0 * time_scale + dist * 12.0);
	vec3 tint = vec3(0.12, 0.04, 0.02);
	float alpha = vig * strength * flicker;
	COLOR = vec4(tint, alpha);
}
