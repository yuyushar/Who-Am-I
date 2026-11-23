shader_type canvas_item;

uniform float softness : hint_range(0.01, 0.5) = 0.18;
uniform vec4 flash_color : hint_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec2 center = vec2(0.5, 0.5);
	float dist = distance(UV, center);
	// Lingkaran sempurna dengan pendaran cahaya radial halus (soft edge radial glow)
	float alpha = 1.0 - smoothstep(0.5 - softness, 0.5, dist);
	COLOR = vec4(flash_color.rgb, alpha * flash_color.a * COLOR.a);
}
