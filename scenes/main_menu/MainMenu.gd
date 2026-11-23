extends Control

onready var btn_commence = $MenuContainer/CommenceButton
onready var btn_persist = $MenuContainer/PersistButton
onready var btn_directory = $MenuContainer/DirectorySlot/DirectoryButton
onready var lock_badge = $MenuContainer/DirectorySlot/LockBadge
onready var shard_container = $MenuContainer/DirectorySlot/ShardContainer
onready var btn_guide = $MenuContainer/GuideButton
onready var btn_about = $MenuContainer/AboutButton
onready var btn_terminate = $MenuContainer/TerminateButton
onready var tween = $Tween

const LOCK_TEXT_WAVE = "[wave amp=18 freq=5][color=#ff4747][ LOCKED ][/color][/wave]"
const LOCK_TEXT_SHAKE = "[shake rate=25 level=12][color=#ffdd44][ LOCKED ][/color][/shake]"

var confirm_modal = null
var guide_modal = null
var about_modal = null
var is_intro_berjalan: bool = false
var intro_layer: CanvasLayer = null

func _ready():
	_periksa_status_persist()
	_periksa_status_directory()
	_siapkan_confirm_modal()
	_siapkan_guide_modal()
	_siapkan_about_modal()
	
	if not Global.intro_sudah_tampil:
		Global.intro_sudah_tampil = true
		_jalankan_intro_loading()
	else:
		Global.putar_bgm_worldvoid()

func _siapkan_confirm_modal():
	var modal_res = load("res://scenes/ui/ConfirmModal.tscn")
	if modal_res:
		confirm_modal = modal_res.instance()
		add_child(confirm_modal)

func _siapkan_guide_modal():
	var guide_res = load("res://scenes/ui/GuideModal.tscn")
	if guide_res:
		guide_modal = guide_res.instance()
		add_child(guide_modal)

func _siapkan_about_modal():
	var about_res = load("res://scenes/ui/AboutModal.tscn")
	if about_res:
		about_modal = about_res.instance()
		add_child(about_modal)

func _jalankan_intro_loading():
	is_intro_berjalan = true
	
	intro_layer = CanvasLayer.new()
	intro_layer.layer = 150
	add_child(intro_layer)
	
	var bg = ColorRect.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color(0.00784314, 0.00784314, 0.0156863, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	intro_layer.add_child(bg)
	
	var center = CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_layer.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGN_CENTER
	vbox.add_constant_override("separation", 22)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(vbox)
	
	var logo_rect = TextureRect.new()
	logo_rect.expand = true
	logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo_rect.rect_min_size = Vector2(300, 190)
	logo_rect.rect_pivot_offset = Vector2(150, 95)
	if ResourceLoader.exists("res://logo.png"):
		logo_rect.texture = load("res://logo.png")
	logo_rect.modulate.a = 0.0
	logo_rect.rect_scale = Vector2(0.92, 0.92)
	vbox.add_child(logo_rect)
	
	var lbl = Label.new()
	lbl.text = "[ INITIALIZING CONSCIOUSNESS... ]"
	lbl.align = Label.ALIGN_CENTER
	var bold_font = load("res://addons/dialogue_manager/example_balloon/Open_Sans/OpenSans-Bold.ttf")
	if bold_font:
		var df = DynamicFont.new()
		df.font_data = bold_font
		df.size = 15
		df.use_filter = true
		lbl.add_font_override("font", df)
	lbl.add_color_override("font_color", Color(0.45, 0.82, 1.0, 1.0))
	lbl.modulate.a = 0.0
	vbox.add_child(lbl)
	
	var bar_bg = ColorRect.new()
	bar_bg.rect_min_size = Vector2(260, 3)
	bar_bg.color = Color(0.12, 0.16, 0.25, 0.8)
	bar_bg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(bar_bg)
	
	var bar_fill = ColorRect.new()
	bar_fill.rect_size = Vector2(0, 3)
	bar_fill.color = Color(0.25, 0.85, 1.0, 0.95)
	bar_bg.add_child(bar_fill)
	
	var intro_tween = Tween.new()
	intro_tween.name = "IntroTween"
	intro_layer.add_child(intro_tween)
	
	yield(get_tree().create_timer(0.35), "timeout")
	if not is_instance_valid(intro_layer) or not is_intro_berjalan:
		return
		
	# 1. Fade-in logo & text
	intro_tween.interpolate_property(logo_rect, "modulate:a", 0.0, 1.0, 0.70, Tween.TRANS_SINE, Tween.EASE_OUT)
	intro_tween.interpolate_property(logo_rect, "rect_scale", Vector2(0.92, 0.92), Vector2(1.0, 1.0), 0.70, Tween.TRANS_BACK, Tween.EASE_OUT)
	intro_tween.interpolate_property(lbl, "modulate:a", 0.0, 1.0, 0.50, Tween.TRANS_SINE, Tween.EASE_OUT)
	intro_tween.start()
	yield(intro_tween, "tween_all_completed")
	if not is_instance_valid(intro_layer) or not is_intro_berjalan:
		return
		
	# 2. Preload seluruh aset penting secara bertahap (mencegah lag / crash saat dimainkan)
	var daftar_preload = [
		"res://scenes/prologue/Prologue.tscn",
		"res://scenes/directory/Directory.tscn",
		"res://scenes/ui/GuideModal.tscn",
		"res://scenes/ui/AboutModal.tscn",
		"res://scenes/ui/ConfirmModal.tscn",
		"res://dialogues/village_e_i.tres",
		"res://dialogues/modern_s_n.tres",
		"res://dialogues/future_t_f.tres",
		"res://dialogues/skycity_j_p.tres",
		"res://scenes/zone/Zone01.tscn",
		"res://scenes/zone/Zone02.tscn",
		"res://scenes/zone/Zone03.tscn",
		"res://scenes/zone/Zone04.tscn"
	]
	
	lbl.text = "[ LOADING ASSETS & PROTOCOLS... ]"
	var total_items = float(daftar_preload.size())
	var max_bar_width = 260.0
	
	for i in range(daftar_preload.size()):
		var res_path = daftar_preload[i]
		if ResourceLoader.exists(res_path):
			ResourceLoader.load(res_path)
		var target_width = ((i + 1) / total_items) * max_bar_width
		intro_tween.interpolate_property(bar_fill, "rect_size:x", bar_fill.rect_size.x, target_width, 0.08, Tween.TRANS_QUAD, Tween.EASE_OUT)
		intro_tween.start()
		yield(get_tree(), "idle_frame")
		yield(get_tree().create_timer(0.04), "timeout")
		if not is_instance_valid(intro_layer) or not is_intro_berjalan:
			return
			
	# 3. Synchronized State
	lbl.text = "[ CONSCIOUSNESS SYNCHRONIZED ]"
	lbl.add_color_override("font_color", Color(0.35, 1.0, 0.65, 1.0))
	
	yield(get_tree().create_timer(0.45), "timeout")
	if not is_instance_valid(intro_layer) or not is_intro_berjalan:
		return
		
	_selesaikan_intro()

func _selesaikan_intro():
	if not is_intro_berjalan:
		return
	is_intro_berjalan = false
	
	Global.putar_bgm_worldvoid(1.2)
	
	if is_instance_valid(intro_layer):
		var intro_tween = intro_layer.get_node_or_null("IntroTween")
		if is_instance_valid(intro_tween):
			intro_tween.stop_all()
			for c in intro_layer.get_children():
				if c is Control:
					intro_tween.interpolate_property(c, "modulate:a", c.modulate.a, 0.0, 0.45, Tween.TRANS_SINE, Tween.EASE_OUT)
			intro_tween.start()
			yield(intro_tween, "tween_all_completed")
		if is_instance_valid(intro_layer):
			intro_layer.queue_free()

func _periksa_status_persist():
	if is_instance_valid(btn_persist):
		var ada_save = Global.ada_save_progres()
		if ada_save:
			btn_persist.set_button_disabled(false)
			btn_persist.set_display_text("> Persist")
			btn_persist.set_colors(Color(0.96, 0.82, 0.15, 1.0), Color(1.0, 0.95, 0.45, 1.0))
		else:
			btn_persist.set_button_disabled(true)
			btn_persist.set_display_text("> Persist (No Data)")
			btn_persist.set_colors(Color(0.45, 0.45, 0.45, 0.5), Color(0.45, 0.45, 0.45, 0.5), Color(0.45, 0.45, 0.45, 0.5))

func _periksa_status_directory():
	if not is_instance_valid(btn_directory) or not is_instance_valid(lock_badge):
		return
		
	var mbti_count = Global.mbti_terbuka.size()
	
	if mbti_count > 0:
		if not Global.directory_notif_dilihat:
			_jalankan_animasi_unlock_pertama()
		else:
			lock_badge.visible = false
			btn_directory.set_button_disabled(false)
			btn_directory.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		lock_badge.visible = true
		lock_badge.bbcode_text = LOCK_TEXT_WAVE
		lock_badge.modulate = Color(1.0, 1.0, 1.0, 1.0)
		btn_directory.set_button_disabled(true)

func _jalankan_animasi_unlock_pertama():
	lock_badge.visible = true
	lock_badge.bbcode_text = LOCK_TEXT_WAVE
	lock_badge.modulate = Color(1.0, 1.0, 1.0, 1.0)
	btn_directory.set_button_disabled(true)
	
	yield(get_tree().create_timer(0.4), "timeout")
	
	lock_badge.bbcode_text = LOCK_TEXT_SHAKE
	tween.interpolate_property(lock_badge, "modulate", Color(1.0, 1.0, 1.0, 1.0), Color(1.5, 1.2, 0.4, 1.0), 0.35, Tween.TRANS_SINE)
	tween.interpolate_property(lock_badge, "rect_scale", Vector2(1.0, 1.0), Vector2(1.2, 1.2), 0.35, Tween.TRANS_BACK, Tween.EASE_OUT)
	tween.start()
	yield(tween, "tween_completed")
	
	_ciptakan_efek_pecah()
	lock_badge.visible = false
	
	tween.interpolate_property(btn_directory, "modulate", Color(0.4, 0.9, 1.0, 0.5), Color(0.3, 1.0, 1.0, 1.0), 0.3, Tween.TRANS_BOUNCE, Tween.EASE_OUT)
	tween.interpolate_property(btn_directory, "modulate", Color(0.3, 1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0, 1.0), 0.3, Tween.TRANS_SINE, Tween.EASE_IN_OUT, 0.3)
	tween.start()
	yield(tween, "tween_completed")
	
	btn_directory.set_button_disabled(false)
	
	Global.directory_notif_dilihat = true
	Global.simpan_koleksi_ke_file()

func _ciptakan_efek_pecah():
	if not is_instance_valid(shard_container):
		return
		
	var fragmen_teks = ["[", "L", "O", "C", "K", "E", "D", "]"]
	var base_x = lock_badge.rect_position.x if is_instance_valid(lock_badge) else 10.0
	var base_y = lock_badge.rect_position.y if is_instance_valid(lock_badge) else -14.0
	
	for i in range(fragmen_teks.size()):
		var char_lbl = Label.new()
		char_lbl.text = fragmen_teks[i]
		char_lbl.add_font_override("font", lock_badge.get_font("normal_font"))
		char_lbl.add_color_override("font_color", Color(1.0, 0.35, 0.35, 1.0))
		char_lbl.rect_position = Vector2(base_x + (i * 18.0), base_y)
		shard_container.add_child(char_lbl)
		
		var arah_x = (i - 3.5) * rand_range(25.0, 45.0)
		var arah_y = rand_range(-80.0, -140.0)
		var target_pos = char_lbl.rect_position + Vector2(arah_x, arah_y)
		var target_rot = rand_range(-120.0, 120.0)
		var durasi = rand_range(0.5, 0.75)
		
		var t = Tween.new()
		char_lbl.add_child(t)
		t.interpolate_property(char_lbl, "rect_position", char_lbl.rect_position, target_pos, durasi, Tween.TRANS_QUAD, Tween.EASE_OUT)
		t.interpolate_property(char_lbl, "rect_rotation", 0.0, target_rot, durasi, Tween.TRANS_SINE)
		t.interpolate_property(char_lbl, "modulate:a", 1.0, 0.0, durasi, Tween.TRANS_EXPO, Tween.EASE_IN)
		t.start()
		t.connect("tween_all_completed", char_lbl, "queue_free")

func _on_CommenceButton_pressed():
	if Global.ada_save_progres():
		if is_instance_valid(confirm_modal):
			confirm_modal.tampilkan(
				"Terdapat skenario petualangan yang belum diselesaikan.\nYakin ingin menimpanya dan memulai petualangan baru?",
				"> Sure",
				"> Pass",
				"MEMULAI ULANG",
				funcref(self, "_eksekusi_commence")
			)
			return
	_eksekusi_commence()

func _eksekusi_commence():
	Global.reset_game_total()
	Global.pindah_ke_scene("res://scenes/prologue/Prologue.tscn")

func _on_PersistButton_pressed():
	if Global.ada_save_progres():
		Global.muat_game_progres()
	else:
		_shake_node(btn_persist)

func _on_DirectoryButton_pressed():
	if Global.mbti_terbuka.size() > 0:
		Global.pindah_ke_scene("res://scenes/directory/Directory.tscn")
	else:
		_shake_node(lock_badge)

func _on_GuideButton_pressed():
	if is_instance_valid(guide_modal):
		guide_modal.buka()

func _on_AboutButton_pressed():
	if is_instance_valid(about_modal):
		about_modal.buka()

func _shake_node(target_node: Control):
	if is_instance_valid(tween) and is_instance_valid(target_node) and target_node.visible:
		var orig_pos = target_node.rect_position
		tween.stop(target_node, "rect_position:x")
		tween.interpolate_property(target_node, "rect_position:x", orig_pos.x, orig_pos.x + 8.0, 0.05, Tween.TRANS_SINE)
		tween.interpolate_property(target_node, "rect_position:x", orig_pos.x + 8.0, orig_pos.x - 8.0, 0.1, Tween.TRANS_SINE, Tween.EASE_IN_OUT, 0.05)
		tween.interpolate_property(target_node, "rect_position:x", orig_pos.x - 8.0, orig_pos.x, 0.05, Tween.TRANS_SINE, Tween.EASE_OUT, 0.15)
		tween.start()

func _on_TerminateButton_pressed():
	if is_instance_valid(confirm_modal):
		confirm_modal.tampilkan(
			"Apakah kamu yakin ingin mengakhiri sesi dan keluar dari permainan?",
			"> Sure",
			"> Pass",
			"KELUAR PERMAINAN",
			funcref(self, "_eksekusi_quit")
		)
		return
	_eksekusi_quit()

func _eksekusi_quit():
	get_tree().quit()

func _input(event):
	if is_intro_berjalan:
		# Jangan izinkan skip intro loading dengan tombol keyboard atau mouse click (tunggu hingga selesai preload)
		if (event is InputEventKey and event.is_pressed()) or (event is InputEventMouseButton and event.is_pressed()):
			get_tree().set_input_as_handled()
			return
			
	if is_instance_valid(guide_modal) and guide_modal.is_terbuka:
		return
	if is_instance_valid(about_modal) and about_modal.is_terbuka:
		return
	if is_instance_valid(confirm_modal) and confirm_modal.is_terbuka:
		return
