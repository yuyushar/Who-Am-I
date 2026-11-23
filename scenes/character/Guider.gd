extends Node2D

# ==========================================
# KONFIGURASI KECEPATAN & JARAK GUIDER
# (Bisa diatur langsung di Inspector Godot atau diedit di sini)
# ==========================================
export(float) var speed_slow = 160.0          # Speed santai / lambat saat jarak normal
export(float) var speed_fast = 340.0          # Speed kencang saat ketinggalan jauh (kejar MC)

# PENGATURAN JARAK POSISI GUIDER DARI MC (Dalam World Pixels)
# Semakin besar angkanya, semakin jauh posisi Guider melayang dari tubuh MC
export(float) var jarak_jauh_x = 95.0         # Jarak horizontal Guider dari MC (default: 95)
export(float) var jarak_jauh_y = 100.0        # Jarak vertikal Guider dari MC (default: 100)

export(float) var jarak_stop = 30.0           # Jarak berhenti mendekat (sudah pas di titik target)
export(float) var jarak_mulai_gerak = 55.0    # Jarak A: Jarak minimum sebelum Guider mulai bergerak
export(float) var jarak_kejar_kencang = 220.0 # Jarak B: Jarak jauh untuk memicu speed kencang
export(float) var jarak_teleport = 480.0      # Batas lompatan instan (cutscene / ganti map)

var mode_kejar_kencang = false
var wave_time = 0.0

# Pengaturan Idle 3 Detik
var idle_timer = 0.0
var idle_wander_timer = 0.0
var idle_target_offset = Vector2.ZERO
var idle_wander_offset = Vector2.ZERO

onready var anim = $AnimatedSprite

func _ready():
	set_as_toplevel(true)
	# Pastikan Background map berada di layer paling bawah (-10) agar Guider tidak pernah tertimpa
	_pastikan_background_di_bawah()
	call_deferred("_pastikan_background_di_bawah")
	# Posisikan Guider langsung di tempatnya saat map dimulai agar tidak terbang dari (0,0)
	call_deferred("teleport_ke_player")

func _pastikan_background_di_bawah():
	var root = get_tree().current_scene
	if not root:
		root = get_parent()
		while root and root.get_parent() != get_tree().root:
			root = root.get_parent()
	if root:
		for node_name in ["Background", "LatarBelakang", "MapBackground"]:
			var bg = root.get_node_or_null(node_name)
			if bg and bg is CanvasItem:
				bg.z_index = -10

func teleport_ke_player():
	var player = get_parent()
	if not is_instance_valid(player):
		return
	var target = hitung_target_posisi(player, false)
	global_position = target
	mode_kejar_kencang = false
	idle_timer = 0.0
	idle_wander_offset = Vector2.ZERO
	idle_target_offset = Vector2.ZERO
	if is_instance_valid(anim):
		anim.rotation = 0.0
		anim.scale = Vector2(0.5, 0.5)

func hitung_base_offset(player_facing: String, player_sedang_gerak: bool) -> Vector2:
	# Aturan Posisi Guider (dalam koordinat pixel dunia nyata agar tidak mengecil oleh scale player):
	# - Saat player berjalan: Guider mengekor di belakang langkah player.
	# - Saat player berhenti (End Point): Guider melayang tepat ke BELAKANG tubuh MC.
	if player_sedang_gerak:
		match player_facing:
			"front":
				z_index = -1
				return Vector2(jarak_jauh_x * 0.75, -jarak_jauh_y * 0.8) # Di kanan dan belakang langkah MC
			"right":
				z_index = -1
				return Vector2(-jarak_jauh_x, -25.0) # Di kiri (belakang MC)
			"left":
				z_index = -1
				return Vector2(jarak_jauh_x, -25.0) # Di kanan (belakang MC)
			"back":
				z_index = 1
				return Vector2(-jarak_jauh_x * 0.75, jarak_jauh_y * 0.8) # Di kiri dan belakang langkah MC
			_:
				z_index = -1
				return Vector2(jarak_jauh_x * 0.75, -jarak_jauh_y * 0.8)
	else:
		# End point saat diam (selalu di belakang MC):
		match player_facing:
			"front":
				# MC hadap depan/bawah -> Belakang MC adalah arah ATAS (punggung)
				z_index = -1
				return Vector2(jarak_jauh_x * 0.45, -jarak_jauh_y)
			"right":
				# MC hadap kanan -> Belakang MC adalah arah KIRI
				z_index = -1
				return Vector2(-jarak_jauh_x, -20.0)
			"left":
				# MC hadap kiri -> Belakang MC adalah arah KANAN
				z_index = -1
				return Vector2(jarak_jauh_x, -20.0)
			"back":
				# MC hadap belakang/atas -> Belakang MC adalah arah BAWAH
				z_index = 1
				return Vector2(-jarak_jauh_x * 0.45, jarak_jauh_y)
			_:
				z_index = -1
				return Vector2(jarak_jauh_x * 0.45, -jarak_jauh_y)

func hitung_target_posisi(player: Node2D, player_sedang_gerak: bool) -> Vector2:
	var player_facing = "front"
	if "facing" in player:
		player_facing = player.facing
	var base_off = hitung_base_offset(player_facing, player_sedang_gerak)
	# Menggunakan jarak pixel dunia langsung tanpa dikalikan player.scale agar jaraknya tetap lebar
	return player.global_position + base_off

func _process(delta):
	var player = get_parent()
	if not is_instance_valid(player):
		return

	scale = player.scale
	var player_facing = "front"
	if "facing" in player:
		player_facing = player.facing

	# 1. Deteksi apakah Player sedang bergerak
	var player_sedang_gerak = false
	var input_locked = false
	if player.has_method("is_input_locked"):
		input_locked = player.is_input_locked()
	elif Global.dialog_aktif or Global.is_dialogue_playing() or Global.cutscene_aktif:
		input_locked = true

	if not input_locked:
		if player.has_method("is_moving"):
			player_sedang_gerak = player.is_moving()
		elif "velocity" in player and player.velocity != Vector2.ZERO:
			player_sedang_gerak = true
		elif Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_D):
			player_sedang_gerak = true
		elif Input.is_action_pressed("move_up") or Input.is_action_pressed("move_down") or Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right"):
			player_sedang_gerak = true

	var base_target = hitung_target_posisi(player, player_sedang_gerak)
	var dist = global_position.distance_to(base_target)

	# 2. Teleport otomatis jika player berpindah tempat mendadak / cutscene
	if dist > jarak_teleport:
		teleport_ke_player()
		return

	# 3. Logika Idle 3 Detik (Gerak kecil bebas saat MC diam)
	var target_posisi = base_target

	if player_sedang_gerak or Global.dialog_aktif or Global.cutscene_aktif:
		idle_timer = 0.0
		idle_wander_offset = Vector2.ZERO
		idle_target_offset = Vector2.ZERO
	else:
		idle_timer += delta
		if idle_timer >= 3.0:
			idle_wander_timer -= delta
			if idle_wander_timer <= 0.0:
				idle_wander_timer = rand_range(1.5, 2.6)
				var rx = rand_range(-14.0, 14.0)
				var ry = rand_range(-12.0, 12.0)
				idle_target_offset = Vector2(rx, ry)
				
			idle_wander_offset = idle_wander_offset.move_toward(idle_target_offset, 14.0 * delta)
			var bob_y = sin(OS.get_ticks_msec() * 0.0035) * 4.0
			target_posisi += idle_wander_offset + Vector2(0, bob_y)

	# 4. Logika Kecepatan Mengikuti & Deselerasi Halus (Smooth Deceleration)
	if dist > jarak_kejar_kencang:
		mode_kejar_kencang = true
	elif dist <= jarak_stop:
		mode_kejar_kencang = false

	if dist > jarak_mulai_gerak or mode_kejar_kencang:
		# Kecepatan transisi: melambat secara halus saat mulai mendekati target
		var current_speed = speed_slow
		if mode_kejar_kencang:
			if dist > jarak_mulai_gerak:
				current_speed = speed_fast
			else:
				# Masuk jarak A: turunkan kecepatan secara halus (ease-out)
				var t = clamp((dist - jarak_stop) / max(1.0, (jarak_mulai_gerak - jarak_stop)), 0.0, 1.0)
				current_speed = lerp(speed_slow * 0.85, speed_fast, t)

		# Gerakan meliuk / bergelombang (wavy flight) saat mengejar MC
		var move_step = current_speed * delta
		var to_target = (target_posisi - global_position)
		if to_target.length() > 2.0:
			var dir = to_target.normalized()
			var perp = Vector2(-dir.y, dir.x) # Vektor tegak lurus
			
			wave_time += delta * (14.0 if mode_kejar_kencang else 6.0)
			# Intensitas gelombang mengecil saat dekat agar mendarat pas di target
			var wave_factor = clamp(dist / 120.0, 0.0, 1.0)
			var wave_intensity = (18.0 if mode_kejar_kencang else 6.0) * wave_factor
			var wave_offset = perp * sin(wave_time) * wave_intensity
			
			var next_pos = global_position.move_toward(target_posisi, move_step)
			global_position = next_pos + (wave_offset * delta * 4.0)
		else:
			global_position = target_posisi

		# Animasi visual dinamis: Kemiringan tubuh (tilt) dan denyut (squash/stretch)
		if is_instance_valid(anim):
			var tilt_target = clamp((target_posisi.x - global_position.x) * 0.0035, -0.22, 0.22)
			anim.rotation = lerp(anim.rotation, tilt_target, delta * 8.0)
			
			if mode_kejar_kencang and dist > jarak_stop:
				var pulse = sin(OS.get_ticks_msec() * 0.014) * 0.07
				anim.scale = Vector2(0.5 * (1.0 + pulse), 0.5 * (1.0 - pulse))
			else:
				anim.scale = lerp(anim.scale, Vector2(0.5, 0.5), delta * 6.0)
	else:
		# Saat dekat atau MC diam: normalkan rotasi & skala
		if is_instance_valid(anim):
			anim.rotation = lerp(anim.rotation, 0.0, delta * 8.0)
			anim.scale = lerp(anim.scale, Vector2(0.5, 0.5), delta * 8.0)

		if idle_timer >= 3.0:
			# Melayang perlahan saat idle roaming
			global_position = global_position.move_toward(target_posisi, 28.0 * delta)
		elif dist > 1.0:
			# Bergeser perlahan ke posisi end point
			global_position = global_position.move_toward(target_posisi, speed_slow * 0.6 * delta)

	# 5. Sinkronisasi Animasi Arah Hadap
	if is_instance_valid(anim) and anim.animation != player_facing:
		anim.play(player_facing)
