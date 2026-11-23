extends Node2D

var dialog_resource = load("res://dialogues/skycity_j_p.tres")

# Tekstur ekspresi / status NPC World 4
var tex_myra1 = preload("res://aset/World 4/World/MY_NPC.png")
var tex_myra2 = preload("res://aset/World 4/World/MY_NPC2.png")
var tex_ronnie1 = preload("res://aset/World 4/World/Rn_NPC.png")
var tex_ronnie2 = preload("res://aset/World 4/World/Rn_NPC2.png")

onready var ysort_node = $YSort if has_node("YSort") else self
onready var gatekeeper = $YSort/GatekeeperNPC if has_node("YSort/GatekeeperNPC") else get_node_or_null("GatekeeperNPC")
onready var player = $YSort/Player if has_node("YSort/Player") else get_node_or_null("Player")
onready var npc_captain = $YSort/NPC1 if has_node("YSort/NPC1") else null
onready var npc_myra = $YSort/NPC2 if has_node("YSort/NPC2") else null
onready var npc_ronnie = $YSort/NPC3_TieBreaker if has_node("YSort/NPC3_TieBreaker") else null
onready var bgm = $AudioStreamPlayer if has_node("AudioStreamPlayer") else get_node_or_null("BGM")

# Barang kargo kargo milik Captain C di dermaga
onready var c_items = [
	get_node_or_null("YSort/C_items"),
	get_node_or_null("YSort/C_items2"),
	get_node_or_null("YSort/C_items2_2"),
	get_node_or_null("YSort/C_items3"),
	get_node_or_null("YSort/C_items4")
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

	# Setup sistem AreaTindih (Foreground Occlusion) menggunakan Polygon2D
	inisialisasi_area_tindih()
	
	# Setup status visual awal objek & NPC
	inisialisasi_status_objek()
	
	# Atur batas kamera sesuai ReferenceRect BatasKamera
	atur_batas_kamera()

	# Pastikan guider langsung berada di posisi player (tidak terbang dari jauh saat masuk zona)
	if is_instance_valid(player) and player.has_method("teleport_guider_ke_player"):
		player.teleport_guider_ke_player()

	# Hubungkan signal dari sistem dialog
	if not DialogueManager.is_connected("dialogue_finished", self, "_on_dialog_global_selesai"):
		DialogueManager.connect("dialogue_finished", self, "_on_dialog_global_selesai")

	# Hubungkan signal dialog_selesai dari seluruh NPC di dalam YSort
	var search_node = get_node_or_null("YSort")
	var children = search_node.get_children() if search_node != null else get_children()
	for child in children:
		if child.has_signal("dialog_selesai") and child != gatekeeper:
			child.connect("dialog_selesai", self, "_on_npc_dialog_selesai")

	# Sembunyikan Gatekeeper di awal permainan
	if is_instance_valid(gatekeeper):
		gatekeeper.hide()

	if Global.sedang_muat_save:
		inisialisasi_status_save()
	else:
		jalankan_prolog()

func inisialisasi_status_save():
	quest_selesai_zona = Global.quest_selesai
	npc_sudah_diajak_bicara = []
	if Global.captain_selesai:
		npc_sudah_diajak_bicara.append("npc_captain")
	if Global.myra_selesai:
		npc_sudah_diajak_bicara.append("npc_myra")
	if Global.ronnie_selesai:
		npc_sudah_diajak_bicara.append("npc_ronnie")
		
	inisialisasi_status_objek()
	
	if quest_selesai_zona >= total_quest and is_instance_valid(gatekeeper):
		gatekeeper.modulate.a = 1.0
		gatekeeper.show()

# Dictionary node tindih & trigger untuk kontrol depth dinamis
var tindih_nodes = {}
var active_triggers = {}
const CONDITIONAL_TINDIH_NAMES = ["Middle6", "Middle5", "Middle4", "Middle3", "Middle2", "Middle", "Right", "Top", "Top2"]

# ==============================================================================
# SISTEM FOREGROUND OCCLUSION (AREA TINDIH & TRIGGER ACCTINDIH)
# ==============================================================================
# 1. Objek umum di AreaTindih (Middle, Bottom, Left) tetap aktif sebagai overlay jika tidak ada di CONDITIONAL_TINDIH_NAMES.
# 2. Objek bersyarat diaktifkan (nyala) hanya jika player memicu trigger di ACCTindih:
#    - Middle 6 nyala kalau: Box ketriger
#    - Middle 5 kalau: Box2 ketriger
#    - Middle 3 kalau: Box3 ketriger
#    - Middle 2 kalau: Box4 ketriger
#    - Right kalau: Flag3 atau Flag4 ketriger
#    - Top kalau: Flag ketriger
#    - Top2 kalau: Flag2 ketriger
#    - Middle 4 kalau: Fence2 ketriger
#    - Middle kalau: Fence ketriger
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
		
	# Wadah overlay yang berada pada z_index = 5
	var overlay = Node2D.new()
	overlay.name = "OverlayForeground"
	overlay.z_index = 5
	overlay.transform = bg.transform
	add_child(overlay)
	
	tindih_nodes.clear()
	
	# Salin seluruh child CollisionPolygon2D dari AreaTindih ke Polygon2D overlay
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
			
			# Objek kondisional dinonaktifkan di awal sampai player masuk ke trigger
			if child.name in CONDITIONAL_TINDIH_NAMES:
				poly_node.visible = false
				child.set_deferred("disabled", true)
			else:
				poly_node.visible = true
				child.set_deferred("disabled", false)
				
	# Setup pemicu (triggers) dari ACCTindih
	var acctindih = get_node_or_null("ACCTindih")
	if is_instance_valid(acctindih):
		acctindih.collision_layer = 0
		acctindih.collision_mask = 0
		
		# Buat Area2D pemantau per tiap child shape di ACCTindih
		var trigger_shapes = []
		for c in acctindih.get_children():
			if c is CollisionPolygon2D:
				trigger_shapes.append(c)
				
		for trig_col in trigger_shapes:
			var trig_name = trig_col.name
			var trig_area = Area2D.new()
			trig_area.name = "TrigArea_" + trig_name
			trig_area.collision_layer = 0
			trig_area.collision_mask = 1 # Monitor Player pada layer 1
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
	var is_box = active_triggers.get("Box", false)
	var is_box2 = active_triggers.get("Box2", false)
	var is_box3 = active_triggers.get("Box3", false)
	var is_box4 = active_triggers.get("Box4", false)
	var is_flag = active_triggers.get("Flag", false)
	var is_flag2 = active_triggers.get("Flag2", false)
	var is_flag3_or_4 = active_triggers.get("Flag3", false) or active_triggers.get("Flag4", false)
	var is_fence = active_triggers.get("Fence", false)
	var is_fence2 = active_triggers.get("Fence2", false)
	
	# 2. Middle 6 nyala kalau: Box ketriger
	_set_tindih_state("Middle6", is_box)
	# 3. Middle 5 kalau box2 ketriger
	_set_tindih_state("Middle5", is_box2)
	# 4. Middle 3 kalau box3 ketriger
	_set_tindih_state("Middle3", is_box3)
	# 5. Middle 2 kalau box4 ketriger
	_set_tindih_state("Middle2", is_box4)
	# 6. Right kalau flag3 or flag4 ketriger
	_set_tindih_state("Right", is_flag3_or_4)
	# 7. Top kalau flag ketriger
	_set_tindih_state("Top", is_flag)
	# 8. Top2 kalau flag2 ketriger
	_set_tindih_state("Top2", is_flag2)
	# 9. Middle 4 kalau Fence2 ketriger
	_set_tindih_state("Middle4", is_fence2)
	# 10. Middle kalau Fence ketriger
	_set_tindih_state("Middle", is_fence)

func _set_tindih_state(target_name: String, is_active: bool):
	if tindih_nodes.has(target_name):
		var item = tindih_nodes[target_name]
		if is_instance_valid(item.get("poly")):
			item["poly"].visible = is_active
		if is_instance_valid(item.get("col")):
			item["col"].set_deferred("disabled", not is_active)

# ==============================================================================
# INISIALISASI & STATUS NPC
# ==============================================================================
func inisialisasi_status_objek():
	# Kondisi Kargo Captain C: jika quest sudah selesai, hilangkan kargo karena sudah dimuat ke kapal
	if Global.captain_selesai:
		for item in c_items:
			if is_instance_valid(item):
				item.visible = false
				item.modulate.a = 0.0
				var col = item.get_node_or_null("StaticBody2D/CollisionShape2D")
				if is_instance_valid(col):
					col.set_deferred("disabled", true)
	else:
		for item in c_items:
			if is_instance_valid(item):
				item.visible = true
				item.modulate.a = 1.0
				var col = item.get_node_or_null("StaticBody2D/CollisionShape2D")
				if is_instance_valid(col):
					col.set_deferred("disabled", false)
					
	# Kondisi Myra: ganti tekstur jika sudah selesai quest
	if is_instance_valid(npc_myra):
		var spr = npc_myra.get_node_or_null("Sprite")
		if is_instance_valid(spr):
			spr.texture = tex_myra2 if Global.myra_selesai else tex_myra1
			
	# Kondisi Ronnie: ganti tekstur jika sudah selesai quest
	if is_instance_valid(npc_ronnie):
		var spr = npc_ronnie.get_node_or_null("Sprite")
		if is_instance_valid(spr):
			spr.texture = tex_ronnie2 if Global.ronnie_selesai else tex_ronnie1

func jalankan_prolog():
	if Global.sedang_muat_save:
		return
	if dialog_resource != null and dialog_resource.get("raw_text") != null:
			dialog_resource = DialogueManager.get_resource_from_text(dialog_resource.raw_text)
	if dialog_resource == null or not dialog_resource.titles.has("prologue_skycity"):
		return
	prolog_sedang_berjalan = true
	Global.mulai_dialog()
	yield(get_tree().create_timer(0.2), "timeout")
	DialogueManager.show_example_dialogue_balloon("prologue_skycity", dialog_resource, [self, Global])

func _on_dialog_global_selesai():
	if prolog_sedang_berjalan:
		prolog_sedang_berjalan = false
		Global.periksa_dan_tampilkan_guide_awal()

# ==============================================================================
# CUTSCENE & ANIMASI SKENARIO NPC
# ==============================================================================

# Skenario Captain C (Kargo Kapal Terbang: J = Rapi & Terencana, P = Dinamis & Cepat)
func cutscene_opsi_captain(pilihan: String = "J"):
	if not is_instance_valid(npc_captain):
		return
		
	if is_instance_valid(Global.dim_rect):
		Global.dim_rect.visible = false
		
	var base_scale = Vector2(0.42, 0.42)
	
	# Animasi peti/box kargo Captain C
	for i in range(c_items.size()):
		var item = c_items[i]
		if is_instance_valid(item):
			var orig_pos = item.position
			var offset = Vector2(0, -6) if pilihan == "J" else Vector2(rand_range(-3, 3), -8)
			tween.interpolate_property(item, "position", orig_pos, orig_pos + offset, 0.18 + (i * 0.05), Tween.TRANS_BOUNCE, Tween.EASE_OUT)
			tween.interpolate_property(item, "position", orig_pos + offset, orig_pos, 0.22, Tween.TRANS_BOUNCE, Tween.EASE_IN, 0.18 + (i * 0.05))
	
	# Captain C melompat gembira dengan mantap
	tween.interpolate_property(npc_captain, "scale", base_scale, Vector2(0.39, 0.46), 0.2, Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.interpolate_property(npc_captain, "scale", Vector2(0.39, 0.46), base_scale, 0.2, Tween.TRANS_BOUNCE, Tween.EASE_OUT, 0.2)
	tween.start()
	yield(get_tree().create_timer(0.45), "timeout")

# Skenario Myra (Navigasi Rute Langit: J = Rute Resmi Teruji, P = Jalur Angin Baru)
func cutscene_opsi_myra(_pilihan: String = "J"):
	if not is_instance_valid(npc_myra):
		return
		
	if is_instance_valid(Global.dim_rect):
		Global.dim_rect.visible = false
		
	# Ganti ekspresi Myra ke tex_myra2
	var spr = npc_myra.get_node_or_null("Sprite")
	if is_instance_valid(spr):
		spr.texture = tex_myra2
		
	var base_scale = Vector2(0.42, 0.42)
	var orig_pos = npc_myra.position
	
	# Animasi melayang / levitasi lembut navigator langit
	tween.interpolate_property(npc_myra, "position", orig_pos, orig_pos + Vector2(0, -14), 0.25, Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.interpolate_property(npc_myra, "scale", base_scale, Vector2(0.44, 0.40), 0.25, Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.start()
	yield(get_tree().create_timer(0.25), "timeout")
	
	tween.interpolate_property(npc_myra, "position", orig_pos + Vector2(0, -14), orig_pos, 0.25, Tween.TRANS_SINE, Tween.EASE_IN)
	tween.interpolate_property(npc_myra, "scale", Vector2(0.44, 0.40), base_scale, 0.25, Tween.TRANS_SINE, Tween.EASE_IN)
	tween.start()
	yield(get_tree().create_timer(0.25), "timeout")

# Skenario Ronnie (Boarding Penumpang: J = Kloter Terjadwal, P = Mengalir Fleksibel)
func cutscene_opsi_ronnie(pilihan: String = "J"):
	if not is_instance_valid(npc_ronnie):
		return
		
	if is_instance_valid(Global.dim_rect):
		Global.dim_rect.visible = false
		
	# Ganti ekspresi Ronnie ke tex_ronnie2
	var spr = npc_ronnie.get_node_or_null("Sprite")
	if is_instance_valid(spr):
		spr.texture = tex_ronnie2
		
	var base_scale = Vector2(0.42, 0.42)
	
	# Animasi lega & ceria Ronnie (squash & stretch dan hop)
	tween.interpolate_property(npc_ronnie, "scale", base_scale, Vector2(0.45, 0.38), 0.18, Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.interpolate_property(npc_ronnie, "rotation_degrees", 0.0, -4.0 if pilihan == "J" else 4.0, 0.18, Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.start()
	yield(get_tree().create_timer(0.18), "timeout")
	
	tween.interpolate_property(npc_ronnie, "scale", Vector2(0.45, 0.38), base_scale, 0.2, Tween.TRANS_BOUNCE, Tween.EASE_OUT)
	tween.interpolate_property(npc_ronnie, "rotation_degrees", -4.0 if pilihan == "J" else 4.0, 0.0, 0.2, Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.start()
	yield(get_tree().create_timer(0.2), "timeout")

# ==============================================================================
# LOGIKA PENYELESAIAN DIALOG & KEMUNCULAN GATEKEEPER
# ==============================================================================
func _on_npc_dialog_selesai(key_dialog: String):
	if key_dialog in ["npc_captain", "npc_myra", "npc_ronnie"]:
		if not (key_dialog in npc_sudah_diajak_bicara):
			npc_sudah_diajak_bicara.append(key_dialog)
			quest_selesai_zona += 1
			print("Quest Sky City Selesai: ", quest_selesai_zona, "/", total_quest)
			
			# Kunci kontrol selama reaksi selesai dialog berlangsung, layar TERANG
			Global.cutscene_aktif = true
			Global.dialog_aktif = false
			if is_instance_valid(Global.dim_rect):
				Global.dim_rect.visible = false
			
			if key_dialog == "npc_captain":
				var st = animasi_pindah_kargo_captain()
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

# Animasi barang-barang kargo Captain C melayang ke atas kapal (pindah ke kapal) lalu menghilang
func animasi_pindah_kargo_captain():
	for i in range(c_items.size()):
		var item = c_items[i]
		if is_instance_valid(item):
			var orig_pos = item.position
			var target_pos = orig_pos + Vector2(0, -60) # Terangkat ke atas ke arah kapal
			var durasi = 0.55
			var delay = i * 0.12
			
			tween.interpolate_property(item, "position", orig_pos, target_pos, durasi, Tween.TRANS_QUAD, Tween.EASE_OUT, delay)
			tween.interpolate_property(item, "modulate:a", 1.0, 0.0, durasi * 0.8, Tween.TRANS_SINE, Tween.EASE_IN, delay + 0.15)
			
			var col = item.get_node_or_null("StaticBody2D/CollisionShape2D")
			if is_instance_valid(col):
				col.set_deferred("disabled", true)
				
	tween.start()
	yield(get_tree().create_timer(c_items.size() * 0.12 + 0.65), "timeout")
	
	for item in c_items:
		if is_instance_valid(item):
			item.visible = false

func mulai_cutscene_gatekeeper():
	if cutscene_berjalan:
		return
	cutscene_berjalan = true
	
	# Layar tetap terang selama cutscene kamera
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
	gatekeeper.scale = Vector2(0.0, 0.0)
	
	tween.interpolate_property(gatekeeper, "modulate:a", 0.0, 1.0, 0.6, Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.interpolate_property(gatekeeper, "scale", Vector2(0.0, 0.0), base_gk_scale, 0.7, Tween.TRANS_BACK, Tween.EASE_OUT)
	tween.start()
	yield(tween, "tween_completed")
	
	yield(get_tree().create_timer(0.4), "timeout")
	
	# 4. Jalankan dialog panggilan Gatekeeper ke MC (layar digelapkan di tengah cutscene agar dialog fokus)
	Global.mulai_dialog()
	DialogueManager.show_example_dialogue_balloon("panggil_mc_skycity", dialog_resource, [self, Global])
	yield(DialogueManager, "dialogue_finished")
	Global.akhiri_dialog()
	
	# 5. KUNCI KEMBALI GERAK & LAYAR TERANG KEMBALI SAAT KAMERA PULANG
	Global.cutscene_aktif = true
	if is_instance_valid(Global.dim_rect):
		Global.dim_rect.visible = false
		
	# 6. Kembalikan kamera secara halus ke Player
	tween.interpolate_property(
		cam, "global_position", 
		target_pos, player.global_position, 
		1.4, Tween.TRANS_SINE, Tween.EASE_IN_OUT
	)
	tween.start()
	yield(tween, "tween_completed")
	
	# 7. Pasang kembali kamera ke dalam koordinat lokal player & buka kontrol pemain
	cam.set_as_toplevel(false)
	cam.position = Vector2.ZERO
	
	cutscene_berjalan = false
	Global.cutscene_aktif = false
	Global.dialog_aktif = false

func _munculkan_gatekeeper_langsung():
	if is_instance_valid(gatekeeper):
		gatekeeper.show()
		gatekeeper.modulate.a = 1.0
	cutscene_berjalan = false
	Global.mulai_dialog()
	DialogueManager.show_example_dialogue_balloon("panggil_mc_skycity", dialog_resource, [self, Global])

# ==============================================================================
# BATAS KAMERA
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
