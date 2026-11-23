extends Node2D

var dialog_resource = load("res://dialogues/modern_s_n.tres")

# Tekstur ekspresi Moxie (Cemberut sebelum dibantu, Senyum setelah dibantu)
var tex_moxie_cemberut = preload("res://aset/World 2/World/M_NPC2.png")
var tex_moxie_senyum = preload("res://aset/World 2/World/M_NPC.png")

onready var ysort_node = $YSort if has_node("YSort") else self
onready var gatekeeper = $YSort/GatekeeperNPC if has_node("YSort/GatekeeperNPC") else get_node_or_null("GatekeeperNPC")
onready var player = $YSort/Player if has_node("YSort/Player") else get_node_or_null("Player")
onready var npc_moxie = $YSort/NPC1 if has_node("YSort/NPC1") else null
onready var npc_zana = $YSort/NPC2 if has_node("YSort/NPC2") else null
onready var npc_arif = $YSort/NPC3_TieBreaker if has_node("YSort/NPC3_TieBreaker") else null
onready var bgm = $BGM if has_node("BGM") else null

var prolog_sedang_berjalan = false
var quest_selesai_zona = 0
var total_quest = 3
var npc_sudah_diajak_bicara = []
var cutscene_berjalan = false
var zana_cutscene_pending = false

# Tween untuk pergerakan kamera dan animasi karakter
var tween = Tween.new()

# Flash overlay untuk kamera Arif
var flash_overlay: ColorRect = null

# Sistem AreaTindih & ACCTindih
var tindih_nodes = {}
var active_triggers = {}
const CONDITIONAL_TINDIH_NAMES = ["Bottom3", "Bottom2"]

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
	
	_buat_flash_overlay()
	atur_batas_kamera()
	inisialisasi_area_tindih()
	
	if not DialogueManager.is_connected("dialogue_finished", self, "_on_dialog_global_selesai"):
		DialogueManager.connect("dialogue_finished", self, "_on_dialog_global_selesai")
		
	# Hubungkan signal dialog_selesai dari seluruh NPC di dalam YSort
	var search_node = get_node_or_null("YSort")
	var children = search_node.get_children() if search_node != null else get_children()
	for child in children:
		if child.has_signal("dialog_selesai") and child != gatekeeper:
			child.connect("dialog_selesai", self, "_on_npc_dialog_selesai")
			
	# AWAL GAME: Sembunyikan Gatekeeper sepenuhnya
	if is_instance_valid(gatekeeper):
		gatekeeper.hide()
		
	inisialisasi_posisi_npc()
	if Global.sedang_muat_save:
		inisialisasi_status_save()
	else:
		jalankan_prolog()

func inisialisasi_status_save():
	quest_selesai_zona = Global.quest_selesai
	npc_sudah_diajak_bicara = []
	if Global.zana_selesai:
		npc_sudah_diajak_bicara.append("npc_zana")
	if Global.moxie_selesai:
		npc_sudah_diajak_bicara.append("npc_moxie")
	if Global.arif_selesai:
		npc_sudah_diajak_bicara.append("npc_arif")
		
	inisialisasi_posisi_npc()
	
	if quest_selesai_zona >= total_quest and is_instance_valid(gatekeeper):
		gatekeeper.modulate.a = 1.0
		gatekeeper.show()

# ==============================================================================
# SISTEM FOREGROUND OCCLUSION (AREA TINDIH & ACCTINDIH TRIGGER)
# ==============================================================================
func inisialisasi_area_tindih():
	var bg = get_node_or_null("Background")
	var area_tindih = get_node_or_null("AreaTindih")
	if not is_instance_valid(bg) or not is_instance_valid(area_tindih):
		return
	
	if not bg.texture:
		return
		
	var tex = bg.texture
	var tex_half = tex.get_size() * 0.5
	
	# Bersihkan overlay lama jika ada
	var old_overlay = get_node_or_null("OverlayForeground")
	if is_instance_valid(old_overlay):
		old_overlay.queue_free()
		
	var overlay = Node2D.new()
	overlay.name = "OverlayForeground"
	overlay.z_index = 5
	overlay.transform = bg.transform
	add_child(overlay)
	
	tindih_nodes.clear()
	
	for child in area_tindih.get_children():
		if child is CollisionPolygon2D and child.polygon.size() > 2:
			var poly_node = Polygon2D.new()
			poly_node.name = "Tindih_" + child.name
			poly_node.texture = tex
			
			var poly_points = PoolVector2Array()
			var uvs = PoolVector2Array()
			
			for pt in child.polygon:
				var global_pt = child.to_global(pt)
				var local_bg_pt = bg.to_local(global_pt)
				poly_points.append(local_bg_pt)
				uvs.append(local_bg_pt + tex_half)
				
			poly_node.polygon = poly_points
			poly_node.uv = uvs
			overlay.add_child(poly_node)
			
			tindih_nodes[child.name] = {
				"poly": poly_node,
				"col": child
			}
			
			if child.name in CONDITIONAL_TINDIH_NAMES:
				poly_node.visible = false
				child.set_deferred("disabled", true)
			else:
				poly_node.visible = true
				child.set_deferred("disabled", false)
				
	var acctindih = get_node_or_null("ACCTindih")
	if is_instance_valid(acctindih):
		acctindih.collision_layer = 0
		acctindih.collision_mask = 0
		
		var trigger_shapes = []
		for c in acctindih.get_children():
			if c is CollisionPolygon2D:
				trigger_shapes.append(c)
				
		for trig_col in trigger_shapes:
			var trig_name = trig_col.name
			var trig_area = Area2D.new()
			trig_area.name = "TrigArea_" + trig_name
			trig_area.collision_layer = 0
			trig_area.collision_mask = 1 # Monitor Player layer 1
			trig_area.monitoring = true
			trig_area.monitorable = false
			
			acctindih.remove_child(trig_col)
			trig_area.add_child(trig_col)
			acctindih.add_child(trig_area)
			
			trig_area.connect("body_entered", self, "_on_trigger_body_entered", [trig_name])
			trig_area.connect("body_exited", self, "_on_trigger_body_exited", [trig_name])

func _on_trigger_body_entered(body: Node, trig_name: String):
	if body is KinematicBody2D or body.name == "Player":
		active_triggers[trig_name] = true
		_update_conditional_tindih()

func _on_trigger_body_exited(body: Node, trig_name: String):
	if body is KinematicBody2D or body.name == "Player":
		active_triggers[trig_name] = false
		_update_conditional_tindih()

func _update_conditional_tindih():
	var is_lamp = active_triggers.get("Lamp", false)
	var is_lamp2 = active_triggers.get("Lamp2", false)
	
	# Bottom3 = Lamp ketriger
	_set_tindih_state("Bottom3", is_lamp)
	# Bottom2 = Lamp2 ketriger
	_set_tindih_state("Bottom2", is_lamp2)

func _set_tindih_state(target_name: String, is_active: bool):
	if tindih_nodes.has(target_name):
		var item = tindih_nodes[target_name]
		if is_instance_valid(item.get("poly")):
			item["poly"].visible = is_active
		if is_instance_valid(item.get("col")):
			item["col"].set_deferred("disabled", not is_active)

func _buat_flash_overlay():
	var canvas = CanvasLayer.new()
	canvas.layer = 95
	add_child(canvas)
	
	flash_overlay = ColorRect.new()
	flash_overlay.color = Color.white
	flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_overlay.rect_min_size = Vector2(3000, 3000)
	flash_overlay.modulate.a = 0.0
	canvas.add_child(flash_overlay)

func inisialisasi_posisi_npc():
	# Kondisi awal Moxie: cemberut jika belum selesai, senyum jika sudah selesai dibantu
	if is_instance_valid(npc_moxie):
		var sprite_moxie = npc_moxie.get_node_or_null("Sprite")
		if is_instance_valid(sprite_moxie):
			if Global.moxie_selesai:
				sprite_moxie.texture = tex_moxie_senyum
			else:
				sprite_moxie.texture = tex_moxie_cemberut
		if npc_moxie.has_method("atur_tampilan_label"):
			npc_moxie.atur_tampilan_label()
			
	if is_instance_valid(npc_zana):
		if Global.zana_selesai:
			if Global.zana_opsi_denah:
				npc_zana.position = Vector2(860, 150)
			else:
				npc_zana.position = Vector2(-260, 320)

func jalankan_prolog():
	if Global.sedang_muat_save:
		return
	if dialog_resource != null and dialog_resource.get("raw_text") != null:
			dialog_resource = DialogueManager.get_resource_from_text(dialog_resource.raw_text)
	if dialog_resource == null or not dialog_resource.titles.has("prologue_modern"):
		return
	prolog_sedang_berjalan = true
	Global.mulai_dialog()
	yield(get_tree().create_timer(0.2), "timeout")
	DialogueManager.show_example_dialogue_balloon("prologue_modern", dialog_resource, [self, Global])

func _on_dialog_global_selesai():
	if prolog_sedang_berjalan:
		prolog_sedang_berjalan = false
		Global.periksa_dan_tampilkan_guide_awal()

# ==============================================================================
# CUTSCENE & ANIMASI NPC ZANA
# ==============================================================================

# OPSI 1: MC menyuruh Zana cek denah taman -> Zana melompat ceria menuju papan denah
func cutscene_zana_denah():
	Global.zana_opsi_denah = true
	zana_cutscene_pending = false
	if not is_instance_valid(npc_zana):
		return
		
	Global.cutscene_aktif = true
	Global.dialog_aktif = false
	
	# Layar dibuat terang (matikan efek peredup hitam)
	if is_instance_valid(Global.dim_rect):
		Global.dim_rect.visible = false
		
	# Sembunyikan balon dialog sementara agar animasi lompatan Zana terlihat jelas tanpa terhalang UI
	var balloons = get_tree().get_nodes_in_group("dialogue_balloon")
	for b in balloons:
		b.visible = false
		
	# Jalankan animasi lompat-lari ke arah papan denah di tengah atas
	var start_pos = npc_zana.position
	var target_pos = Vector2(860, 150)
	
	# Animasi 3 lompatan beruntun yang imut
	var hop_durasi = 0.35
	var steps = 3
	for i in range(steps):
		var p_start = start_pos.linear_interpolate(target_pos, float(i) / steps)
		var p_end = start_pos.linear_interpolate(target_pos, float(i + 1) / steps)
		
		# Naik ke udara
		tween.interpolate_property(npc_zana, "position:x", p_start.x, p_end.x, hop_durasi, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
		tween.interpolate_property(npc_zana, "position:y", p_start.y, p_start.y - 25.0, hop_durasi * 0.5, Tween.TRANS_SINE, Tween.EASE_OUT)
		tween.interpolate_property(npc_zana, "scale", Vector2(0.42, 0.42), Vector2(0.38, 0.46), hop_durasi * 0.5, Tween.TRANS_SINE, Tween.EASE_OUT)
		tween.start()
		yield(get_tree().create_timer(hop_durasi * 0.5), "timeout")
		
		# Turun mendarat
		tween.interpolate_property(npc_zana, "position:y", p_start.y - 25.0, p_end.y, hop_durasi * 0.5, Tween.TRANS_BOUNCE, Tween.EASE_OUT)
		tween.interpolate_property(npc_zana, "scale", Vector2(0.38, 0.46), Vector2(0.44, 0.38), hop_durasi * 0.3, Tween.TRANS_SINE, Tween.EASE_IN)
		tween.start()
		yield(get_tree().create_timer(hop_durasi * 0.5), "timeout")
		
		# Normalisasi skala
		tween.interpolate_property(npc_zana, "scale", npc_zana.scale, Vector2(0.42, 0.42), 0.1, Tween.TRANS_SINE, Tween.EASE_OUT)
		tween.start()
		yield(get_tree().create_timer(0.1), "timeout")
		
	# Munculkan kembali balon dan redupkan layar untuk dialog lanjutan
	for b in balloons:
		b.visible = true
	if is_instance_valid(Global.dim_rect):
		Global.dim_rect.visible = true
		
	Global.cutscene_aktif = false
	Global.dialog_aktif = true

# OPSI 2: MC menyarankan mencari jalan lain -> Tandai pending agar cutscene flik jalan setelah dialog selesai
func cutscene_zana_jembatan():
	Global.zana_opsi_denah = false
	if not Global.is_dialogue_playing():
		var st = _jalankan_cutscene_zana_jembatan()
		if st is GDScriptFunctionState and st.is_valid():
			yield(st, "completed")
	else:
		zana_cutscene_pending = true

# Cutscene eksplorasi flik-flik (2-4 detik) mencari jalan bersama Zana menuju danau
func _jalankan_cutscene_zana_jembatan():
	if cutscene_berjalan:
		return
	cutscene_berjalan = true
	Global.cutscene_aktif = true
	Global.dialog_aktif = false
	Global.zana_opsi_denah = false
	
	if not is_instance_valid(npc_zana) or not is_instance_valid(player):
		Global.cutscene_aktif = false
		Global.dialog_aktif = false
		cutscene_berjalan = false
		return
		
	var kamera = player.get_node_or_null("Camera2D")
	if is_instance_valid(kamera):
		kamera.set_as_toplevel(true)
		kamera.global_position = player.global_position
		
	# Layar dibuat terang saat cutscene berjalan (sembunyikan efek peredup dialog)
	if is_instance_valid(Global.dim_rect):
		Global.dim_rect.visible = false
		
	# =========================================================================
	# FLIK 1: Mencari bersama di area tengah / plaza taman
	# =========================================================================
	Global.fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	tween.interpolate_property(Global.fade_rect, "modulate:a", 0.0, 1.0, 0.18, Tween.TRANS_SINE, Tween.EASE_IN)
	tween.start()
	yield(tween, "tween_completed")
	
	player.position = Vector2(850, 480)
	npc_zana.position = Vector2(910, 460)
	if player.has_method("set_facing"):
		player.set_facing("right")
	if is_instance_valid(kamera):
		kamera.global_position = player.global_position
		kamera.align()
		
	tween.interpolate_property(Global.fade_rect, "modulate:a", 1.0, 0.0, 0.18, Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.start()
	yield(tween, "tween_completed")
	
	# Zana melompat kecil celingukan mencari jalan
	var z1_y = npc_zana.position.y
	tween.interpolate_property(npc_zana, "position:y", z1_y, z1_y - 20.0, 0.18, Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.start()
	yield(get_tree().create_timer(0.18), "timeout")
	tween.interpolate_property(npc_zana, "position:y", z1_y - 20.0, z1_y, 0.18, Tween.TRANS_BOUNCE, Tween.EASE_OUT)
	tween.start()
	yield(get_tree().create_timer(0.4), "timeout")
	
	# =========================================================================
	# FLIK 2: Mencari di tikungan jalur pepohonan menuju danau
	# =========================================================================
	tween.interpolate_property(Global.fade_rect, "modulate:a", 0.0, 1.0, 0.18, Tween.TRANS_SINE, Tween.EASE_IN)
	tween.start()
	yield(tween, "tween_completed")
	
	player.position = Vector2(180, 470)
	npc_zana.position = Vector2(120, 450)
	if player.has_method("set_facing"):
		player.set_facing("left")
	if is_instance_valid(kamera):
		kamera.global_position = player.global_position
		kamera.align()
		
	tween.interpolate_property(Global.fade_rect, "modulate:a", 1.0, 0.0, 0.18, Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.start()
	yield(tween, "tween_completed")
	
	# Zana melompat antusias melihat arah danau
	var z2_y = npc_zana.position.y
	tween.interpolate_property(npc_zana, "position:y", z2_y, z2_y - 22.0, 0.18, Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.start()
	yield(get_tree().create_timer(0.18), "timeout")
	tween.interpolate_property(npc_zana, "position:y", z2_y - 22.0, z2_y, 0.18, Tween.TRANS_BOUNCE, Tween.EASE_OUT)
	tween.start()
	yield(get_tree().create_timer(0.4), "timeout")
	
	# =========================================================================
	# FLIK 3: Sampai di depan jembatan danau!
	# =========================================================================
	tween.interpolate_property(Global.fade_rect, "modulate:a", 0.0, 1.0, 0.20, Tween.TRANS_SINE, Tween.EASE_IN)
	tween.start()
	yield(tween, "tween_completed")
	
	# MC berada di depan jembatan
	player.position = Vector2(-150, 410)
	# Zana di samping MC terlebih dahulu
	npc_zana.position = Vector2(-190, 380)
	if player.has_method("set_facing"):
		player.set_facing("left")
	if is_instance_valid(kamera):
		kamera.global_position = player.global_position
		kamera.align()
		
	tween.interpolate_property(Global.fade_rect, "modulate:a", 1.0, 0.0, 0.22, Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.start()
	yield(tween, "tween_completed")
	Global.fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	yield(get_tree().create_timer(0.35), "timeout")
	
	# =========================================================================
	# Zana teleport / melompat ke pinggir danau (kayu atas kiri: Vector2(-260, 320))
	# =========================================================================
	var jembatan_pos = Vector2(-260, 320)
	
	# Squash persiapan melompat/teleport
	tween.interpolate_property(npc_zana, "scale", Vector2(0.42, 0.42), Vector2(0.48, 0.28), 0.15, Tween.TRANS_SINE, Tween.EASE_IN)
	tween.start()
	yield(get_tree().create_timer(0.15), "timeout")
	
	# Fade singkat teleport
	tween.interpolate_property(npc_zana, "modulate:a", 1.0, 0.0, 0.12, Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.start()
	yield(get_tree().create_timer(0.12), "timeout")
	
	# Pindah posisi ke atas kayu dermaga danau
	npc_zana.position = jembatan_pos
	npc_zana.scale = Vector2(0.30, 0.55)
	
	# Muncul kembali dengan efek pop & stretch bounce
	tween.interpolate_property(npc_zana, "modulate:a", 0.0, 1.0, 0.15, Tween.TRANS_SINE, Tween.EASE_IN)
	tween.interpolate_property(npc_zana, "scale", Vector2(0.30, 0.55), Vector2(0.42, 0.42), 0.25, Tween.TRANS_BOUNCE, Tween.EASE_OUT)
	tween.start()
	yield(get_tree().create_timer(0.25), "timeout")
	
	# Zana melompat senang di pinggir danau (berpamitan dengan MC)
	var z_dock_y = jembatan_pos.y
	tween.interpolate_property(npc_zana, "position:y", z_dock_y, z_dock_y - 25.0, 0.2, Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.start()
	yield(get_tree().create_timer(0.2), "timeout")
	tween.interpolate_property(npc_zana, "position:y", z_dock_y - 25.0, z_dock_y, 0.2, Tween.TRANS_BOUNCE, Tween.EASE_OUT)
	tween.start()
	yield(get_tree().create_timer(0.3), "timeout")
	
	# =========================================================================
	# Selesai: Kembalikan kamera ke Player & Buka Kunci Gerak
	# =========================================================================
	if is_instance_valid(kamera):
		kamera.set_as_toplevel(false)
		kamera.position = Vector2.ZERO
		
	Global.cutscene_aktif = false
	Global.dialog_aktif = false
	cutscene_berjalan = false

# ==============================================================================
# ANIMASI MOXIE & ARIF
# ==============================================================================

# Animasi Moxie merasa lega dan berterima kasih (lompat memantul lega & ekspresi berubah ceria)
func animasi_moxie_lega():
	if not is_instance_valid(npc_moxie):
		return
	var base_pos = npc_moxie.position
	var base_scale = Vector2(0.42, 0.42)
	var sprite_moxie = npc_moxie.get_node_or_null("Sprite")
	
	# Lompatan 1: Moxie melompat terkejut lega, di puncak lompatan ekspresi berubah dari cemberut ke senyum!
	tween.interpolate_property(npc_moxie, "position:y", base_pos.y, base_pos.y - 22.0, 0.20, Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.interpolate_property(npc_moxie, "scale", base_scale, Vector2(0.38, 0.48), 0.20, Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.start()
	yield(get_tree().create_timer(0.20), "timeout")
	
	# Puncak lompatan: Ubah aset sprite Moxie dari cemberut (_2) ke senyum biasa!
	if is_instance_valid(sprite_moxie):
		sprite_moxie.texture = tex_moxie_senyum
	if npc_moxie.has_method("atur_tampilan_label"):
		npc_moxie.atur_tampilan_label()
		
	# Mendarat kenyal (bounce)
	tween.interpolate_property(npc_moxie, "position:y", base_pos.y - 22.0, base_pos.y, 0.18, Tween.TRANS_BOUNCE, Tween.EASE_OUT)
	tween.interpolate_property(npc_moxie, "scale", Vector2(0.38, 0.48), Vector2(0.46, 0.38), 0.14, Tween.TRANS_SINE, Tween.EASE_IN)
	tween.start()
	yield(get_tree().create_timer(0.18), "timeout")
	
	# Pulihkan skala normal
	tween.interpolate_property(npc_moxie, "scale", Vector2(0.46, 0.38), base_scale, 0.12, Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.start()
	yield(get_tree().create_timer(0.12), "timeout")
	
	# Lompatan 2: Lompatan riang kedua karena lega masalahnya terselesaikan
	tween.interpolate_property(npc_moxie, "position:y", base_pos.y, base_pos.y - 14.0, 0.15, Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.interpolate_property(npc_moxie, "scale", base_scale, Vector2(0.39, 0.45), 0.15, Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.start()
	yield(get_tree().create_timer(0.15), "timeout")
	
	tween.interpolate_property(npc_moxie, "position:y", base_pos.y - 14.0, base_pos.y, 0.15, Tween.TRANS_BOUNCE, Tween.EASE_OUT)
	tween.interpolate_property(npc_moxie, "scale", Vector2(0.39, 0.45), base_scale, 0.15, Tween.TRANS_SINE, Tween.EASE_IN)
	tween.start()
	yield(get_tree().create_timer(0.15), "timeout")

# Animasi Arif antusias & kilatan kamera fotografi
func animasi_arif_senang():
	if not is_instance_valid(npc_arif):
		return
	var base_pos = npc_arif.position
	var base_scale = Vector2(0.42, 0.42)
	
	# Efek kilatan blitz foto (kamera Arif menjepret hasil tatanan foto)
	if is_instance_valid(flash_overlay):
		tween.interpolate_property(flash_overlay, "modulate:a", 0.0, 0.8, 0.08, Tween.TRANS_SINE, Tween.EASE_OUT)
		tween.start()
		yield(get_tree().create_timer(0.08), "timeout")
		tween.interpolate_property(flash_overlay, "modulate:a", 0.8, 0.0, 0.25, Tween.TRANS_SINE, Tween.EASE_IN)
		tween.start()
		
	# Lompat bangga / antusias
	tween.interpolate_property(npc_arif, "position:y", base_pos.y, base_pos.y - 25.0, 0.2, Tween.TRANS_BACK, Tween.EASE_OUT)
	tween.interpolate_property(npc_arif, "scale", base_scale, base_scale * 1.15, 0.2, Tween.TRANS_BACK, Tween.EASE_OUT)
	tween.start()
	yield(get_tree().create_timer(0.25), "timeout")
	
	tween.interpolate_property(npc_arif, "position:y", npc_arif.position.y, base_pos.y, 0.2, Tween.TRANS_BOUNCE, Tween.EASE_OUT)
	tween.interpolate_property(npc_arif, "scale", npc_arif.scale, base_scale, 0.2, Tween.TRANS_SINE, Tween.EASE_IN)
	tween.start()
	yield(get_tree().create_timer(0.2), "timeout")

# ==============================================================================
# PENYELESAIAN NPC & CUTSCENE GATEKEEPER
# ==============================================================================

func _on_npc_dialog_selesai(key_dialog: String):
	if key_dialog in ["npc_zana", "npc_moxie", "npc_arif"]:
		if not (key_dialog in npc_sudah_diajak_bicara):
			npc_sudah_diajak_bicara.append(key_dialog)
			quest_selesai_zona += 1
			print("Quest Modern Selesai: ", quest_selesai_zona, "/", total_quest)
			
			# Kunci tombol gerak dan interaksi selama animasi selesai berlangsung, layar TERANG
			Global.cutscene_aktif = true
			Global.dialog_aktif = false
			if is_instance_valid(Global.dim_rect):
				Global.dim_rect.visible = false
			
			if key_dialog == "npc_zana":
				if zana_cutscene_pending or not Global.zana_opsi_denah:
					zana_cutscene_pending = false
					var st = _jalankan_cutscene_zana_jembatan()
					if st is GDScriptFunctionState and st.is_valid():
						yield(st, "completed")
			elif key_dialog == "npc_moxie":
				var st = animasi_moxie_lega()
				if st is GDScriptFunctionState and st.is_valid():
					yield(st, "completed")
			elif key_dialog == "npc_arif":
				var st = animasi_arif_senang()
				if st is GDScriptFunctionState and st.is_valid():
					yield(st, "completed")
				
			# Jika seluruh quest di zona ini selesai, picu cutscene kemunculan Gatekeeper!
			if quest_selesai_zona >= total_quest:
				yield(get_tree().create_timer(0.8), "timeout")
				mulai_cutscene_gatekeeper()
			else:
				# Jika belum semua selesai, pulihkan kontrol player
				Global.cutscene_aktif = false
				Global.dialog_aktif = false

func mulai_cutscene_gatekeeper():
	if cutscene_berjalan:
		return
	cutscene_berjalan = true
	Global.cutscene_aktif = true
	Global.dialog_aktif = false
	if is_instance_valid(Global.dim_rect):
		Global.dim_rect.visible = false
	
	if not is_instance_valid(player) or not is_instance_valid(gatekeeper):
		Global.cutscene_aktif = false
		Global.dialog_aktif = false
		cutscene_berjalan = false
		return
		
	var kamera = player.get_node_or_null("Camera2D")
	if not is_instance_valid(kamera):
		gatekeeper.show()
		Global.cutscene_aktif = false
		Global.dialog_aktif = false
		cutscene_berjalan = false
		return
		
	# 1. Pastikan titik mulai kamera dari posisi Player saat ini
	var start_pos = player.global_position
	kamera.set_as_toplevel(true)
	kamera.global_position = start_pos
	
	# Layar dibuat terang saat cutscene kamera berjalan
	if is_instance_valid(Global.dim_rect):
		Global.dim_rect.visible = false
	
	# 2. Geser kamera mulus menuju posisi Gatekeeper di pintu keluar (1787, 37)
	var target_pos = gatekeeper.global_position
	tween.interpolate_property(kamera, "global_position", start_pos, target_pos, 1.5, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	tween.start()
	yield(tween, "tween_completed")
	
	# 3. Fade In Gatekeeper
	gatekeeper.modulate.a = 0.0
	gatekeeper.show()
	tween.interpolate_property(gatekeeper, "modulate:a", 0.0, 1.0, 1.0, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	tween.start()
	yield(tween, "tween_completed")
	yield(get_tree().create_timer(0.4), "timeout")
	
	# 4. Panggil dialog panggilan MC (layar digelapkan di tengah cutscene agar dialog fokus)
	Global.mulai_dialog()
	DialogueManager.show_example_dialogue_balloon("panggil_mc_modern", dialog_resource, [self, Global])
	yield(DialogueManager, "dialogue_finished")
	Global.akhiri_dialog()
	
	# 5. KUNCI GERAK PLAYER SAAT KAMERA PULANG (layar terang kembali, tapi gerak TETAP diblokir total!)
	Global.cutscene_aktif = true
	if is_instance_valid(Global.dim_rect):
		Global.dim_rect.visible = false
	
	# 6. Gerakkan kamera kembali mulus ke posisi Player
	tween.interpolate_property(kamera, "global_position", target_pos, player.global_position, 1.5, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	tween.start()
	yield(tween, "tween_completed")
	
	# 7. Kembalikan kontrol kamera ke Player & BUKA KUNCI GERAK HANYA SETELAH KAMERA SAMPAI
	kamera.set_as_toplevel(false)
	kamera.position = Vector2.ZERO
	Global.cutscene_aktif = false
	Global.dialog_aktif = false
	cutscene_berjalan = false

func atur_batas_kamera():
	var batas = get_node_or_null("BatasKamera")
	if is_instance_valid(player) and is_instance_valid(batas):
		var kamera = player.get_node_or_null("Camera2D")
		if is_instance_valid(kamera):
			var rect = batas.get_global_rect()
			kamera.limit_left = int(rect.position.x)
			kamera.limit_top = int(rect.position.y)
			kamera.limit_right = int(rect.end.x)
			kamera.limit_bottom = int(rect.end.y)

