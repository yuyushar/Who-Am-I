extends Node2D

var dialog_resource = load("res://dialogues/village_e_i.tres")

# Tekstur dan shader untuk pergantian dekorasi (Kondisi Awal vs Festival Terpasang)
var tex_flag_cloth = preload("res://aset/World 1/World/flag1.png")
var tex_flag_pole = preload("res://aset/World 1/World/flag2.png")
var tex_lamp_on = preload("res://aset/World 1/World/lamp1.png")
var tex_lamp_off = preload("res://aset/World 1/World/lamp2.png")
var flag_wind_shader = preload("res://scripts/flag_wind.shader")

onready var ysort_node = $YSort if has_node("YSort") else self
onready var gatekeeper = $YSort/GatekeeperNPC if has_node("YSort/GatekeeperNPC") else $GatekeeperNPC
onready var player = $YSort/Player if has_node("YSort/Player") else $Player
onready var flag_raka_cloth = $YSort/FlagRaka/Cloth if has_node("YSort/FlagRaka/Cloth") else null
onready var board_npc = $YSort/Board if has_node("YSort/Board") else null
onready var bgm = $BGM if has_node("BGM") else null
 
onready var flags_other = [
	get_node_or_null("YSort/FlagTopLeft"),
	get_node_or_null("YSort/FlagTopRight"),
	get_node_or_null("YSort/FlagBottomLeft")
]

onready var lamps = [
	get_node_or_null("YSort/LampTopLeft"),
	get_node_or_null("YSort/LampTopRight"),
	get_node_or_null("YSort/LampMidLeft"),
	get_node_or_null("YSort/LampMidRight"),
	get_node_or_null("YSort/LampGateLeft"),
	get_node_or_null("YSort/LampGateRight")
]

var prolog_sedang_berjalan = false
var quest_selesai_zona = 0
var total_quest = 3
var npc_sudah_diajak_bicara = []
var cutscene_raka_sudah_jalan = false

# Node Tween khusus untuk animasi cutscene
var tween = Tween.new() 

func _ready():
	Global.hentikan_bgm_global(0.8)
	if is_instance_valid(bgm):
		bgm.pause_mode = Node.PAUSE_MODE_PROCESS
		Global.fade_in_bgm(bgm, 1.2, 0.0)
	if not Global.sedang_muat_save:
		Global.reset_tracker_zona()
	Global.daftarkan_zona_aktif(filename)
	add_child(tween)
	if dialog_resource != null and dialog_resource.get("raw_text") != null:
		dialog_resource = DialogueManager.get_resource_from_text(dialog_resource.raw_text)
	
	atur_batas_kamera()
	
	if not DialogueManager.is_connected("dialogue_finished", self, "_on_dialog_global_selesai"):
		DialogueManager.connect("dialogue_finished", self, "_on_dialog_global_selesai")
		
	# Hubungkan signal dialog_selesai dari seluruh NPC di dalam YSort
	var search_node = get_node_or_null("YSort")
	var children = search_node.get_children() if search_node != null else get_children()
	for child in children:
		if child.has_signal("dialog_selesai") and child != gatekeeper:
			child.connect("dialog_selesai", self, "_on_npc_dialog_selesai")
	
	# AWAL GAME: Sembunyikan Gatekeeper sepenuhnya agar tidak bisa diajak interaksi
	if is_instance_valid(gatekeeper):
		gatekeeper.hide() 
	
	# Inisialisasi kondisi awal aset dinamis (Bendera, Lentera, & Papan Kaleva)
	inisialisasi_aset_dinamis()
		
	if Global.sedang_muat_save:
		inisialisasi_status_save()
	else:
		jalankan_prolog()

func inisialisasi_status_save():
	quest_selesai_zona = Global.quest_selesai
	npc_sudah_diajak_bicara = []
	if Global.raka_selesai:
		npc_sudah_diajak_bicara.append("npc_raka")
	if Global.kaleva_selesai:
		npc_sudah_diajak_bicara.append("npc_kaleva")
	if Global.annie_selesai:
		npc_sudah_diajak_bicara.append("npc_annie")
		
	inisialisasi_aset_dinamis()
	
	if quest_selesai_zona >= total_quest and is_instance_valid(gatekeeper):
		gatekeeper.modulate.a = 1.0
		gatekeeper.show()

# Menyesuaikan status awal aset sebelum pemain berbicara dengan NPC
func inisialisasi_aset_dinamis():
	# 1. Papan Pengumuman Kaleva (Hanya muncul jika Kaleva selesai DAN memilih opsi pasang di papan desa)
	if is_instance_valid(board_npc):
		if Global.kaleva_selesai and Global.kaleva_opsi_papan:
			board_npc.visible = true
			board_npc.modulate.a = 1.0
			board_npc.scale = Vector2(1.59204, 1.59204)
		else:
			board_npc.visible = false
			board_npc.modulate.a = 0.0
			board_npc.scale = Vector2(0.1, 0.1)
			
	# 2. Status Dekorasi Festival Raka (Bendera & Lentera Desa)
	if Global.raka_selesai:
		pasang_semua_dekorasi_instan()
	else:
		copot_semua_dekorasi_instan()

func copot_semua_dekorasi_instan():
	for f in flags_other:
		if is_instance_valid(f):
			f.texture = tex_flag_pole
			f.material = null
	if is_instance_valid(flag_raka_cloth):
		flag_raka_cloth.visible = false
		flag_raka_cloth.modulate.a = 0.0
	for l in lamps:
		if is_instance_valid(l):
			l.texture = tex_lamp_off

func pasang_semua_dekorasi_instan():
	var shader_mat = ShaderMaterial.new()
	shader_mat.shader = flag_wind_shader
	shader_mat.set_shader_param("speed", 2.8)
	shader_mat.set_shader_param("amplitude", 2.5)
	shader_mat.set_shader_param("wave_length", 0.04)
	
	for f in flags_other:
		if is_instance_valid(f):
			f.texture = tex_flag_cloth
			f.material = shader_mat
			
	if is_instance_valid(flag_raka_cloth):
		flag_raka_cloth.visible = true
		flag_raka_cloth.modulate.a = 1.0
		flag_raka_cloth.position.y = 0.0
		flag_raka_cloth.material = shader_mat
		
	for l in lamps:
		if is_instance_valid(l):
			l.texture = tex_lamp_on

func jalankan_prolog():
	if Global.sedang_muat_save:
		return
	if dialog_resource != null and dialog_resource.get("raw_text") != null:
			dialog_resource = DialogueManager.get_resource_from_text(dialog_resource.raw_text)
	if dialog_resource == null or not dialog_resource.titles.has("prologue_village"):
		return
	prolog_sedang_berjalan = true
	Global.mulai_dialog()
	yield(get_tree().create_timer(0.2), "timeout")
	DialogueManager.show_example_dialogue_balloon("prologue_village", dialog_resource, [self, Global])

func _on_dialog_global_selesai():
	if prolog_sedang_berjalan:
		prolog_sedang_berjalan = false
		Global.periksa_dan_tampilkan_guide_awal()

# Fungsi mutasi khusus yang dipanggil saat Player memilih Opsi 1 (Kolaborasi / "E")
# Fungsi mutasi khusus yang dipanggil saat Player memilih Opsi 1 (Kolaborasi / "E")
# Dipanggil tepat sebelum dialog Guide muncul
func cutscene_opsi_kolaborasi():
	if not cutscene_raka_sudah_jalan:
		cutscene_raka_sudah_jalan = true
		var st = jalankan_cutscene_dekorasi_raka(true)
		if st is GDScriptFunctionState and st.is_valid():
			yield(st, "completed")

# Fungsi mutasi khusus saat Player memilih Opsi Atas pada Kaleva (memasang di papan pengumuman desa)
func pilih_opsi_papan_kaleva():
	Global.kaleva_opsi_papan = true

func _on_npc_dialog_selesai(key_dialog: String):
	if key_dialog in ["npc_raka", "npc_kaleva", "npc_annie"]:
		if not (key_dialog in npc_sudah_diajak_bicara):
			npc_sudah_diajak_bicara.append(key_dialog)
			quest_selesai_zona += 1
			print("Quest Desa Selesai: ", quest_selesai_zona, "/", total_quest)
			
			# Kunci tombol gerak dan interaksi selama cutscene / animasi berlangsung, layar TERANG
			Global.cutscene_aktif = true
			Global.dialog_aktif = false
			if is_instance_valid(Global.dim_rect):
				Global.dim_rect.visible = false
			
			# Animasi cutscene spesifik per NPC
			if key_dialog == "npc_raka":
				# Jika pemain memilih Opsi 2 (Mandiri / "I"), cutscene dijalankan di akhir dialog
				if not cutscene_raka_sudah_jalan:
					cutscene_raka_sudah_jalan = true
					var st = jalankan_cutscene_dekorasi_raka(false)
					if st is GDScriptFunctionState and st.is_valid():
						yield(st, "completed")
			elif key_dialog == "npc_kaleva":
				# Papan pengumuman HANYA muncul jika pemain memilih opsi atas (papan desa)
				if Global.kaleva_opsi_papan:
					animasi_munculkan_papan_kaleva()
					yield(get_tree().create_timer(0.9), "timeout")
			
			# JIKA 3 QUEST SELESAI -> JALANKAN CUTSCENE KAMERA KE GATEKEEPER
			if quest_selesai_zona >= total_quest:
				yield(get_tree().create_timer(0.6), "timeout")
				mulai_cutscene_gatekeeper()
			else:
				Global.cutscene_aktif = false
				Global.dialog_aktif = false

# --- CUTSCENE DEKORASI RAKA (ZOOM OUT FOKUS DI TENGAH DESA & MUNCULKAN SEMUA LENTERA + BENDERA) ---
func jalankan_cutscene_dekorasi_raka(sebelum_guide: bool = false):
	Global.cutscene_aktif = true
	Global.dialog_aktif = false
	
	# Layar menjadi terang (matikan efek dim hitam transparan agar map terlihat jelas)
	if is_instance_valid(Global.dim_rect):
		Global.dim_rect.visible = false
	
	if not is_instance_valid(player):
		pasang_semua_dekorasi_instan()
		Global.cutscene_aktif = false
		if sebelum_guide and is_instance_valid(Global.dim_rect):
			Global.dim_rect.visible = true
		return
		
	var kamera = player.get_node_or_null("Camera2D")
	if not is_instance_valid(kamera):
		pasang_semua_dekorasi_instan()
		Global.cutscene_aktif = false
		if sebelum_guide and is_instance_valid(Global.dim_rect):
			Global.dim_rect.visible = true
		return
	
	# Titik fokus tengah alun-alun desa (area tengah antara kedua toko dan panggung)
	var map_center = to_global(Vector2(730, 420))
	var durasi_zoom = 1.4
	var target_zoom = Vector2(1.85, 1.85)
	
	# 1. Lepas kamera & geser mulus ke tengah alun-alun desa sambil zoom out proporsional
	kamera.set_as_toplevel(true)
	kamera.global_position = player.global_position
	
	tween.interpolate_property(kamera, "global_position", player.global_position, map_center, durasi_zoom, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	tween.interpolate_property(kamera, "zoom", Vector2(1, 1), target_zoom, durasi_zoom, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	tween.start()
	yield(tween, "tween_completed")
	
	# 2. Nyalakan dan pasang Lentera (lamp1.png) dengan efek pop bounce & pendaran cahaya
	for l in lamps:
		if is_instance_valid(l):
			l.texture = tex_lamp_on
			var base_s = Vector2(1.59204, 1.59204)
			tween.interpolate_property(l, "scale", base_s * 1.3, base_s, 0.45, Tween.TRANS_BACK, Tween.EASE_OUT)
			tween.interpolate_property(l, "modulate", Color(1.8, 1.8, 1.4, 1.0), Color.white, 0.5, Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.start()
	yield(get_tree().create_timer(0.3), "timeout")
	
	# 3. Pasang seluruh Bendera Festival (flag1.png + wind shader) & kain bendera Raka berkibar turun
	var shader_mat = ShaderMaterial.new()
	shader_mat.shader = flag_wind_shader
	shader_mat.set_shader_param("speed", 2.8)
	shader_mat.set_shader_param("amplitude", 2.5)
	shader_mat.set_shader_param("wave_length", 0.04)
	
	for f in flags_other:
		if is_instance_valid(f):
			f.texture = tex_flag_cloth
			f.material = shader_mat
			var base_s = Vector2(1.59204, 1.59204)
			tween.interpolate_property(f, "scale", base_s * 1.25, base_s, 0.45, Tween.TRANS_BACK, Tween.EASE_OUT)
			
	if is_instance_valid(flag_raka_cloth):
		flag_raka_cloth.visible = true
		flag_raka_cloth.position.y = -45.0
		flag_raka_cloth.modulate.a = 0.0
		flag_raka_cloth.material = shader_mat
		tween.interpolate_property(flag_raka_cloth, "position:y", -45.0, 0.0, 1.1, Tween.TRANS_BOUNCE, Tween.EASE_OUT)
		tween.interpolate_property(flag_raka_cloth, "modulate:a", 0.0, 1.0, 0.6, Tween.TRANS_SINE, Tween.EASE_IN)
	tween.start()
	
	# Berikan jeda 1.2 detik agar pemain bisa menikmati suasana desa yang sudah terdekorasi penuh
	yield(get_tree().create_timer(1.2), "timeout")
	
	# 4. Kembalikan kamera mulus ke Player (zoom kembali 1.0x)
	tween.interpolate_property(kamera, "global_position", map_center, player.global_position, durasi_zoom, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	tween.interpolate_property(kamera, "zoom", target_zoom, Vector2(1, 1), durasi_zoom, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	tween.start()
	yield(tween, "tween_completed")
	
	# 5. Pulihkan kepemilikan kamera ke Player
	kamera.set_as_toplevel(false)
	kamera.position = Vector2.ZERO
	Global.cutscene_aktif = false
	
	# 6. Jika cutscene berlangsung sebelum dialog Guide, aktifkan kembali layar redup dialog
	if sebelum_guide:
		if is_instance_valid(Global.dim_rect):
			Global.dim_rect.visible = true
	else:
		Global.dialog_aktif = false

# --- ANIMASI PAPAN PENGUMUMAN KALEVA (MEMANTUL MUNCUL DI DESA) ---
func animasi_munculkan_papan_kaleva():
	if is_instance_valid(board_npc) and not board_npc.visible:
		board_npc.visible = true
		board_npc.modulate.a = 0.0
		board_npc.scale = Vector2(0.1, 0.1)
		
		# Animasi papan pengumuman muncul membesar dengan efek elastis / spring (back ease-out)
		var target_scale = Vector2(1.59204, 1.59204)
		tween.interpolate_property(board_npc, "scale", Vector2(0.1, 0.1), target_scale, 0.9, Tween.TRANS_BACK, Tween.EASE_OUT)
		tween.interpolate_property(board_npc, "modulate:a", 0.0, 1.0, 0.5, Tween.TRANS_SINE, Tween.EASE_OUT)
		tween.start()

# --- FUNGSI CUTSCENE KAMERA KE GATEKEEPER ---
func mulai_cutscene_gatekeeper():
	Global.cutscene_aktif = true
	Global.dialog_aktif = false 
	
	if not is_instance_valid(player) or not is_instance_valid(gatekeeper):
		Global.cutscene_aktif = false
		Global.dialog_aktif = false
		return
		
	var kamera = player.get_node_or_null("Camera2D")
	if not is_instance_valid(kamera):
		gatekeeper.show()
		Global.cutscene_aktif = false
		Global.dialog_aktif = false
		return
	
	# 1. Pastikan titik mulai kamera persis dari posisi Player saat ini
	var start_pos = player.global_position
	kamera.set_as_toplevel(true)
	kamera.global_position = start_pos
	
	# Layar dibuat terang saat cutscene kamera berjalan
	if is_instance_valid(Global.dim_rect):
		Global.dim_rect.visible = false
	
	# Geser mulus langsung dari posisi Player menuju ke Gatekeeper
	var target_pos = gatekeeper.global_position
	tween.interpolate_property(kamera, "global_position", start_pos, target_pos, 1.5, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	tween.start()
	yield(tween, "tween_completed")
	
	# 2. Fade In Gatekeeper
	gatekeeper.modulate.a = 0.0
	gatekeeper.show()
	tween.interpolate_property(gatekeeper, "modulate:a", 0.0, 1.0, 1.0, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	tween.start()
	yield(tween, "tween_completed")
	yield(get_tree().create_timer(0.4), "timeout")
	
	# 3. Panggil dialog panggilan MC (layar digelapkan di tengah cutscene agar dialog fokus)
	Global.mulai_dialog()
	DialogueManager.show_example_dialogue_balloon("panggil_mc", dialog_resource, [self, Global])
	yield(DialogueManager, "dialogue_finished")
	Global.akhiri_dialog()
	
	# 4. KUNCI KEMBALI GERAK PLAYER SAAT KAMERA PULANG (layar terang kembali, gerak TETAP diblokir!)
	Global.cutscene_aktif = true
	if is_instance_valid(Global.dim_rect):
		Global.dim_rect.visible = false
	
	# 5. Gerakkan kamera kembali langsung ke posisi Player
	tween.interpolate_property(kamera, "global_position", target_pos, player.global_position, 1.5, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	tween.start()
	yield(tween, "tween_completed")
	
	# 6. Kembalikan kamera & buka kunci gerak sepenuhnya HANYA SETELAH KAMERA SAMPAI
	kamera.set_as_toplevel(false)
	kamera.position = Vector2.ZERO
	Global.cutscene_aktif = false
	Global.dialog_aktif = false

func atur_batas_kamera():
	var batas = get_node_or_null("BatasKamera")
	if is_instance_valid(player) and is_instance_valid(batas):
		var kamera = player.get_node_or_null("Camera2D")
		if is_instance_valid(kamera):
			kamera.limit_left = batas.margin_left + self.position.x
			kamera.limit_top = batas.margin_top + self.position.y
			kamera.limit_right = batas.margin_right + self.position.x
			kamera.limit_bottom = batas.margin_bottom + self.position.y

