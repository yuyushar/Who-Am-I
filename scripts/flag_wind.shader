shader_type canvas_item;

uniform float speed : hint_range(0.5, 10.0) = 2.8;
uniform float amplitude : hint_range(0.0, 15.0) = 2.5;
uniform float wave_length : hint_range(0.01, 0.5) = 0.04;

void vertex() {
	// Hanya meliukkan bagian kain bendera, tiang dan batu dasar tetap kokoh
	if (VERTEX.y > 25.0 && VERTEX.x > 10.0 && VERTEX.x < 75.0) {
		float progress = clamp((VERTEX.y - 25.0) / 130.0, 0.0, 1.0);
		VERTEX.x += sin(TIME * speed + VERTEX.y * wave_length) * amplitude * progress;
	}
}
