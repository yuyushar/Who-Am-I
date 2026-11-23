extends Node2D

var dialog_resource = load("res://dialogues/future_t_f.tres")

# Tekstur monitor K-41RO (Tab2 = Merah/Krisis Energi, Tab1 = Normal/Energi Stabil)
var tex_tab_merah = preload("res://aset/World 3/World/Tab2.png")
var tex_tab_normal = preload("res://aset/World 3/World/Tab1.png")

onready var ysort_node = $YSort if has_node("YSort") else self
onready var gatekeeper = $YSort/GatekeeperNPC if has_node("YSort/GatekeeperNPC") else get_node_or_null("GatekeeperNPC")
onready var player = $YSort/Player if has_node("YSort/Player") else get_node_or_null("Player")
onready var npc_agcl = $YSort/NPC1 if has_node("YSort/NPC1") else null
onready var npc_k4iro = $YSort/NPC2 if has_node("YSort/NPC2") else null
onready var npc_elio = $YSort/NPC3_TieBreaker if has_node("YSort/NPC3_TieBreaker") else null
onready var robot_monitor = $YSort/RobotMonitor if has_node("YSort/RobotMonitor") else null
onready var bgm = $BGM if has_node("BGM") else null

# Daftar lampu futuristik kota di dalam YSort
onready var lamps = [
	get_node_or_null("YSort/Lamp1"),
	get_node_or_null("YSort/Lamp2"),
	get_node_or_null("YSort/Lamp3"),
	get_node_or_null("YSort/Lamp4"),
	get_node_or_null("YSort/Lamp5"),
	get_node_or_null("YSort/Lamp6"),
	get_node_or_null("YSort/Lamp7"),
	get_node_or_null("YSort/Lamp8"),
	get_node_or_null("YSort/Lamp9")
]

var prolog_sedang_berjalan = false
var quest_selesai_zona = 0
var total_quest = 3
var npc_sudah_diajak_bicara = []
var cutscene_berjalan = false

# Tween untuk pergerakan kamera dan animasi karakter
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
	inisialisasi_area_tindih()
	
	# Amankan deteksi seluruh lampu di YSort
	var ysort = get_node_or_null("YSort")
	if is_instance_valid(ysort):
		for child in ysort.get_children():
			if "lamp" in child.name.to_lower() and not (child in lamps):
				lamps.append(child)
	
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
		
	inisialisasi_status_objek()
	if Global.sedang_muat_save:
		inisialisasi_status_save()
	else:
		jalankan_prolog()

func inisialisasi_status_save():
	quest_selesai_zona = Global.quest_selesai
	npc_sudah_diajak_bicara = []
	if Global.agcl_selesai:
		npc_sudah_diajak_bicara.append("npc_agcl")
	if Global.k4iro_selesai:
		npc_sudah_diajak_bicara.append("npc_k4iro")
	if Global.elio_selesai:
		npc_sudah_diajak_bicara.append("npc_elio")
		
	inisialisasi_status_objek()
	
	if quest_selesai_zona >= total_quest and is_instance_valid(gatekeeper):
		gatekeeper.modulate.a = 1.0
		gatekeeper.show()

# ==============================================================================
# SISTEM FOREGROUND OCCLUSION (AREA TINDIH & ACCTINDIH TRIGGER)
# ==============================================================================
var tindih_nodes = {}
var active_triggers = {}
const CONDITIONAL_TINDIH_NAMES = []

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
	pass

func _set_tindih_state(target_name: String, is_active: bool):
	if tindih_nodes.has(target_name):
		var item = tindih_nodes[target_name]
		if is_instance_valid(item.get("poly")):
			item["poly"].visible = is_active
		if is_instance_valid(item.get("col")):
			item["col"].set_deferred("disabled", not is_active)

func inisialisasi_status_objek():
	# Kondisi monitor K-41RO: merah jika belum selesai, normal jika energi sudah teralokasi
	if is_instance_valid(robot_monitor):
		if Global.k4iro_selesai:
			robot_monitor.texture = tex_tab_normal
		else:
			robot_monitor.texture = tex_tab_merah

func jalankan_prolog():
	if Global.sedang_muat_save:
		return
	if dialog_resource != null and dialog_resource.get("raw_text") != null:
			dialog_resource = DialogueManager.get_resource_from_text(dialog_resource.raw_text)
	if dialog_resource == null or not dialog_resource.titles.has("prologue_future"):
		return
	prolog_sedang_berjalan = true
	Global.mulai_dialog()
	yield(get_tree().create_timer(0.2), "timeout")
	DialogueManager.show_example_dialogue_balloon("prologue_future", dialog_resource, [self, Global])

func _on_dialog_global_selesai():
	if prolog_sedang_berjalan:
		prolog_sedang_berjalan = false
		Global.periksa_dan_tampilkan_guide_awal()

# ==============================================================================
# ANIMASI & REAKSI NPC WORLD 3
# ==============================================================================

# Animasi Ag_CL: Menggaruk kepala / meregangkan badan santai di kursi setelah selesai coding (posisi duduk tetap di kursi)
func animasi_agcl_selesai():
	if not is_instance_valid(npc_agcl):
		return
	var base_scale = Vector2(0.42, 0.42)
	
	# Gerakan peregangan santai di kursi (sedikit squash/stretch dan tilt kepala seperti menggaruk/meregangkan badan)
	tween.interpolate_property(npc_agcl, "scale", base_scale, Vector2(0.44, 0.39), 0.2, Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.interpolate_property(npc_agcl, "rotation_degrees", 0.0, 4.0, 0.2, Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.start()
	yield(get_tree().create_timer(0.2), "timeout")
	
	tween.interpolate_property(npc_agcl, "rotation_degrees", 4.0, -3.0, 0.25, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	tween.start()
	yield(get_tree().create_timer(0.25), "timeout")
	
	tween.interpolate_property(npc_agcl, "scale", Vector2(0.44, 0.39), base_scale, 0.2, Tween.TRANS_SINE, Tween.EASE_IN)
	tween.interpolate_property(npc_agcl, "rotation_degrees", -3.0, 0.0, 0.2, Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.start()
	yield(get_tree().create_timer(0.2), "timeout")

# Mekanisme monitor K-41RO: Berkedip distorsi lalu berubah dari Tab2 (merah) ke Tab1 (normal)
func stabilkan_energi_k4iro():
	if not is_instance_valid(robot_monitor):
		return
		
	# Layar dibuat terang (matikan efek peredup dialog agar fokus cahaya kota terlihat jelas dan terang)
	if is_instance_valid(Global.dim_rect):
		Global.dim_rect.visible = false
		
	# Efek kedipan glitch/distorsi saat energi dialihkan
	for i in range(2):
		tween.interpolate_property(robot_monitor, "modulate", Color(1, 1, 1, 1), Color(3.0, 0.4, 0.4, 1), 0.08, Tween.TRANS_SINE, Tween.EASE_OUT)
		tween.start()
		yield(get_tree().create_timer(0.08), "timeout")
		
		tween.interpolate_property(robot_monitor, "modulate", Color(3.0, 0.4, 0.4, 1), Color(1, 1, 1, 1), 0.08, Tween.TRANS_SINE, Tween.EASE_IN)
		tween.start()
		yield(get_tree().create_timer(0.08), "timeout")
		
	# Berganti tekstur ke Tab1 (energi normal stabil)
	robot_monitor.texture = tex_tab_normal
	
	# Pendaran fokus cahaya terang pada objek monitor Tab & lampu-lampu kota:
	# Tab menyala cyan holografis sangat terang (glow) lalu stabil
	tween.interpolate_property(robot_monitor, "modulate", Color(0.2, 2.6, 3.2, 1.2), Color(1.15, 1.35, 1.5, 1), 0.6, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	
	# Lampu kota futuristik menyala terang serentak menyambut energi normal
	for lamp in lamps:
		if is_instance_valid(lamp):
			tween.interpolate_property(lamp, "modulate", Color(1, 1, 1, 1), Color(1.6, 2.4, 3.0, 1), 0.4, Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.start()
	yield(get_tree().create_timer(0.4), "timeout")
	
	for lamp in lamps:
		if is_instance_valid(lamp):
			tween.interpolate_property(lamp, "modulate", Color(1.6, 2.4, 3.0, 1), Color(1.15, 1.25, 1.35, 1), 0.5, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	tween.start()
	yield(get_tree().create_timer(0.5), "timeout")

# Animasi K-41RO robotik mengangguk puas
func animasi_k4iro_selesai():
	if not is_instance_valid(npc_k4iro):
		return
	var base_pos = npc_k4iro.position
	var base_scale = Vector2(0.42, 0.42)
	
	if is_instance_valid(robot_monitor) and robot_monitor.texture != tex_tab_normal:
		var st_stab = stabilkan_energi_k4iro()
		if st_stab is GDScriptFunctionState and st_stab.is_valid():
			yield(st_stab, "completed")
		
	# Gerakan konfirmasi robotik (pegas tegas)
	tween.interpolate_property(npc_k4iro, "position:y", base_pos.y, base_pos.y - 15.0, 0.15, Tween.TRANS_QUAD, Tween.EASE_OUT)
	tween.interpolate_property(npc_k4iro, "scale", base_scale, Vector2(0.40, 0.45), 0.15, Tween.TRANS_QUAD, Tween.EASE_OUT)
	tween.start()
	yield(get_tree().create_timer(0.15), "timeout")
	
	tween.interpolate_property(npc_k4iro, "position:y", base_pos.y - 15.0, base_pos.y, 0.18, Tween.TRANS_BOUNCE, Tween.EASE_OUT)
	tween.interpolate_property(npc_k4iro, "scale", Vector2(0.40, 0.45), base_scale, 0.18, Tween.TRANS_SINE, Tween.EASE_IN)
	tween.start()
	yield(get_tree().create_timer(0.18), "timeout")

# Animasi Elio: Reaksi tenang dan dingin — anggukan kepala halus (nod) tanda apresiasi tanpa lompat
func animasi_elio_selesai():
	if not is_instance_valid(npc_elio):
		return
	var base_pos = npc_elio.position
	var base_scale = Vector2(0.42, 0.42)
	
	# Anggukan kepala tenang / elegan ke bawah sedikit (3-4 pixel) tanda setuju secara dingin
	tween.interpolate_property(npc_elio, "position:y", base_pos.y, base_pos.y + 4.0, 0.25, Tween.TRANS_QUAD, Tween.EASE_OUT)
	tween.interpolate_property(npc_elio, "scale", base_scale, Vector2(0.425, 0.415), 0.25, Tween.TRANS_QUAD, Tween.EASE_OUT)
	tween.start()
	yield(get_tree().create_timer(0.28), "timeout")
	
	# Kembali tegak dengan tenang
	tween.interpolate_property(npc_elio, "position:y", base_pos.y + 4.0, base_pos.y, 0.25, Tween.TRANS_QUAD, Tween.EASE_IN_OUT)
	tween.interpolate_property(npc_elio, "scale", Vector2(0.425, 0.415), base_scale, 0.25, Tween.TRANS_QUAD, Tween.EASE_IN_OUT)
	tween.start()
	yield(get_tree().create_timer(0.25), "timeout")

# ==============================================================================
# PENYELESAIAN NPC & CUTSCENE GATEKEEPER
# ==============================================================================

func _on_npc_dialog_selesai(key_dialog: String):
	if key_dialog in ["npc_agcl", "npc_k4iro", "npc_elio"]:
		if not (key_dialog in npc_sudah_diajak_bicara):
			npc_sudah_diajak_bicara.append(key_dialog)
			quest_selesai_zona += 1
			print("Quest Future Selesai: ", quest_selesai_zona, "/", total_quest)
			
			# Kunci kontrol selama animasi / cutscene berlangsung, layar TERANG
			Global.cutscene_aktif = true
			Global.dialog_aktif = false
			if is_instance_valid(Global.dim_rect):
				Global.dim_rect.visible = false
			
			if key_dialog == "npc_agcl":
				var st = animasi_agcl_selesai()
				if st is GDScriptFunctionState and st.is_valid():
					yield(st, "completed")
			elif key_dialog == "npc_k4iro":
				var st = animasi_k4iro_selesai()
				if st is GDScriptFunctionState and st.is_valid():
					yield(st, "completed")
			elif key_dialog == "npc_elio":
				var st = animasi_elio_selesai()
				if st is GDScriptFunctionState and st.is_valid():
					yield(st, "completed")
				
			# Jika seluruh quest di zona ini selesai, picu cutscene kemunculan Gatekeeper!
			if quest_selesai_zona >= total_quest:
				yield(get_tree().create_timer(0.8), "timeout")
				mulai_cutscene_gatekeeper()
			else:
				# Jika belum semua selesai, buka kembali kontrol player
				Global.cutscene_aktif = false
				Global.dialog_aktif = false

func mulai_cutscene_gatekeeper():
	if cutscene_berjalan:
		return
	cutscene_berjalan = true
	
	# Layar tetap terang selama cutscene
	Global.cutscene_aktif = true
	Global.dialog_aktif = false
	if is_instance_valid(Global.dim_rect):
		Global.dim_rect.visible = false
	
	if not is_instance_valid(player) or not is_instance_valid(gatekeeper):
		_munculkan_gatekeeper_langsung()
		return
		
	var cam = player.get_node_or_null("Camera2D")
	if not is_instance_valid(cam):
		_munculkan_gatekeeper_langsung()
		return
		
	# 1. Pastikan kamera mulai persis dari posisi player dan lepas ke level teratas
	var start_pos = player.global_position
	cam.set_as_toplevel(true)
	cam.global_position = start_pos
	
	var target_pos = gatekeeper.global_position
	
	# 2. Gerakkan kamera perlahan menuju posisi Gatekeeper di gerbang
	tween.interpolate_property(
		cam, "global_position", 
		start_pos, target_pos, 
		1.6, Tween.TRANS_SINE, Tween.EASE_IN_OUT
	)
	tween.start()
	yield(tween, "tween_completed")
	
	yield(get_tree().create_timer(0.2), "timeout")
	
	# 3. Munculkan Gatekeeper dengan efek fade-in dan scale pop
	gatekeeper.show()
	gatekeeper.modulate.a = 0.0
	var base_gk_scale = Vector2(1.8, 1.8)
	gatekeeper.scale = base_gk_scale * 0.5
	
	tween.interpolate_property(gatekeeper, "modulate:a", 0.0, 1.0, 0.6, Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.interpolate_property(gatekeeper, "scale", gatekeeper.scale, base_gk_scale, 0.6, Tween.TRANS_BACK, Tween.EASE_OUT)
	tween.start()
	yield(tween, "tween_completed")
	
	yield(get_tree().create_timer(0.3), "timeout")
	
	# 4. Panggil dialog Gatekeeper memanggil MC (layar digelapkan di tengah cutscene agar dialog fokus)
	Global.mulai_dialog()
	DialogueManager.show_example_dialogue_balloon("panggil_mc_future", dialog_resource, [self, Global])
	yield(DialogueManager, "dialogue_finished")
	Global.akhiri_dialog()
	
	# 5. KUNCI KEMBALI GERAK & LAYAR TETAP TERANG SAAT KAMERA PULANG
	Global.cutscene_aktif = true
	if is_instance_valid(Global.dim_rect):
		Global.dim_rect.visible = false
		
	# 6. Kembalikan kamera secara halus ke posisi player
	tween.interpolate_property(
		cam, "global_position", 
		target_pos, player.global_position, 
		1.6, Tween.TRANS_SINE, Tween.EASE_IN_OUT
	)
	tween.start()
	yield(tween, "tween_completed")
	
	# 7. Kembalikan kepemilikan kamera ke player & buka kembali kontrol HANYA SETELAH KAMERA SAMPAI
	cam.set_as_toplevel(false)
	cam.position = Vector2.ZERO
	Global.cutscene_aktif = false
	Global.dialog_aktif = false
	cutscene_berjalan = false

func _munculkan_gatekeeper_langsung():
	if is_instance_valid(gatekeeper):
		gatekeeper.show()
		gatekeeper.modulate.a = 1.0
	Global.cutscene_aktif = false
	Global.dialog_aktif = false
	cutscene_berjalan = false

# ==============================================================================
# PENGATURAN KAMERA ZONA
# ==============================================================================

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
