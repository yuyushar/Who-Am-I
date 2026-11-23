tool
extends Control

# Ikon siluet mouse dengan tombol KLIK KIRI di-highlight putih cerah
export(Color) var mouse_body_color: Color = Color(0.08, 0.11, 0.16, 0.95)
export(Color) var mouse_border_color: Color = Color(0.42, 0.56, 0.74, 0.95)
export(Color) var left_click_color: Color = Color(1.0, 1.0, 1.0, 1.0)
export(Color) var right_click_color: Color = Color(0.14, 0.18, 0.25, 0.90)

func _ready():
	rect_min_size = Vector2(26, 34)

func _draw():
	var w = rect_size.x
	var h = rect_size.y
	if w <= 0 or h <= 0:
		w = 26.0
		h = 34.0
		
	var padding = 2.0
	var rw = w - padding * 2.0
	var rh = h - padding * 2.0
	var ox = padding
	var oy = padding
	
	var corner_r = rw * 0.40
	var btn_h = rh * 0.46
	var mid_x = ox + rw * 0.5
	
	# 1. Bayangan halus mouse di bawah
	draw_rect(Rect2(ox - 1, oy - 1, rw + 2, rh + 2), Color(0.0, 0.0, 0.0, 0.35))
	
	# 2. Bodi bagian bawah (Palm Rest)
	var palm_pts = PoolVector2Array([
		Vector2(ox, oy + btn_h),
		Vector2(ox + rw, oy + btn_h),
		Vector2(ox + rw, oy + rh - corner_r),
		Vector2(ox + rw - corner_r * 0.3, oy + rh - corner_r * 0.3),
		Vector2(ox + rw - corner_r, oy + rh),
		Vector2(ox + corner_r, oy + rh),
		Vector2(ox + corner_r * 0.3, oy + rh - corner_r * 0.3),
		Vector2(ox, oy + rh - corner_r),
		Vector2(ox, oy + btn_h)
	])
	draw_colored_polygon(palm_pts, mouse_body_color)
	
	# 3. Tombol KLIK KIRI (DISOROT PUTIH TERANG SESUAI REQUEST)
	var left_btn_pts = PoolVector2Array([
		Vector2(ox, oy + corner_r),
		Vector2(ox + corner_r * 0.3, oy + corner_r * 0.3),
		Vector2(ox + corner_r, oy),
		Vector2(mid_x - 1.0, oy),
		Vector2(mid_x - 1.0, oy + btn_h),
		Vector2(ox, oy + btn_h)
	])
	draw_colored_polygon(left_btn_pts, left_click_color)
	
	# 4. Tombol KLIK KANAN (Gelap / Standby)
	var right_btn_pts = PoolVector2Array([
		Vector2(mid_x + 1.0, oy),
		Vector2(ox + rw - corner_r, oy),
		Vector2(ox + rw - corner_r * 0.3, oy + corner_r * 0.3),
		Vector2(ox + rw, oy + corner_r),
		Vector2(ox + rw, oy + btn_h),
		Vector2(mid_x + 1.0, oy + btn_h)
	])
	draw_colored_polygon(right_btn_pts, right_click_color)
	
	# 5. Garis luar bodi mouse (Border polyline)
	var outer_outline = PoolVector2Array([
		Vector2(ox, oy + corner_r),
		Vector2(ox + corner_r * 0.3, oy + corner_r * 0.3),
		Vector2(ox + corner_r, oy),
		Vector2(ox + rw - corner_r, oy),
		Vector2(ox + rw - corner_r * 0.3, oy + corner_r * 0.3),
		Vector2(ox + rw, oy + corner_r),
		Vector2(ox + rw, oy + rh - corner_r),
		Vector2(ox + rw - corner_r * 0.3, oy + rh - corner_r * 0.3),
		Vector2(ox + rw - corner_r, oy + rh),
		Vector2(ox + corner_r, oy + rh),
		Vector2(ox + corner_r * 0.3, oy + rh - corner_r * 0.3),
		Vector2(ox, oy + rh - corner_r),
		Vector2(ox, oy + corner_r)
	])
	draw_polyline(outer_outline, mouse_border_color, 1.6, true)
	
	# 6. Garis pemisah horizontal (antara tombol dan bodi bawah)
	draw_line(Vector2(ox + 1.0, oy + btn_h), Vector2(ox + rw - 1.0, oy + btn_h), mouse_border_color, 1.5, true)
	
	# 7. Garis pemisah vertikal tengah (antara tombol kiri dan kanan)
	draw_line(Vector2(mid_x, oy + 2.0), Vector2(mid_x, oy + btn_h), mouse_border_color, 1.5, true)
	
	# 8. Scroll Wheel kecil di tengah
	var wheel_w = 3.5
	var wheel_h = 6.5
	var wheel_rect = Rect2(mid_x - wheel_w * 0.5, oy + btn_h * 0.28, wheel_w, wheel_h)
	draw_rect(wheel_rect, Color(0.04, 0.06, 0.08, 1.0))
	draw_rect(wheel_rect, mouse_border_color, false, 1.0)
