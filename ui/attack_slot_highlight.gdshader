shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.88, 0.94, 1.0, 1.0);
uniform float strength : hint_range(0.0, 1.5) = 0.0;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float d = length(uv);
	// Jasna obwódka, środek prawie przezroczysty — bez żółtej „plamy”.
	float rim = smoothstep(0.58, 1.0, d);
	float inner = 1.0 - smoothstep(0.0, 0.42, d);
	float alpha = (rim * 0.9 + inner * 0.08) * strength * glow_color.a;
	COLOR = vec4(glow_color.rgb, alpha);
}
