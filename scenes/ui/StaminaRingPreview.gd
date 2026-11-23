tool
extends Control

var anim_timer: float = 0.0

func _process(delta):
	anim_timer += delta
	update()

func _draw():
	var center = rect_size * 0.5
	var radius = 22.0
	var thickness = 4.5
	var point_count = 36
	
	# Bayangan
	draw_circle(center, radius + 2.5, Color(0.0, 0.0, 0.0, 0.5))
	draw_circle(center, radius - 2.5, Color(0.04, 0.06, 0.10, 0.7))
	# Track lingkaran kosong
	draw_arc(center, radius, 0.0, TAU, point_count, Color(0.18, 0.24, 0.32, 0.9), thickness, true)
	
	# Siklus animasi: stamina penuh (hijau di kanan) -> lari (kanan terkuras, menyisakan merah di kiri) -> isi ulang
	var cycle = fmod(anim_timer, 4.0)
	var ratio = 1.0
	if cycle < 2.2:
		# Lari: stamina berkurang dari 1.0 ke 0.15
		var t = cycle / 2.2
		ratio = lerp(1.0, 0.15, t)
	elif cycle < 2.5:
		# Habis sesaat
		ratio = 0.15
	elif cycle < 3.8:
		# Mengisi ulang dari 0.15 ke 1.0
		var t = (cycle - 2.5) / 1.3
		ratio = lerp(0.15, 1.0, t)
	else:
		ratio = 1.0
		
	var col = Color(0.25, 0.92, 0.55, 1.0)
	if ratio < 0.22:
		var blink = sin(anim_timer * 18.0) * 0.2
		col = Color(0.96, 0.26 + blink, 0.22, 1.0) # Merah (di kiri saat kritis)
	elif ratio < 0.50:
		var t = (ratio - 0.22) / 0.28
		col = Color(0.96, lerp(0.35, 0.85, t), 0.22, 1.0) # Oranye ke kuning
	else:
		var t = (ratio - 0.50) / 0.50
		col = Color(lerp(0.96, 0.25, t), lerp(0.85, 0.92, t), lerp(0.25, 0.55, t), 1.0) # Kuning ke hijau
		
	if ratio > 0.02:
		var sweep = TAU * clamp(ratio, 0.0, 1.0)
		var segs = max(3, int(point_count * clamp(ratio, 0.0, 1.0)))
		var pts = PoolVector2Array()
		for i in range(segs + 1):
			# 0% - 50% di KIRI (Merah), 50% - 100% di KANAN (Hijau)
			var a = -PI * 0.5 - (float(i) / float(segs)) * sweep
			pts.append(center + Vector2(cos(a), sin(a)) * radius)
		draw_polyline(pts, col, thickness, true)
		
		draw_circle(pts[0], thickness * 0.48, col)
		draw_circle(pts[pts.size() - 1], thickness * 0.48, col)
