shader_type canvas_item;

uniform float brightness : hint_range(-1.0, 1.0) = -0.07;
uniform float contrast : hint_range(0.0, 3.0) = 0.92;
uniform float saturation : hint_range(0.0, 3.0) = 0.85;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	// 1. Turunkan kontras sedikit
	c.rgb = (c.rgb - 0.5) * contrast + 0.5;
	// 2. Buat sedikit lebih gelap (kurangi brightness/kecerahan)
	c.rgb += brightness;
	// 3. Turunkan saturasi sedikit agar visual latar lebih adem dan tidak menyilaukan
	float gray = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(vec3(gray), c.rgb, saturation);
	COLOR = c;
}

