extends KinematicBody2D

# ==========================================
# KONFIGURASI KECEPATAN & STAMINA MC
# (Bisa diatur langsung di Inspector Godot atau diedit di sini)
# ==========================================
export(float) var walk_speed = 240.0        # Kecepatan jalan santai MC
export(float) var sprint_speed = 360.0      # Kecepatan lari MC saat menekan Shift
export(float) var max_stamina = 100.0       # Kapasitas maksimal bar stamina
export(float) var stamina_drain_rate = 26.0 # Kecepatan berkurangnya stamina per detik saat lari (~3.8 detik)
export(float) var stamina_regen_rate = 35.0 # Kecepatan pengisian stamina per detik (~2.8 detik)

# Posisi mengapung Stamina Ring di atas kepala MC (Ubah Y lebih minus jika ingin lebih ke atas lagi)
export(Vector2) var stamina_ring_offset = Vector2(0, -235)

var speed = 240.0
var facing = "front"
var velocity = Vector2.ZERO

var current_stamina = 100.0
var stamina_regen_timer = 0.0
var is_sprinting = false
var is_exhausted = false

# Visual Display Ring Stamina Melingkar di atas kepala Player
var stamina_ui: Node2D = null
var stamina_display_timer = 0.0

onready var anim = $AnimatedSprite 

# Kelas custom untuk render stamina ring melingkar (seperti Genshin Impact / Zelda BotW)
class StaminaRing extends Node2D:
	var stamina_ratio: float = 1.0
	var opacity: float = 0.0
	var is_exhausted: bool = false
	
	func _draw():
		if opacity <= 0.005:
			return
		
		var radius = 25.0
		var thickness = 5.0
		var point_count = 48
		
		# 1. Bayangan lingkaran lembut (Glow / Shadow)
		draw_circle(Vector2.ZERO, radius + 3.0, Color(0.0, 0.0, 0.0, 0.45 * opacity))
		
		# 2. Disc bagian dalam (transparan gelap elegan)
		draw_circle(Vector2.ZERO, radius - 3.0, Color(0.04, 0.06, 0.10, 0.65 * opacity))
		
		# 3. Jalur kosong lingkaran (empty track ring)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, point_count, Color(0.15, 0.20, 0.28, 0.85 * opacity), thickness, true)
		
		# 4. Busur stamina aktif: Hijau di kanan (saat tinggi/penuh), Merah di kiri (saat kritis/habis)
		if stamina_ratio > 0.015:
			var fill_color = Color(0.25, 0.92, 0.55, opacity) # Hijau zamrud cerah
			if stamina_ratio < 0.22 or is_exhausted:
				var blink = (sin(OS.get_ticks_msec() * 0.016) * 0.15) if is_exhausted else 0.0
				fill_color = Color(0.96, 0.26 + blink, 0.22, opacity) # Merah bahaya (di kiri)
			elif stamina_ratio < 0.50:
				var t = (stamina_ratio - 0.22) / 0.28
				fill_color = Color(0.96, lerp(0.35, 0.85, t), 0.22, opacity) # Gradasi oranye ke kuning
			else:
				var t = (stamina_ratio - 0.50) / 0.50
				fill_color = Color(lerp(0.96, 0.25, t), lerp(0.85, 0.92, t), lerp(0.25, 0.55, t), opacity) # Kuning ke hijau
				
			var sweep = TAU * clamp(stamina_ratio, 0.0, 1.0)
			var segs = max(3, int(point_count * clamp(stamina_ratio, 0.0, 1.0)))
			var pts = PoolVector2Array()
			for i in range(segs + 1):
				# 0% - 50% berada di setengah lingkaran KIRI (Merah saat kritis)
				# 50% - 100% berada di setengah lingkaran KANAN (Hijau saat penuh)
				# Saat lari, stamina kanan (hijau) terkuras lebih dahulu, menyisakan merah di kiri
				var a = -PI * 0.5 - (float(i) / float(segs)) * sweep
				pts.append(Vector2(cos(a), sin(a)) * radius)
			draw_polyline(pts, fill_color, thickness, true)
			
			draw_circle(pts[0], thickness * 0.48, fill_color)
			draw_circle(pts[pts.size() - 1], thickness * 0.48, fill_color)

func _setup_stamina_ui():
	stamina_ui = StaminaRing.new()
	stamina_ui.position = stamina_ring_offset
	stamina_ui.z_index = 20
	add_child(stamina_ui)

func _ready():
	anim.play(facing)
	anim.stop()
	_setup_stamina_ui()
	if Global.posisi_spawn_sementara != Vector2.ZERO:
		global_position = Global.posisi_spawn_sementara
		Global.posisi_spawn_sementara = Vector2.ZERO

func is_moving() -> bool:
	return velocity != Vector2.ZERO

func set_facing(arah: String):
	facing = arah
	if is_instance_valid(anim):
		anim.play(facing)
		anim.stop()
	var guider = get_node_or_null("Guider")
	if is_instance_valid(guider) and guider.has_method("teleport_ke_player"):
		guider.teleport_ke_player()

func is_input_locked() -> bool:
	if Global.dialog_aktif or Global.is_dialogue_playing() or Global.cutscene_aktif or Global.guide_modal_terbuka:
		return true
	if is_instance_valid(Global.fade_rect) and Global.fade_rect.modulate.a > 0.15:
		return true
	return false

func teleport_guider_ke_player():
	var guider = get_node_or_null("Guider")
	if is_instance_valid(guider) and guider.has_method("teleport_ke_player"):
		guider.teleport_ke_player()

func _physics_process(delta):
	# Kunci input saat dialog, cutscene, atau transisi fade sedang aktif
	if is_input_locked():
		velocity = Vector2.ZERO
		anim.stop()
		anim.speed_scale = 1.0
		is_sprinting = false
		current_stamina = min(max_stamina, current_stamina + stamina_regen_rate * delta)
		if is_instance_valid(stamina_ui):
			stamina_ui.opacity = move_toward(stamina_ui.opacity, 0.0, delta * 4.0)
			stamina_ui.update()
		return

	velocity = Vector2.ZERO

	if Input.is_key_pressed(KEY_D) or Input.is_action_pressed("move_right"):
		velocity.x += 1
	if Input.is_key_pressed(KEY_A) or Input.is_action_pressed("move_left"):
		velocity.x -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_action_pressed("move_down"):
		velocity.y += 1
	if Input.is_key_pressed(KEY_W) or Input.is_action_pressed("move_up"):
		velocity.y -= 1

	var player_berjalan = (velocity != Vector2.ZERO)

	# Logika Tombol Shift (Sprint / Lari Tambah Kecepatan)
	var shift_pressed = Input.is_key_pressed(KEY_SHIFT) or (InputMap.has_action("sprint") and Input.is_action_pressed("sprint"))
	
	if player_berjalan and shift_pressed and not is_exhausted and current_stamina > 0.0:
		is_sprinting = true
		current_stamina = max(0.0, current_stamina - stamina_drain_rate * delta)
		stamina_regen_timer = 0.35
		if current_stamina <= 0.0:
			is_exhausted = true
			is_sprinting = false
	else:
		is_sprinting = false
		if stamina_regen_timer > 0.0:
			stamina_regen_timer -= delta
		else:
			current_stamina = min(max_stamina, current_stamina + stamina_regen_rate * delta)
			if is_exhausted and current_stamina >= 15.0:
				is_exhausted = false

	# Kecepatan aktual saat ini
	var current_speed = sprint_speed if is_sprinting else walk_speed
	speed = current_speed

	if player_berjalan:
		velocity = velocity.normalized()

		if abs(velocity.x) > abs(velocity.y):
			facing = "right" if velocity.x > 0 else "left"
		else:
			facing = "front" if velocity.y > 0 else "back"

		if anim.animation != facing:
			anim.play(facing)
		elif not anim.is_playing():
			anim.play(facing)

		# Animasi kaki melangkah lebih cepat saat lari
		anim.speed_scale = 1.45 if is_sprinting else 1.0

		velocity = move_and_slide(velocity * current_speed)
	else:
		anim.stop()
		anim.speed_scale = 1.0

	# Update visual Stamina Ring
	if not is_instance_valid(stamina_ui):
		return
		
	stamina_ui.position = stamina_ring_offset
	stamina_ui.stamina_ratio = current_stamina / max_stamina
	stamina_ui.is_exhausted = is_exhausted
	
	if current_stamina < max_stamina or is_sprinting:
		stamina_display_timer = 0.6
		stamina_ui.opacity = move_toward(stamina_ui.opacity, 1.0, delta * 5.0)
	else:
		if stamina_display_timer > 0.0:
			stamina_display_timer -= delta
		else:
			stamina_ui.opacity = move_toward(stamina_ui.opacity, 0.0, delta * 2.5)
			
	stamina_ui.update()
