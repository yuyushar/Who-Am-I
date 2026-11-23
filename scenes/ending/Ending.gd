extends Control

onready var background = $Background
onready var char_layer = $CharacterLayer
onready var player_sprite = $CharacterLayer/Player
onready var guide_sprite = $CharacterLayer/Guide
onready var gatekeeper_sprite = $CharacterLayer/Gatekeeper

onready var flashbang_rect = $FlashbangLayer/FlashbangRect
onready var flashbang_dot = $FlashbangLayer/FlashbangDot

onready var personality_panel = $PersonalityLayer/PersonalityPanel
onready var title_label = $PersonalityLayer/PersonalityPanel/TitleLabel
onready var char_texture = $PersonalityLayer/PersonalityPanel/MainHBox/LeftCol/Frame/CharTexture
onready var class_label = $PersonalityLayer/PersonalityPanel/MainHBox/LeftCol/ClassLabel
onready var role_code_label = $PersonalityLayer/PersonalityPanel/MainHBox/LeftCol/RoleCodeLabel

onready var bar_ei = $PersonalityLayer/PersonalityPanel/MainHBox/RightCol/VBoxStats/BarEI
onready var bar_sn = $PersonalityLayer/PersonalityPanel/MainHBox/RightCol/VBoxStats/BarSN
onready var bar_tf = $PersonalityLayer/PersonalityPanel/MainHBox/RightCol/VBoxStats/BarTF
onready var bar_jp = $PersonalityLayer/PersonalityPanel/MainHBox/RightCol/VBoxStats/BarJP

onready var desc_label = $PersonalityLayer/PersonalityPanel/MainHBox/RightCol/DescLabel
onready var close_prompt = $PersonalityLayer/PersonalityPanel/ClosePrompt
onready var click_detector = $PersonalityLayer/ClickDetector

onready var tween = $Tween

var hasil_kode: String = ""
var can_close_info: bool = false
var balon_aktif: Node = null
var is_demo_mode: bool = false
var anim_bars_data: Array = []

const DIALOG_ENDING_RAW = """
~ start
Guide: YAY! SELAMAT!!!
Gatekeeper: iya, selamat! Kau sudah menyelesaikan tugasmu
Player: Lalu apa yang selanjutnya aku lakukan
Gatekeeper: Tidak perlu melakukan apapun, kita sudah mendapatkan hasilnya
Player: Huh?
Guide: Semua dunia yang kau lewati sebenarnya untuk mengecek siapa dirimu
Player: Lalu apa yang akan terjadi padaku?
Gatekeeper: Sekarang kita akan melihat hasilnya, [shake rate=20 level=10][redacted][/shake] sudah memberikan hasil pada guide, bisakah kau menunjukkannya?
Guide: Baik! Tahan ya?
do flashbang_mulai()
=> END

~ redacted_speech
[Redacted]: [shake rate=28 level=13]Selamat {{player_name}}, kau sudah menyelesaikan trials ku[/shake]
[Redacted]: [shake rate=28 level=13]Semoga kita bertemu lagi dengan ending yang berbeda[/shake]
do kembali_ke_menu_utama()
=> END
"""

var ending_resource: Resource = null

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	Global.dialog_aktif = true
	Global.fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Global.putar_bgm_worldvoid()
	
	# Parse dialog resource
	ending_resource = DialogueManager.get_resource_from_text(DIALOG_ENDING_RAW)
	
	# Sembunyikan elemen flashbang dan informasi MBTI di awal
	flashbang_rect.visible = false
	flashbang_dot.visible = false
	personality_panel.visible = false
	close_prompt.visible = false
	click_detector.visible = false
	
	click_detector.connect("pressed", self, "_on_click_detector_pressed")
	
	# Cek apakah pemain datang dari gameplay atau langsung membuka scene Ending untuk testing
	var total_poin = Global.poin_E + Global.poin_I + Global.poin_S + Global.poin_N + Global.poin_T + Global.poin_F + Global.poin_J + Global.poin_P
	if total_poin == 0:
		# Mode demo/preview langsung: Gunakan preset ISTJ (Inspector) lengkap persis referensi
		is_demo_mode = true
		hasil_kode = "ISTJ"
		# JANGAN simpan ke mbti_collection agar file save tidak terisi otomatis saat testing scene
	else:
		is_demo_mode = false
		hasil_kode = Global.hitung_hasil_mbti()
		Global.simpan_koleksi_mbti(hasil_kode)
		Global.hapus_save_progres() # Hapus save state sementara karena run telah tuntas
	
	# Siapkan data stat MBTI di UI
	_siapkan_data_personality()
	
	# Fade in layar awal jika layar sedang gelap
	if Global.fade_rect.modulate.a > 0.05:
		var st = Global.fade_in(1.2)
		if st is GDScriptFunctionState:
			yield(st, "completed")
	Global.fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Mulai percakapan ending
	tampilkan_dialog("start")

func _process(_delta):
	# Efek melayang halus karakter di dalam void
	var t = OS.get_ticks_msec() * 0.002
	if is_instance_valid(player_sprite):
		player_sprite.position.y = 380.0 + sin(t * 1.2) * 4.0
	if is_instance_valid(guide_sprite) and guide_sprite.visible:
		guide_sprite.position.y = 340.0 + sin(t * 1.5) * 5.0
	if is_instance_valid(gatekeeper_sprite) and gatekeeper_sprite.visible:
		gatekeeper_sprite.position.y = 340.0 + sin(t * 1.1 + 1.0) * 4.0

func tampilkan_dialog(title_name: String):
	if is_instance_valid(balon_aktif):
		balon_aktif.queue_free()
		balon_aktif = null
		
	var baris_dialog = yield(DialogueManager.get_next_dialogue_line(title_name, ending_resource, [self, Global]), "completed")
	
	if baris_dialog != null:
		balon_aktif = load("res://addons/dialogue_manager/example_balloon/example_balloon.tscn").instance()
		balon_aktif.dialogue_line = baris_dialog
		balon_aktif.dialogue_resource = ending_resource
		add_child(balon_aktif)
		balon_aktif.connect("actioned", self, "tampilkan_dialog")
	else:
		balon_aktif = null

func flashbang_mulai():
	call_deferred("_jalankan_flashbang_sequence")

func _jalankan_flashbang_sequence():
	if is_instance_valid(balon_aktif):
		balon_aktif.queue_free()
		balon_aktif = null
		
	# 1. Titik putih di tengah menyebar ke seluruh layar
	flashbang_dot.visible = true
	flashbang_dot.rect_scale = Vector2(0.01, 0.01)
	flashbang_dot.modulate.a = 1.0
	
	tween.stop_all()
	# Dot membesar dari titik kecil ke lingkaran raksasa menutup layar (diperlambat 0.3s)
	tween.interpolate_property(flashbang_dot, "rect_scale", Vector2(0.01, 0.01), Vector2(60.0, 60.0), 0.85, Tween.TRANS_EXPO, Tween.EASE_IN)
	tween.start()
	yield(tween, "tween_all_completed")
	
	# Layar penuh putih pekat
	flashbang_rect.visible = true
	flashbang_rect.modulate.a = 1.0
	flashbang_dot.visible = false
	
	# Tunggu 1.5 detik sesuai instruksi skenario
	yield(get_tree().create_timer(1.5), "timeout")
	
	# 2. Balik ke void tapi SENDIRIAN (Guide & Gatekeeper hilang)
	guide_sprite.visible = false
	gatekeeper_sprite.visible = false
	
	# Fade out layar putih
	tween.interpolate_property(flashbang_rect, "modulate:a", 1.0, 0.0, 1.2, Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.start()
	yield(tween, "tween_all_completed")
	flashbang_rect.visible = false
	
	yield(get_tree().create_timer(0.4), "timeout")
	
	# 3. Munculkan informasi diri (MBTI Result)
	_munculkan_informasi_diri()

func _siapkan_data_personality():
	var data = Global.get_mbti_info(hasil_kode)
	var role = data.get("role", "Inspector")
	var cls = data.get("class", "Leader")
	var desc = data.get("desc", "")
	
	class_label.text = "Class " + cls
	role_code_label.text = role + " : " + hasil_kode
	desc_label.text = desc
	desc_label.percent_visible = 0.0 # Disembunyikan di awal untuk animasi ngetik (typewriter)
	
	# Load foto karakter dari aset/MBTI Chars/<KODE>.png
	var char_path = "res://aset/MBTI Chars/" + hasil_kode + ".png"
	if ResourceLoader.exists(char_path):
		char_texture.texture = load(char_path)
		
	anim_bars_data.clear()
	
	var p_i = 2 if is_demo_mode else Global.poin_I
	var p_e = 1 if is_demo_mode else Global.poin_E
	var p_s = 2 if is_demo_mode else Global.poin_S
	var p_n = 0 if is_demo_mode else Global.poin_N
	var p_t = 3 if is_demo_mode else Global.poin_T
	var p_f = 0 if is_demo_mode else Global.poin_F
	var p_j = 2 if is_demo_mode else Global.poin_J
	var p_p = 1 if is_demo_mode else Global.poin_P
	
	# Konfigurasi Stat Bar (INTROVERT vs EXTROVERT, SENSOR vs INTUITIVES, THINKERS vs FEELERS, JUDGERS vs PERCEIVERS)
	_setup_stat_bar(bar_ei, "INTROVERT", p_i, p_e, "EXTROVERT", Color(0.15, 0.75, 0.38, 1.0))
	_setup_stat_bar(bar_sn, "SENSOR", p_s, p_n, "INTUITIVES", Color(0.0, 0.72, 0.82, 1.0))
	_setup_stat_bar(bar_tf, "THINKERS", p_t, p_f, "FEELERS", Color(0.62, 0.28, 0.78, 1.0))
	_setup_stat_bar(bar_jp, "JUDGERS", p_j, p_p, "PERCEIVERS", Color(0.85, 0.42, 0.18, 1.0))

func _setup_stat_bar(bar_node: Control, label_kiri: String, poin_kiri: int, poin_kanan: int, label_kanan: String, color_accent: Color):
	if bar_node == null:
		return
	var lbl_l = bar_node.get_node_or_null("LabelKiri")
	var lbl_num = bar_node.get_node_or_null("LabelSkor")
	var lbl_r = bar_node.get_node_or_null("LabelKanan")
	var fill_rect = bar_node.get_node_or_null("ProgressBar/FillRect")
	var bg_rect = bar_node.get_node_or_null("ProgressBar")
	
	if is_instance_valid(lbl_l):
		lbl_l.text = label_kiri
	if is_instance_valid(lbl_num):
		lbl_num.text = str(poin_kiri) + " / " + str(poin_kanan)
	if is_instance_valid(lbl_r):
		lbl_r.text = label_kanan
		
	if is_instance_valid(bg_rect):
		bg_rect.color = Color(0.16, 0.18, 0.24, 0.95) # Abu-abu netral sebagai dasar
		
	# Tentukan pemenang dan skala warna 0-3
	var pemenang_kiri = true
	var skor_tampil = poin_kiri
	
	if poin_kanan > poin_kiri:
		pemenang_kiri = false
		skor_tampil = poin_kanan
	elif poin_kiri == poin_kanan:
		# Jika poin seimbang, tentukan arah sesuai huruf kode MBTI akhir yang didapat
		if ("E" in hasil_kode and label_kanan.begins_with("EXTRO")) or \
		   ("N" in hasil_kode and label_kanan.begins_with("INTUI")) or \
		   ("F" in hasil_kode and label_kanan.begins_with("FEEL")) or \
		   ("P" in hasil_kode and label_kanan.begins_with("PERCE")):
			pemenang_kiri = false
			skor_tampil = poin_kanan
		else:
			pemenang_kiri = true
			skor_tampil = poin_kiri
			
	# Skala 0 - 3 sesuai permintaan:
	# 0 = Tidak ada warna sama sekali (abu-abu doang)
	# 1 = 1/3 warna (33.3%)
	# 2 = 2/3 warna (66.6%)
	# 3 = 3/3 warna penuh (100%)
	var target_ratio = 0.0
	if skor_tampil <= 0:
		target_ratio = 0.0
	elif skor_tampil == 1:
		target_ratio = 1.0 / 3.0
	elif skor_tampil == 2:
		target_ratio = 2.0 / 3.0
	else:
		target_ratio = 1.0
		
	if is_instance_valid(fill_rect):
		fill_rect.margin_left = 0
		fill_rect.margin_top = 0
		fill_rect.margin_right = 0
		fill_rect.margin_bottom = 0
		fill_rect.color = color_accent
		
		# Set posisi awal sebelum di-tween (mulai dari rasio 0.0)
		if target_ratio <= 0.0:
			fill_rect.visible = false
		else:
			fill_rect.visible = true
			if pemenang_kiri:
				fill_rect.anchor_left = 0.0
				fill_rect.anchor_right = 0.0
			else:
				fill_rect.anchor_left = 1.0
				fill_rect.anchor_right = 1.0
				
		anim_bars_data.append({
			"fill_rect": fill_rect,
			"pemenang_kiri": pemenang_kiri,
			"target_ratio": target_ratio
		})

func _munculkan_informasi_diri():
	# Sembunyikan karakter void agar tidak tumpang tindih dengan teks hasil MBTI
	if is_instance_valid(player_sprite):
		player_sprite.visible = false
	if is_instance_valid(guide_sprite):
		guide_sprite.visible = false
	if is_instance_valid(gatekeeper_sprite):
		gatekeeper_sprite.visible = false
		
	personality_panel.visible = true
	personality_panel.modulate.a = 0.0
	desc_label.percent_visible = 0.0
	
	tween.stop_all()
	# Slide & fade-in panel informasi kepribadian
	tween.interpolate_property(personality_panel, "modulate:a", 0.0, 1.0, 0.65, Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.interpolate_property(personality_panel, "rect_scale", Vector2(0.96, 0.96), Vector2(1.0, 1.0), 0.65, Tween.TRANS_BACK, Tween.EASE_OUT)
	
	# Animasi pengisian stat bar dari 0 ke target skor secara dinamis
	for b in anim_bars_data:
		var f_rect = b["fill_rect"]
		var is_left = b["pemenang_kiri"]
		var tr = b["target_ratio"]
		if tr > 0.0 and is_instance_valid(f_rect):
			if is_left:
				tween.interpolate_property(f_rect, "anchor_right", 0.0, tr, 0.85, Tween.TRANS_CUBIC, Tween.EASE_OUT)
			else:
				tween.interpolate_property(f_rect, "anchor_left", 1.0, 1.0 - tr, 0.85, Tween.TRANS_CUBIC, Tween.EASE_OUT)
				
	# Efek mengetik (typewriter) pada deskripsi kepribadian
	tween.interpolate_property(desc_label, "percent_visible", 0.0, 1.0, 1.6, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	
	tween.start()
	yield(tween, "tween_all_completed")
	
	# Tunggu 3 detik setelah informasi berhasil dimuat sepenuhnya sesuai instruksi skenario
	yield(get_tree().create_timer(3.0), "timeout")
	
	# Tampilkan tombol/prompt "Tekan di mana pun untuk melanjutkan"
	close_prompt.visible = true
	close_prompt.modulate.a = 0.0
	click_detector.visible = true
	can_close_info = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	Global.fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	tween.interpolate_property(close_prompt, "modulate:a", 0.0, 1.0, 0.4, Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.start()

func _input(event):
	if can_close_info:
		var is_mouse_click = event is InputEventMouseButton and event.is_pressed() and event.button_index == BUTTON_LEFT
		var is_key = event is InputEventKey and event.is_pressed() and not event.is_echo() and (event.scancode == KEY_SPACE or event.scancode == KEY_ENTER or event.scancode == KEY_F)
		if is_mouse_click or is_key:
			get_tree().set_input_as_handled()
			_on_click_detector_pressed()

func _on_click_detector_pressed():
	if not can_close_info:
		return
	can_close_info = false
	click_detector.visible = false
	close_prompt.visible = false
	Global.play_sfx_button()
	_fade_out_personality_dan_redacted()

func _fade_out_personality_dan_redacted():
	tween.stop_all()
	# Fade out personality info ke hitam
	tween.interpolate_property(personality_panel, "modulate:a", 1.0, 0.0, 0.6, Tween.TRANS_SINE, Tween.EASE_IN)
	tween.start()
	yield(tween, "tween_all_completed")
	personality_panel.visible = false
	
	yield(get_tree().create_timer(0.4), "timeout")
	
	# REDACTED ngomong dengan getaran intens sedang-tinggi
	tampilkan_dialog("redacted_speech")

func kembali_ke_menu_utama():
	yield(get_tree().create_timer(0.5), "timeout")
	Global.reset_game_total()
	Global.pindah_ke_scene("res://scenes/main_menu/MainMenu.tscn")
