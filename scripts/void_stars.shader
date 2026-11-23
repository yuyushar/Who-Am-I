shader_type canvas_item;

uniform vec4 bg_color : hint_color = vec4(0.008, 0.008, 0.018, 1.0);
uniform vec4 star_color_1 : hint_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 star_color_2 : hint_color = vec4(0.65, 0.85, 1.0, 1.0);
uniform vec4 star_color_3 : hint_color = vec4(1.0, 0.92, 0.70, 1.0);
uniform float speed : hint_range(0.1, 5.0) = 1.0;
uniform float density : hint_range(10.0, 100.0) = 42.0;

// Fungsi pseudo-random hash sederhana & sangat ringan
float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV * vec2(density, density * 0.5625);
	vec2 id = floor(uv);
	vec2 gv = fract(uv) - 0.5;

	vec3 col = bg_color.rgb;

	// Iterasi 3x3 sel sekitar agar bintang yang berada di pinggir sel tidak terpotong
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 offset = vec2(float(x), float(y));
			vec2 cell_id = id + offset;
			float n = hash(cell_id);

			// Kemunculan bintang hanya pada sebagian sel (~20% sel)
			if (n > 0.80) {
				// Posisi acak bintang di dalam sel
				vec2 star_pos = offset + (vec2(fract(n * 23.45), fract(n * 67.89)) - 0.5) * 0.75;
				float d = length(gv - star_pos);

				// Ukuran bintang bervariasi
				float star_size = fract(n * 345.67) * 0.04 + 0.015;
				
				// Animasi kelap-kelip bernyawa (nyala redup bervariasi per bintang)
				float twinkle_spd = (fract(n * 89.12) * 2.5 + 1.2) * speed;
				float phase = fract(n * 123.45) * 6.28318;
				float twinkle = sin(TIME * twinkle_spd + phase) * 0.5 + 0.5;
				twinkle = pow(twinkle, 1.8); // Kontras nyala terang vs redup

				// Efek pendaran cahaya (core + outer glow)
				float glow = smoothstep(star_size * 2.5, 0.0, d) * 0.35;
				float core = smoothstep(star_size, 0.0, d);
				float brightness = (core + glow) * twinkle;

				// Variasi warna bintang (putih, biru langit/cyan, keemasan)
				float color_rand = fract(n * 456.78);
				vec3 c_star = star_color_1.rgb;
				if (color_rand < 0.35) {
					c_star = star_color_2.rgb;
				} else if (color_rand < 0.65) {
					c_star = star_color_3.rgb;
				}

				col += c_star * brightness;
			}
		}
	}

	COLOR = vec4(col, 1.0);
}

