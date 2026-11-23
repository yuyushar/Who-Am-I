extends Node

var player_name = ""

# --- DAFTAR MAP MODULAR ---
# Zona aktif adalah zona yang sudah memiliki skenario & aset lengkap
var daftar_map = [
	{"path": "res://scenes/zone/Zone01.tscn", "dimensi": "E_I", "aktif": true},
	{"path": "res://scenes/zone/Zone02.tscn", "dimensi": "S_N", "aktif": true},
	{"path": "res://scenes/zone/Zone03.tscn", "dimensi": "T_F", "aktif": true},
	{"path": "res://scenes/zone/Zone04.tscn", "dimensi": "J_P", "aktif": true}
]

var dimensi_selesai = [] 
var zona_dikunjungi = [] 

# --- MANAJEMEN ZONA MODULAR & TRACKER SISA ZONA ---
var max_zona: int = 4
var zona_ke: int = 1
var sisa_zona: int = 3 

# --- STATUS ZONA AKTIF ---
var quest_selesai = 0
var skor_kiri = 0  
var skor_kanan = 0 

# --- POIN MBTI TOTAL ---
var poin_E = 0
var poin_I = 0
var poin_S = 0
var poin_N = 0
var poin_T = 0
var poin_F = 0
var poin_J = 0
var poin_P = 0

var mbti_result = ""
var quest_npc1 = 0
var quest_npc2 = 0

# --- KOMPONEN FADE OTOMATIS ---
var canvas_layer: CanvasLayer
var fade_rect: ColorRect
var tween: Tween
var mbti_terbuka = []
var mbti_baru_terbuka = false
var data_mbti: Dictionary = {}
var dialog_aktif = false
var cutscene_aktif = false setget set_cutscene_aktif
var dim_layer: CanvasLayer
var dim_rect: ColorRect

# --- MANAJEMEN CURSOR & PAUSE MENU ---
var pause_menu_terbuka: bool = false
var pilihan_dialog_aktif: bool = false
var guide_modal_terbuka: bool = false
var about_modal_terbuka: bool = false
var guide_awal_sudah_muncul: bool = false
var guide_modal_global: CanvasLayer = null
var _last_desired_mouse_mode: int = -1
var pause_menu: CanvasLayer = null

# --- MANAJEMEN SAVE & RESUME PROGRES PETUALANGAN ---
const SAVE_PATH_PROGRESS = "user://game_progress.save"
var posisi_spawn_sementara: Vector2 = Vector2.ZERO
var sedang_muat_save: bool = false
var intro_sudah_tampil: bool = false

# --- MANAJEMEN BGM & SFX GLOBAL ---
var bgm_global: AudioStreamPlayer = null
const BGM_WORLDVOID = preload("res://aset/Music/worldvoid_music.ogg")

var sfx_button_click: AudioStream = preload("res://aset/sfx/button-click.mp3")
var sfx_button_hover: AudioStream = null
var sfx_locked_button: AudioStream = null
var sfx_encounter: AudioStream = null
var sfx_dialog_blip: AudioStream = null
var sfx_dialog_redacted: AudioStream = null
var sfx_player: AudioStreamPlayer = null
var sfx_hover_player: AudioStreamPlayer = null
var sfx_dialog_player: AudioStreamPlayer = null
var sfx_encounter_player: AudioStreamPlayer = null
var _last_dialog_sfx_time: float = 0.0
var _last_button_sfx_time: float = 0.0
var _last_hover_sfx_time: float = 0.0

var current_focus_control: Control = null

func _on_gui_focus_changed(control: Control):
	current_focus_control = control

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	muat_koleksi_dari_file()
	muat_data_mbti_json()
	_inisialisasi_pause_menu()
	_init_audio_system()
	get_tree().connect("node_added", self, "_on_node_added_global")
	# Membuat lapisan layar hitam paling depan (di atas semua scene)
	canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	add_child(canvas_layer)
	
	fade_rect = ColorRect.new()
	fade_rect.color = Color.black
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Menyesuaikan layar penuh
	fade_rect.rect_min_size = Vector2(2000, 2000) 
	fade_rect.modulate.a = 0.0 # Transparan di awal
	canvas_layer.add_child(fade_rect)
	
	tween = Tween.new()
	add_child(tween)
	dim_layer = CanvasLayer.new()
	dim_layer.layer = 90 # Di bawah dialog, di atas player/map
	add_child(dim_layer)
	
	dim_rect = ColorRect.new()
	dim_rect.color = Color(0, 0, 0, 0.6) # Hitam transparan 60%
	dim_rect.anchor_left = 0.0
	dim_rect.anchor_top = 0.0
	dim_rect.anchor_right = 1.0
	dim_rect.anchor_bottom = 1.0
	dim_rect.rect_min_size = Vector2(3000, 3000) # Pastikan menutupi seluruh layar
	dim_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim_rect.visible = false
	dim_layer.add_child(dim_rect)
	
	if not DialogueManager.is_connected("dialogue_started", self, "_on_dialogue_mulai"):
		DialogueManager.connect("dialogue_started", self, "_on_dialogue_mulai")
	if not DialogueManager.is_connected("dialogue_finished", self, "_on_dialogue_beres"):
		DialogueManager.connect("dialogue_finished", self, "_on_dialogue_beres")
	
	var vp = get_viewport()
	if is_instance_valid(vp) and not vp.is_connected("gui_focus_changed", self, "_on_gui_focus_changed"):
		vp.connect("gui_focus_changed", self, "_on_gui_focus_changed")
	
	update_mouse_cursor()

func _process(_delta):
	update_mouse_cursor()

func _input(event):
	# 1. Tombol ESC di dalam zone petualangan membuka / menutup Pause Menu
	if event is InputEventKey and event.is_pressed() and not event.is_echo() and event.scancode == KEY_ESCAPE:
		if is_in_gameplay_zone():
			# JIKA SEDANG DIALOG / CUTSCENE dan Pause Menu sedang tutup, DILARANG membuka pause menu!
			if not pause_menu_terbuka and is_dialogue_playing():
				get_tree().set_input_as_handled()
				return
			toggle_pause_menu()
			get_tree().set_input_as_handled()
			return

	# 2. Tombol ENTER: jangan izinkan memencet tombol UI (Button) di luar dialog!
	# Kecuali di dalam dialog (memilih respon / lanjut dialog) atau saat mengetik teks di LineEdit (input nama)
	if event is InputEventKey and (event.scancode == KEY_ENTER or event.scancode == KEY_KP_ENTER):
		if not is_dialogue_playing():
			var focus_owner: Control = null
			if is_instance_valid(dim_rect):
				focus_owner = dim_rect.get_focus_owner()
			elif is_instance_valid(current_focus_control):
				focus_owner = current_focus_control
				
			var is_text_input = is_instance_valid(focus_owner) and (focus_owner is LineEdit or focus_owner is TextEdit)
			if not is_text_input:
				if is_instance_valid(focus_owner) and focus_owner is BaseButton:
					focus_owner.release_focus()
				get_tree().set_input_as_handled()

func is_in_gameplay_zone() -> bool:
	var cur = get_tree().current_scene
	if not is_instance_valid(cur) or cur.filename == "":
		return false
	var fn = cur.filename.to_lower()
	# Hanya zone petualangan/eksplorasi yang menyembunyikan kursor saat berjalan bebas
	return ("zone" in fn) and not ("prologue" in fn) and not ("ending" in fn)

func update_mouse_cursor():
	var desired = Input.MOUSE_MODE_VISIBLE
	# Mouse disembunyikan HANYA saat player sedang berjalan di gameplay zone normal (tanpa dialog, tanpa pause, tanpa guide modal, tanpa pilihan respon)
	if is_in_gameplay_zone() and not pause_menu_terbuka and not guide_modal_terbuka and not about_modal_terbuka and not dialog_aktif and not pilihan_dialog_aktif:
		desired = Input.MOUSE_MODE_HIDDEN
		
	if Input.get_mouse_mode() != desired or _last_desired_mouse_mode != desired:
		_last_desired_mouse_mode = desired
		Input.set_mouse_mode(desired)

func _init_audio_system():
	if bgm_global == null:
		bgm_global = AudioStreamPlayer.new()
		bgm_global.name = "BGMGlobal"
		bgm_global.pause_mode = Node.PAUSE_MODE_PROCESS
		add_child(bgm_global)
		
	if sfx_player == null:
		sfx_player = AudioStreamPlayer.new()
		sfx_player.name = "SFXButtonPlayer"
		sfx_player.pause_mode = Node.PAUSE_MODE_PROCESS
		add_child(sfx_player)
		
	if sfx_locked_button == null and ResourceLoader.exists("res://aset/sfx/locked_button.mp3"):
		sfx_locked_button = load("res://aset/sfx/locked_button.mp3")
		
	if sfx_encounter_player == null:
		sfx_encounter_player = AudioStreamPlayer.new()
		sfx_encounter_player.name = "SFXEncounterPlayer"
		sfx_encounter_player.pause_mode = Node.PAUSE_MODE_PROCESS
		add_child(sfx_encounter_player)
		
	if sfx_encounter == null and ResourceLoader.exists("res://aset/sfx/encounter-sfx.ogg"):
		sfx_encounter = load("res://aset/sfx/encounter-sfx.ogg")
		
	if sfx_dialog_player == null:
		sfx_dialog_player = AudioStreamPlayer.new()
		sfx_dialog_player.name = "SFXDialogPlayer"
		sfx_dialog_player.pause_mode = Node.PAUSE_MODE_PROCESS
		sfx_dialog_player.volume_db = -12.0
		_setup_dialog_blip_stream()
		add_child(sfx_dialog_player)
		
	if sfx_hover_player == null:
		sfx_hover_player = AudioStreamPlayer.new()
		sfx_hover_player.name = "SFXHoverPlayer"
		sfx_hover_player.pause_mode = Node.PAUSE_MODE_PROCESS
		sfx_hover_player.volume_db = -2.0
		if sfx_button_hover == null and ResourceLoader.exists("res://aset/sfx/button_hover.wav"):
			sfx_button_hover = load("res://aset/sfx/button_hover.wav")
			if "loop_mode" in sfx_button_hover:
				sfx_button_hover.loop_mode = 0
		if sfx_button_hover != null:
			sfx_hover_player.stream = sfx_button_hover
		add_child(sfx_hover_player)

func _setup_dialog_blip_stream():
	if ResourceLoader.exists("res://aset/sfx/dialog_blip.wav"):
		sfx_dialog_blip = load("res://aset/sfx/dialog_blip.wav")
		if "loop_mode" in sfx_dialog_blip:
			sfx_dialog_blip.loop_mode = 0
			
	if ResourceLoader.exists("res://aset/sfx/dialog_redacted.wav"):
		sfx_dialog_redacted = load("res://aset/sfx/dialog_redacted.wav")
		if "loop_mode" in sfx_dialog_redacted:
			sfx_dialog_redacted.loop_mode = 0
			
	if sfx_dialog_blip != null:
		sfx_dialog_player.stream = sfx_dialog_blip
	else:
		var candidates = [
			"res://aset/sfx/dialog_blip.ogg",
			"res://aset/sfx/dialog_blip.mp3",
			"res://aset/sfx/dialog.wav"
		]
		for p in candidates:
			if ResourceLoader.exists(p):
				sfx_dialog_player.stream = load(p)
				return

func _on_node_added_global(node: Node):
	if node is Button:
		if not node.is_connected("mouse_entered", self, "_on_button_hovered_global"):
			node.connect("mouse_entered", self, "_on_button_hovered_global", [node])

func _on_button_hovered_global(btn: Button):
	if is_instance_valid(btn) and btn.is_visible_in_tree() and not btn.disabled:
		play_sfx_hover()

func putar_bgm_worldvoid(durasi_fade: float = 1.0):
	_init_audio_system()
	if is_instance_valid(bgm_global):
		if bgm_global.stream == BGM_WORLDVOID and bgm_global.playing and bgm_global.volume_db > -10.0:
			# Lagu worldvoid sudah berputar dengan volume normal, biarkan lanjut tanpa restart!
			return
		bgm_global.stream = BGM_WORLDVOID
		fade_in_bgm(bgm_global, durasi_fade, 0.0)

func hentikan_bgm_global(durasi_fade: float = 1.0):
	if is_instance_valid(bgm_global) and bgm_global.playing:
		fade_out_bgm_saat_ini(durasi_fade)
		# Matikan bgm_global perlahan
		tween.interpolate_property(bgm_global, "volume_db", bgm_global.volume_db, -80.0, durasi_fade, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
		tween.start()
		yield(get_tree().create_timer(durasi_fade), "timeout")
		if is_instance_valid(bgm_global) and bgm_global.volume_db <= -70.0:
			bgm_global.stop()

func play_sfx_button():
	_init_audio_system()
	var now = OS.get_ticks_msec() / 1000.0
	if now - _last_button_sfx_time < 0.08:
		return
	_last_button_sfx_time = now
	
	if is_instance_valid(sfx_player) and sfx_button_click != null:
		if "loop" in sfx_button_click:
			sfx_button_click.loop = false
		sfx_player.stream = sfx_button_click
		sfx_player.pitch_scale = rand_range(0.92, 1.12) # Pitch random agar tidak monoton
		sfx_player.play()

func play_sfx_locked():
	_init_audio_system()
	var now = OS.get_ticks_msec() / 1000.0
	if now - _last_button_sfx_time < 0.08:
		return
	_last_button_sfx_time = now
	
	if sfx_locked_button == null and ResourceLoader.exists("res://aset/sfx/locked_button.mp3"):
		sfx_locked_button = load("res://aset/sfx/locked_button.mp3")
		
	if is_instance_valid(sfx_player):
		if sfx_locked_button != null:
			if "loop" in sfx_locked_button:
				sfx_locked_button.loop = false
			sfx_player.stream = sfx_locked_button
			sfx_player.pitch_scale = rand_range(0.96, 1.06)
			sfx_player.play()
		elif sfx_button_click != null:
			# Fallback jika audio belum terload
			sfx_player.stream = sfx_button_click
			sfx_player.pitch_scale = 0.65
			sfx_player.play()

func play_sfx_encounter():
	_init_audio_system()
	if sfx_encounter_player == null:
		sfx_encounter_player = AudioStreamPlayer.new()
		sfx_encounter_player.name = "SFXEncounterPlayer"
		sfx_encounter_player.pause_mode = Node.PAUSE_MODE_PROCESS
		add_child(sfx_encounter_player)
		
	if sfx_encounter == null and ResourceLoader.exists("res://aset/sfx/encounter-sfx.ogg"):
		sfx_encounter = load("res://aset/sfx/encounter-sfx.ogg")
		
	if is_instance_valid(sfx_encounter_player) and sfx_encounter != null:
		if "loop" in sfx_encounter:
			sfx_encounter.loop = false
		sfx_encounter_player.stream = sfx_encounter
		sfx_encounter_player.volume_db = -3.0
		sfx_encounter_player.pitch_scale = rand_range(0.97, 1.03)
		sfx_encounter_player.play()

func play_sfx_hover():
	_init_audio_system()
	var now = OS.get_ticks_msec() / 1000.0
	if now - _last_hover_sfx_time < 0.04:
		return
	_last_hover_sfx_time = now
	
	if is_instance_valid(sfx_hover_player) and sfx_hover_player.stream != null:
		sfx_hover_player.pitch_scale = rand_range(0.97, 1.05)
		sfx_hover_player.play()

func play_sfx_dialog(is_redacted: bool = false):
	_init_audio_system()
	var now = OS.get_ticks_msec() / 1000.0
	if now - _last_dialog_sfx_time < 0.045:
		return
	_last_dialog_sfx_time = now
	
	if is_instance_valid(sfx_dialog_player):
		if is_redacted:
			if sfx_dialog_redacted != null:
				sfx_dialog_player.stream = sfx_dialog_redacted
			elif sfx_dialog_blip != null:
				sfx_dialog_player.stream = sfx_dialog_blip
			sfx_dialog_player.volume_db = -8.0
			sfx_dialog_player.pitch_scale = rand_range(0.75, 0.92) # Suara deep / berat untuk Redacted
		else:
			if sfx_dialog_blip != null:
				sfx_dialog_player.stream = sfx_dialog_blip
			sfx_dialog_player.volume_db = -13.0
			sfx_dialog_player.pitch_scale = rand_range(0.96, 1.08) # Suara cerah / normal
			
		if sfx_dialog_player.stream != null:
			sfx_dialog_player.play()

func set_pilihan_dialog_aktif(val: bool):
	pilihan_dialog_aktif = val
	update_mouse_cursor()

func _inisialisasi_pause_menu():
	if pause_menu == null:
		var scn = load("res://scenes/ui/PauseMenu.tscn")
		if scn != null:
			pause_menu = scn.instance()
			add_child(pause_menu)

func toggle_pause_menu():
	if not pause_menu_terbuka and is_dialogue_playing():
		return
	if pause_menu == null:
		_inisialisasi_pause_menu()
	if is_instance_valid(pause_menu):
		if pause_menu_terbuka:
			pause_menu.tutup()
		else:
			pause_menu.buka()

# --- MODAL PETUNJUK KONTROL (GUIDE MODAL GLOBAL) ---
func _inisialisasi_guide_modal_global():
	if guide_modal_global == null:
		var scn = load("res://scenes/ui/GuideModal.tscn")
		if scn != null:
			guide_modal_global = scn.instance()
			add_child(guide_modal_global)

func buka_guide_modal_global():
	if guide_modal_global == null:
		_inisialisasi_guide_modal_global()
	if is_instance_valid(guide_modal_global):
		guide_modal_global.buka()

func periksa_dan_tampilkan_guide_awal():
	# Muncul hanya 1x saja di awal Zona Pertama per permainan
	if guide_awal_sudah_muncul:
		return
	if zona_ke != 1:
		return
	if sedang_muat_save:
		return
		
	guide_awal_sudah_muncul = true
	# Beri sedikit jeda setelah dialog guider tertutup agar transisi terasa halus
	yield(get_tree().create_timer(0.35), "timeout")
	buka_guide_modal_global()

# --- PORTRAIT DIALOG TRACKER ---
var dialog_left_char: String = ""
var dialog_right_char: String = ""
var dialog_last_speaker_side: String = ""
var _portrait_cache: Dictionary = {}

func reset_dialog_speakers():
	dialog_left_char = ""
	dialog_right_char = ""
	dialog_last_speaker_side = ""

func get_character_key(char_name: String) -> String:
	var clean = char_name.strip_edges().to_lower()
	if clean == "":
		return ""
	if clean in ["guide", "guider", "g"]:
		return "g"
	if clean in ["gatekeeper", "gate keeper", "gk"]:
		return "gk"
	if clean in ["player", "p"]:
		return "p"
	if clean in ["annie", "a"]:
		return "a"
	if clean in ["kaleva", "kalaeva", "k"]:
		return "k"
	if clean in ["raka", "r"]:
		return "r"
	if clean in ["zana", "z"]:
		return "z"
	if clean in ["moxie", "m"]:
		return "m"
	if clean in ["arif", "ar"]:
		return "ar"
	if clean in ["ag_cl", "agcl", "sw"]:
		return "sw"
	if clean in ["k-41ro", "k4iro", "kairo", "ro"]:
		return "ro"
	if clean in ["elio", "e"]:
		return "e"
	if clean in ["captain", "captain c", "c"]:
		return "c"
	if clean in ["myra", "my"]:
		return "my"
	if clean in ["ronnie", "rn"]:
		return "rn"
	if player_name != "" and clean == player_name.strip_edges().to_lower():
		return "p"
	return clean

func _find_portrait_path(char_key: String, state: String) -> String:
	var upper_key = char_key.to_upper()
	var lower_key = char_key.to_lower()
	var cap_key = char_key.capitalize()
	var candidates = [
		# Folder aset/World 1/Dialog (A_dialog_1.png, K_dialog_1.png, R_dialog_1.png)
		"res://aset/World 1/Dialog/" + upper_key + "_dialog_" + state + ".png",
		"res://aset/World 1/Dialog/" + lower_key + "_dialog_" + state + ".png",
		"res://aset/World 1/Dialog/" + cap_key + "_dialog_" + state + ".png",
		"res://aset/World 1/Dialog/" + upper_key + "_dialog" + state + ".png",
		"res://aset/World 1/Dialog/" + lower_key + "_dialog" + state + ".png",
		# Folder aset/World 2/Dialog (AR_dialog_1.png, M_dialog_1.png, Z_dialog_1.png)
		"res://aset/World 2/Dialog/" + upper_key + "_dialog_" + state + ".png",
		"res://aset/World 2/Dialog/" + lower_key + "_dialog_" + state + ".png",
		"res://aset/World 2/Dialog/" + cap_key + "_dialog_" + state + ".png",
		"res://aset/World 2/Dialog/" + upper_key + "_dialog" + state + ".png",
		"res://aset/World 2/Dialog/" + lower_key + "_dialog" + state + ".png",
		# Folder aset/World 3/Dialog (E_dialog1.png, RO_dialog1.png, SW_dialog1.png)
		"res://aset/World 3/Dialog/" + upper_key + "_dialog" + state + ".png",
		"res://aset/World 3/Dialog/" + lower_key + "_dialog" + state + ".png",
		"res://aset/World 3/Dialog/" + cap_key + "_dialog" + state + ".png",
		"res://aset/World 3/Dialog/" + upper_key + "_dialog_" + state + ".png",
		"res://aset/World 3/Dialog/" + lower_key + "_dialog_" + state + ".png",
		# Folder aset/World 4/Dialog (C_dialog1.png, My_dialog1.png, Rn_dialog1.png)
		"res://aset/World 4/Dialog/" + upper_key + "_dialog" + state + ".png",
		"res://aset/World 4/Dialog/" + cap_key + "_dialog" + state + ".png",
		"res://aset/World 4/Dialog/" + lower_key + "_dialog" + state + ".png",
		"res://aset/World 4/Dialog/" + upper_key + "_dialog_" + state + ".png",
		"res://aset/World 4/Dialog/" + cap_key + "_dialog_" + state + ".png",
		"res://aset/World 4/Dialog/" + lower_key + "_dialog_" + state + ".png",
		# Folder aset/dialog (g_dialog1.png, p_dialog1.png, gk_dialog1.png)
		"res://aset/dialog/" + lower_key + "_dialog" + state + ".png",
		"res://aset/dialog/" + upper_key + "_dialog" + state + ".png",
		"res://aset/dialog/" + lower_key + "_dialog_" + state + ".png",
		"res://aset/dialog/" + upper_key + "_dialog_" + state + ".png"
	]
	for p in candidates:
		if ResourceLoader.exists(p):
			return p
	return ""

# Mengecek apakah karakter sedang diam dan belum ada file _dialog_2 di disk
# Jika true, sistem dialog akan menggelapkan karakter melalui modulate (fallback)
func is_portrait_fallback_dimmed(char_key: String, is_talking: bool) -> bool:
	if is_talking:
		return false
	var state2_path = _find_portrait_path(char_key, "2")
	return state2_path == ""

func get_portrait_texture(char_key: String, is_talking: bool) -> Texture:
	if char_key == "":
		return null
	var state = "1" if is_talking else "2"
	var cache_key = char_key + "_" + state
	if _portrait_cache.has(cache_key):
		return _portrait_cache[cache_key]
	
	var path = _find_portrait_path(char_key, state)
	# Jika butuh state 2 (diam) tapi file _dialog_2 belum ada di folder, gunakan file state 1
	if path == "" and state == "2":
		path = _find_portrait_path(char_key, "1")
		
	var tex = null
	if path != "" and ResourceLoader.exists(path):
		tex = load(path)
	_portrait_cache[cache_key] = tex
	return tex

func scan_second_speaker(resource, start_id: String, first_char: String) -> String:
	if resource == null or not ("lines" in resource) or resource.lines == null:
		return ""
	var first_key = get_character_key(first_char)
	var curr_id = start_id
	var visited = {}
	var steps = 0
	while curr_id != "" and curr_id != "end" and curr_id != null and steps < 40:
		if visited.has(curr_id):
			break
		visited[curr_id] = true
		steps += 1
		
		if not resource.lines.has(curr_id):
			break
		var data = resource.lines.get(curr_id)
		if data == null:
			break
		
		if data.has("character"):
			var c = String(data.character).strip_edges()
			if c != "":
				var c_key = get_character_key(c)
				if c.to_lower() != first_char.to_lower() and (c_key == "" or c_key != first_key):
					return c
		
		if data.has("next_id") and data.next_id != "":
			curr_id = data.next_id.split(",")[0]
		elif data.has("next_conditional_id"):
			curr_id = data.next_conditional_id.split(",")[0]
		else:
			break
	return ""

func update_dialog_speakers(current_char: String, resource = null, next_id: String = "") -> Dictionary:
	var clean = current_char.strip_edges()
	var char_key = get_character_key(clean)
	var active_side = ""
	
	if clean != "":
		if dialog_left_char == "":
			# Inisialisasi posisi awal kedua karakter yang terlibat
			var second = ""
			if resource != null and next_id != "":
				second = scan_second_speaker(resource, next_id, clean)
			
			var clean_is_player = (char_key == "p")
			var second_key = get_character_key(second)
			var second_is_player = (second_key == "p")
			
			# JIKA PERCAKAPAN MELIBATKAN MC (PLAYER):
			# MC HARUS SELALU BERADA DI SISI KIRI (dialog_left_char),
			# dan lawan bicaranya (NPC) selalu di SISI KANAN (dialog_right_char).
			if clean_is_player:
				dialog_left_char = clean
				dialog_right_char = second
				active_side = "left"
				dialog_last_speaker_side = "left"
			elif second_is_player:
				# NPC bicara pertama: MC tetap di sisi kiri! NPC diletakkan di sisi kanan!
				dialog_left_char = second
				dialog_right_char = clean
				active_side = "right"
				dialog_last_speaker_side = "right"
			else:
				# Percakapan antar NPC (misal Guide & Gatekeeper)
				dialog_left_char = clean
				dialog_right_char = second
				active_side = "left"
				dialog_last_speaker_side = "left"
		else:
			var left_key = get_character_key(dialog_left_char)
			var right_key = get_character_key(dialog_right_char)
			
			if (char_key != "" and char_key == left_key) or clean.to_lower() == dialog_left_char.to_lower():
				active_side = "left"
				dialog_last_speaker_side = "left"
			elif (char_key != "" and char_key == right_key) or clean.to_lower() == dialog_right_char.to_lower():
				active_side = "right"
				dialog_last_speaker_side = "right"
			else:
				if dialog_right_char == "":
					dialog_right_char = clean
					active_side = "right"
					dialog_last_speaker_side = "right"
				else:
					if dialog_last_speaker_side == "left":
						dialog_right_char = clean
						active_side = "right"
						dialog_last_speaker_side = "right"
					else:
						dialog_left_char = clean
						active_side = "left"
						dialog_last_speaker_side = "left"
	else:
		active_side = ""
		
	return {
		"left_char": dialog_left_char,
		"right_char": dialog_right_char,
		"active_side": active_side
	}

func is_dialogue_playing() -> bool:
	if cutscene_aktif:
		return true
	if dialog_aktif:
		return true
	if pilihan_dialog_aktif:
		return true
	if DialogueManager.is_dialogue_running:
		return true
	var tree = get_tree()
	if is_instance_valid(tree) and tree.get_nodes_in_group("dialogue_balloon").size() > 0:
		return true
	return false

func set_cutscene_aktif(val: bool) -> void:
	cutscene_aktif = val
	if cutscene_aktif:
		# Jika cutscene aktif, pastikan layar TERANG (matikan efek peredup hitam)
		# Layar gelap HANYA boleh muncul saat teks dialog sedang aktif di layar
		if is_instance_valid(dim_rect) and not DialogueManager.is_dialogue_running:
			dim_rect.visible = false

# Fungsi untuk dipanggil saat dialog mulai
func mulai_dialog():
	dialog_aktif = true
	# Saat dialog muncul (baik gameplay biasa maupun di tengah cutscene), gelapkan layar agar dialog fokus
	if is_instance_valid(dim_rect):
		dim_rect.visible = true
	reset_dialog_speakers()

func akhiri_dialog():
	dialog_aktif = false
	if is_instance_valid(dim_rect):
		dim_rect.visible = false
	reset_dialog_speakers()

func _on_dialogue_mulai():
	dialog_aktif = true
	# Saat dialog aktif, layarnya diredupkan/digelapkan
	if is_instance_valid(dim_rect):
		dim_rect.visible = true
	reset_dialog_speakers()

# Otomatis dipanggil oleh DialogueManager saat dialog END
func _on_dialogue_beres():
	yield(get_tree(), "idle_frame")
	var tree = get_tree()
	if is_instance_valid(tree):
		if tree.get_nodes_in_group("dialogue_balloon").size() > 0:
			return
	if DialogueManager.is_dialogue_running:
		return
	dialog_aktif = false
	if is_instance_valid(dim_rect):
		dim_rect.visible = false
	reset_dialog_speakers()
# --- FUNGSI EFEK FADE ---
func fade_out(durasi = 1.0):
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP # Blokir input saat layar hitam
	tween.interpolate_property(fade_rect, "modulate:a", fade_rect.modulate.a, 1.0, durasi, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	tween.start()
	yield(tween, "tween_completed")

func fade_in(durasi = 1.0):
	tween.interpolate_property(fade_rect, "modulate:a", fade_rect.modulate.a, 0.0, durasi, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	tween.start()
	yield(tween, "tween_completed")
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

# Status dialog NPC per zona
var raka_selesai = false
var kaleva_selesai = false
var annie_selesai = false
var kaleva_opsi_papan = false

var zana_selesai = false
var moxie_selesai = false
var arif_selesai = false
var zana_opsi_denah = false
var agcl_selesai = false
var k4iro_selesai = false
var elio_selesai = false
var captain_selesai = false
var myra_selesai = false
var ronnie_selesai = false

func selesaikan_npc(nama_npc: String):
	match nama_npc:
		"raka": raka_selesai = true
		"kaleva": kaleva_selesai = true
		"annie": annie_selesai = true
		"zana": zana_selesai = true
		"moxie": moxie_selesai = true
		"arif": arif_selesai = true
		"agcl", "ag_cl", "sw": agcl_selesai = true
		"k4iro", "k-41ro", "ro": k4iro_selesai = true
		"elio", "e": elio_selesai = true
		"captain", "captain c", "c": captain_selesai = true
		"myra", "my": myra_selesai = true
		"ronnie", "rn": ronnie_selesai = true

func reset_tracker_zona():
	cutscene_aktif = false
	quest_selesai = 0
	skor_kiri = 0
	skor_kanan = 0
	raka_selesai = false
	kaleva_selesai = false
	annie_selesai = false
	kaleva_opsi_papan = false
	zana_selesai = false
	moxie_selesai = false
	arif_selesai = false
	zana_opsi_denah = false
	agcl_selesai = false
	k4iro_selesai = false
	elio_selesai = false
	captain_selesai = false
	myra_selesai = false
	ronnie_selesai = false
	update_progres_zona()
func acak_skenario_npc():
	randomize()
	quest_npc1 = randi() % 3
	quest_npc2 = randi() % 3

func tambah_poin(tipe: String):
	quest_selesai += 1
	
	if tipe == "E" or tipe == "S" or tipe == "T" or tipe == "J":
		skor_kiri += 1
	else:
		skor_kanan += 1
		
	match tipe:
		"E": poin_E += 1
		"I": poin_I += 1
		"S": poin_S += 1
		"N": poin_N += 1
		"T": poin_T += 1
		"F": poin_F += 1
		"J": poin_J += 1
		"P": poin_P += 1
		
	tampilkan_debugger()

func tampilkan_debugger():
	print("======== 🛠 DEBUGGER GLOBAL 🛠 ========")
	print("Pemain          : ", player_name)
	print("Dimensi Selesai : ", dimensi_selesai, " (Total: ", dimensi_selesai.size(), "/4)")
	print("Status Zona Ini : Quest = ", quest_selesai, " | Skor Kiri = ", skor_kiri, " | Skor Kanan = ", skor_kanan)
	print("POIN MBTI AKUMULASI:")
	print("  [E] ", poin_E, " vs [I] ", poin_I)
	print("  [S] ", poin_S, " vs [N] ", poin_N)
	print("  [T] ", poin_T, " vs [F] ", poin_F)
	print("  [J] ", poin_J, " vs [P] ", poin_P)
	print("=======================================\n")

func hitung_hasil_mbti() -> String:
	var hasil = ""
	hasil += "E" if poin_E >= poin_I else "I"
	hasil += "S" if poin_S >= poin_N else "N"
	hasil += "T" if poin_T >= poin_F else "F"
	hasil += "J" if poin_J >= poin_P else "P"
	
	mbti_result = hasil
	return hasil

func is_valid_zone_path(scene_path: String) -> bool:
	for m in daftar_map:
		if m.get("path", "") == scene_path:
			return true
	return false

func daftarkan_zona_aktif(scene_path: String):
	if scene_path != "" and is_valid_zone_path(scene_path):
		if not (scene_path in zona_dikunjungi):
			zona_dikunjungi.append(scene_path)
		for map in daftar_map:
			if map["path"] == scene_path:
				if not (map["dimensi"] in dimensi_selesai):
					dimensi_selesai.append(map["dimensi"])
				print("📍 [Global] Zona terdaftar aktif: ", scene_path, " [", map["dimensi"], "]")
				break
	update_progres_zona()

func update_progres_zona():
	# Total zona dihitung dari daftar_map yang aktif (default 4 dimensi MBTI: E/I, S/N, T/F, J/P)
	var total_map = 0
	for m in daftar_map:
		if m.get("aktif", true):
			total_map += 1
	max_zona = int(max(total_map, 4))
	
	# Hitung jumlah zona gameplay MBTI yang sudah didatangi
	var count_zona = 0
	for path in zona_dikunjungi:
		if is_valid_zone_path(path):
			count_zona += 1
	if count_zona == 0 and dimensi_selesai.size() > 0:
		count_zona = dimensi_selesai.size()
		
	# zona_ke: urutan dunia saat ini (1 sampai max_zona)
	zona_ke = int(clamp(max(1, count_zona), 1, max_zona))
	# sisa_zona: berapa banyak dunia yang tersisa SETELAH dunia ini selesai
	sisa_zona = int(max(0, max_zona - zona_ke))
	print("📊 [Global] Progres Zona: Zona ke-", zona_ke, " dari ", max_zona, " (Sisa: ", sisa_zona, " dunia lagi)")

func catat_zona_sekarang_selesai():
	var cur = get_tree().current_scene
	if is_instance_valid(cur) and cur.filename != "" and is_valid_zone_path(cur.filename):
		daftarkan_zona_aktif(cur.filename)

func get_random_map() -> String:
	catat_zona_sekarang_selesai()
	
	var cur_path = ""
	if is_instance_valid(get_tree().current_scene):
		cur_path = get_tree().current_scene.filename
		
	var map_valid = []
	for map in daftar_map:
		if not map.get("aktif", true):
			continue
		# Zona belum pernah didatangi dimensi maupun path-nya
		if not (map["dimensi"] in dimensi_selesai) and not (map["path"] in zona_dikunjungi) and map["path"] != cur_path:
			map_valid.append(map)
	
	print("🎲 [Global] Sisa Zona Tersedia di Run Ini: ", map_valid.size())
	for m in map_valid:
		print("   - ", m["dimensi"], ": ", m["path"])
		
	if map_valid.size() > 0:
		randomize()
		var index_acak = randi() % map_valid.size()
		var map_terpilih = map_valid[index_acak]
		print("🚀 [Global] Pindah ke Zona Terpilih: ", map_terpilih["path"], " [", map_terpilih["dimensi"], "]")
		return map_terpilih["path"]
	else:
		print("🏆 [Global] Semua Zona Selesai! Menuju Ending Skenario.")
		hitung_hasil_mbti()
		return "res://scenes/ending/Ending.tscn"

# --- FUNGSI PERALIHAN ZONA DENGAN FADE ---
# Kita beri nilai bawaan 1.0 detik untuk antar-zona biasa
func pindah_zona_acak(durasi_out: float = 1.0, durasi_in: float = 1.0):
	dialog_aktif = true
	
	# Redupkan musik bersamaan dengan layar hitam
	fade_out_bgm_saat_ini(durasi_out)
	yield(fade_out(durasi_out), "completed")
	
	var map_selanjutnya = get_random_map()
	var err = get_tree().change_scene(map_selanjutnya)
	if err != OK:
		printerr("❌ [Global] GAGAL change_scene ke: ", map_selanjutnya, " (Kode Error: ", err, ")")
		
	yield(get_tree(), "idle_frame")
	yield(fade_in(durasi_in), "completed")

const SAVE_PATH_MBTI = "user://mbti_collection.save"
var directory_notif_dilihat: bool = false

func simpan_koleksi_ke_file():
	var file = File.new()
	if file.open(SAVE_PATH_MBTI, File.WRITE) == OK:
		file.store_var({
			"mbti_terbuka": mbti_terbuka,
			"notif_dilihat": directory_notif_dilihat
		})
		file.close()

func muat_koleksi_dari_file():
	var file = File.new()
	if file.file_exists(SAVE_PATH_MBTI):
		if file.open(SAVE_PATH_MBTI, File.READ) == OK:
			var data = file.get_var()
			if data is Dictionary:
				mbti_terbuka = data.get("mbti_terbuka", [])
				directory_notif_dilihat = data.get("notif_dilihat", false)
			elif data is Array:
				mbti_terbuka = data
			file.close()

func simpan_koleksi_mbti(kode: String):
	if not (kode in mbti_terbuka):
		mbti_terbuka.append(kode)
		mbti_baru_terbuka = true
		simpan_koleksi_ke_file()
		print("🎉 Koleksi Baru Terbuka: ", kode)

const DEFAULT_MBTI_DATA = {
	"ISTJ": {
		"class": "Leader",
		"role": "Inspector",
		"desc": "The Inspector adalah penyelenggara yang bertanggung jawab, yang terdorong untuk menciptakan dan menegakkan ketertiban di dalam sistem dan institusi. Praktis, teliti, dan mengutamakan fakta nyata serta integritas tinggi."
	},
	"INTJ": {
		"class": "Leader",
		"role": "Mastermind",
		"desc": "The Mastermind adalah pemikir strategis dengan visi jangka panjang yang tajam. Selalu termotivasi untuk merombak dan menyempurnakan sistem rumit dengan ide-ide inovatif serta perencanaan matang."
	},
	"ESTJ": {
		"class": "Leader",
		"role": "Supervisor",
		"desc": "The Supervisor adalah organisator tegas dan pekerja keras yang selalu siap memimpin. Berorientasi pada hasil nyata, menjunjung tinggi keteraturan, dan piawai menggerakkan orang serta proyek secara efisien."
	},
	"ENTJ": {
		"class": "Leader",
		"role": "Commander",
		"desc": "The Commander adalah pemimpin visioner dan berani yang tidak kenal lelah. Menguasai pemetaan strategi besar, cepat mengambil keputusan penting, dan mampu mengubah setiap rintangan menjadi keberhasilan."
	},
	"ISFJ": {
		"class": "Parserv",
		"role": "Protector",
		"desc": "The Protector adalah pengasuh yang setia, teliti, dan berdedikasi tinggi. Selalu siap membela keharmonisan dan memberikan perhatian tulus demi menjaga keamanan dan kenyamanan orang-orang tersayang."
	},
	"INFJ": {
		"class": "Parserv",
		"role": "Counselor",
		"desc": "The Counselor adalah pengayom berwawasan batin mendalam dengan integritas pribadi yang kokoh. Penuh empati dan idealisme, selalu bertekad membimbing sesama untuk mewujudkan potensi terbaik dalam hidup mereka."
	},
	"ESFJ": {
		"class": "Parserv",
		"role": "Provider",
		"desc": "The Provider adalah penolong yang hangat, ramah, dan penuh energi sosial. Sangat peka terhadap kebutuhan lingkungan sekitarnya serta berdedikasi untuk menciptakan keharmonisan dan kebersamaan komunitas."
	},
	"ENFJ": {
		"class": "Parserv",
		"role": "Teacher",
		"desc": "The Teacher adalah pembimbing karismatik dan inspiratif yang mampu memikat hati banyak orang. Terdorong oleh nilai kemanusiaan, mereka memimpin dengan empati alami menuju masa depan yang lebih bermakna."
	},
	"ISTP": {
		"class": "Briliance",
		"role": "Craftsman",
		"desc": "The Craftsman adalah penemu praktis dengan pemahaman mekanis yang luar biasa. Cepat menguasai berbagai alat, tenang menghadapi situasi mendadak, dan selalu menemukan solusi logis paling efisien."
	},
	"INTP": {
		"class": "Briliance",
		"role": "Architect",
		"desc": "The Architect adalah pemikir filosofis dan inovator logis yang terpesona oleh pola serta teori mendalam. Berjiwa analitis tinggi, selalu mencari kebenaran hakiki dan prinsip kerja di balik segala fenomena dunia."
	},
	"ESTP": {
		"class": "Briliance",
		"role": "Dynamo",
		"desc": "The Dynamo adalah pengambil aksi energik dan pemberani yang menikmati dinamika hidup di saat ini. Gesit, cerdas membaca situasi, dan piawai menemukan jalan keluar instan di tengah tantangan nyata."
	},
	"ENTP": {
		"class": "Briliance",
		"role": "Visionary",
		"desc": "The Visionary adalah inovator berjiwa bebas yang tertantang oleh gagasan intelektual baru. Gesit dalam berargumen, cerdas merangkai kemungkinan, dan ahli menciptakan solusi kreatif di luar kelaziman."
	},
	"ISFP": {
		"class": "Popularity",
		"role": "Composer",
		"desc": "The Composer adalah penjelajah estetika yang lembut, ramah, dan menikmati keindahan setiap momen. Mengekspresikan nilai batin melalui seni dan tindakan nyata dengan kehangatan spontan yang menawan."
	},
	"INFP": {
		"class": "Popularity",
		"role": "Healer",
		"desc": "The Healer adalah idealis puitis dan berhati mulia yang dibimbing oleh prinsip moral serta keyakinan otentik. Selalu mencari secercah kebaikan dalam setiap insan dan setia mendengarkan panggilan nurani terdalam."
	},
	"ESFP": {
		"class": "Popularity",
		"role": "Performer",
		"desc": "The Performer adalah penghibur ceria yang membawa semangat positif ke mana pun mereka melangkah. Spontan, energik, dan menawan, mampu menghidupkan suasana dengan keceriaan yang menular."
	},
	"ENFP": {
		"class": "Popularity",
		"role": "Champion",
		"desc": "The Champion adalah kreator antusias yang melihat potensi tanpa batas dalam segala hal. Ramah, imajinatif, dan penuh inspirasi baru, mampu menyatukan berbagai ide dan orang dengan kehangatan yang tulus."
	}
}

func muat_data_mbti_json():
	var file = File.new()
	if file.open("res://mbti_data.json", File.READ) == OK:
		var txt = file.get_as_text()
		file.close()
		var res = JSON.parse(txt)
		if res.error == OK and res.result is Dictionary:
			data_mbti = res.result
			print("✅ [Global] Berhasil memuat data MBTI dari res://mbti_data.json (", data_mbti.size(), " tipe)")
			return
		else:
			printerr("❌ [Global] Gagal parse res://mbti_data.json: ", res.error_string)
	else:
		print("ℹ️ [Global] File res://mbti_data.json tidak terbaca langsung, menggunakan data MBTI built-in")
		
	# Fallback otomatis ke data bawaan agar build export tidak pernah kehilangan info MBTI
	data_mbti = DEFAULT_MBTI_DATA.duplicate(true)

func get_mbti_info(kode: String) -> Dictionary:
	if data_mbti.empty():
		muat_data_mbti_json()
	if data_mbti.has(kode):
		return data_mbti[kode]
	if DEFAULT_MBTI_DATA.has(kode):
		return DEFAULT_MBTI_DATA[kode]
	return {}

func reset_koleksi_mbti():
	mbti_terbuka = []
	directory_notif_dilihat = false
	simpan_koleksi_ke_file()
	print("🗑️ [Global] Koleksi MBTI berhasil direset.")

# --- FITUR SAVE & RESUME (PERSIST & STORE & TERMINATE) ---
func simpan_game_progres():
	var cur_scene = get_tree().current_scene
	var scene_path = ""
	var p_pos = Vector2.ZERO
	
	if is_instance_valid(cur_scene):
		scene_path = cur_scene.filename
		var player = cur_scene.get_node_or_null("Player")
		if player == null:
			player = cur_scene.get_node_or_null("YSort/Player")
		if is_instance_valid(player):
			p_pos = player.global_position
			
	var data = {
		"ada_save": true,
		"scene_path": scene_path,
		"player_pos_x": p_pos.x,
		"player_pos_y": p_pos.y,
		"player_name": player_name,
		"dimensi_selesai": dimensi_selesai,
		"zona_dikunjungi": zona_dikunjungi,
		"zona_ke": zona_ke,
		"sisa_zona": sisa_zona,
		"guide_awal_sudah_muncul": guide_awal_sudah_muncul,
		"quest_selesai": quest_selesai,
		"skor_kiri": skor_kiri,
		"skor_kanan": skor_kanan,
		"poin_E": poin_E,
		"poin_I": poin_I,
		"poin_S": poin_S,
		"poin_N": poin_N,
		"poin_T": poin_T,
		"poin_F": poin_F,
		"poin_J": poin_J,
		"poin_P": poin_P,
		"mbti_result": mbti_result,
		"raka_selesai": raka_selesai,
		"kaleva_selesai": kaleva_selesai,
		"annie_selesai": annie_selesai,
		"kaleva_opsi_papan": kaleva_opsi_papan,
		"zana_selesai": zana_selesai,
		"moxie_selesai": moxie_selesai,
		"arif_selesai": arif_selesai,
		"zana_opsi_denah": zana_opsi_denah,
		"agcl_selesai": agcl_selesai,
		"k4iro_selesai": k4iro_selesai,
		"elio_selesai": elio_selesai,
		"captain_selesai": captain_selesai,
		"myra_selesai": myra_selesai,
		"ronnie_selesai": ronnie_selesai
	}
	
	var file = File.new()
	if file.open(SAVE_PATH_PROGRESS, File.WRITE) == OK:
		file.store_var(data)
		file.close()
		print("💾 [Global] Progres permainan berhasil disimpan ke ", SAVE_PATH_PROGRESS)

func ada_save_progres() -> bool:
	var file = File.new()
	if not file.file_exists(SAVE_PATH_PROGRESS):
		return false
	if file.open(SAVE_PATH_PROGRESS, File.READ) == OK:
		var d = file.get_var()
		file.close()
		return (d is Dictionary) and d.get("ada_save", false)
	return false

func muat_game_progres() -> bool:
	var file = File.new()
	if not file.file_exists(SAVE_PATH_PROGRESS):
		return false
	if file.open(SAVE_PATH_PROGRESS, File.READ) != OK:
		return false
	var d = file.get_var()
	file.close()
	if not (d is Dictionary) or not d.get("ada_save", false):
		return false
		
	player_name = d.get("player_name", "")
	dimensi_selesai = d.get("dimensi_selesai", [])
	zona_dikunjungi = d.get("zona_dikunjungi", [])
	zona_ke = d.get("zona_ke", 1)
	sisa_zona = d.get("sisa_zona", 3)
	guide_awal_sudah_muncul = d.get("guide_awal_sudah_muncul", true)
	quest_selesai = d.get("quest_selesai", 0)
	skor_kiri = d.get("skor_kiri", 0)
	skor_kanan = d.get("skor_kanan", 0)
	poin_E = d.get("poin_E", 0)
	poin_I = d.get("poin_I", 0)
	poin_S = d.get("poin_S", 0)
	poin_N = d.get("poin_N", 0)
	poin_T = d.get("poin_T", 0)
	poin_F = d.get("poin_F", 0)
	poin_J = d.get("poin_J", 0)
	poin_P = d.get("poin_P", 0)
	mbti_result = d.get("mbti_result", "")
	
	raka_selesai = d.get("raka_selesai", false)
	kaleva_selesai = d.get("kaleva_selesai", false)
	annie_selesai = d.get("annie_selesai", false)
	kaleva_opsi_papan = d.get("kaleva_opsi_papan", false)
	zana_selesai = d.get("zana_selesai", false)
	moxie_selesai = d.get("moxie_selesai", false)
	arif_selesai = d.get("arif_selesai", false)
	zana_opsi_denah = d.get("zana_opsi_denah", false)
	agcl_selesai = d.get("agcl_selesai", false)
	k4iro_selesai = d.get("k4iro_selesai", false)
	elio_selesai = d.get("elio_selesai", false)
	captain_selesai = d.get("captain_selesai", false)
	myra_selesai = d.get("myra_selesai", false)
	ronnie_selesai = d.get("ronnie_selesai", false)
	
	var target_scene = d.get("scene_path", "")
	if target_scene == "" or not ResourceLoader.exists(target_scene):
		target_scene = "res://scenes/zone/Zone01.tscn"
		
	posisi_spawn_sementara = Vector2(d.get("player_pos_x", 0), d.get("player_pos_y", 0))
	sedang_muat_save = true
	dialog_aktif = false
	cutscene_aktif = false
	if is_instance_valid(dim_rect):
		dim_rect.visible = false
	
	pindah_ke_scene(target_scene)
	return true

func hapus_save_progres():
	var dir = Directory.new()
	if dir.file_exists(SAVE_PATH_PROGRESS):
		dir.remove(SAVE_PATH_PROGRESS)
		print("🗑️ [Global] Save progres permainan dihapus.")

func reset_game_total():
	hapus_save_progres()
	guide_awal_sudah_muncul = false
	guide_modal_terbuka = false
	about_modal_terbuka = false
	player_name = ""
	dimensi_selesai = []
	zona_dikunjungi = []
	quest_selesai = 0
	skor_kiri = 0
	skor_kanan = 0
	poin_E = 0
	poin_I = 0
	poin_S = 0
	poin_N = 0
	poin_T = 0
	poin_F = 0
	poin_J = 0
	poin_P = 0
	mbti_result = ""
	kaleva_opsi_papan = false
	zana_selesai = false
	moxie_selesai = false
	arif_selesai = false
	zana_opsi_denah = false
	agcl_selesai = false
	k4iro_selesai = false
	elio_selesai = false
	captain_selesai = false
	myra_selesai = false
	ronnie_selesai = false
	raka_selesai = false
	kaleva_selesai = false
	annie_selesai = false
	posisi_spawn_sementara = Vector2.ZERO
	sedang_muat_save = false
	update_progres_zona()
	# mbti_terbuka Sengaja TIDAK di-reset biar koleksinya tetep tersimpan!
# --- FUNGSI PINDAH SCENE DENGAN FADE ---
func pindah_ke_scene(path_scene: String):
	# Redupkan musik bersamaan dengan layar hitam
	fade_out_bgm_saat_ini(1.0)
	yield(fade_out(1.0), "completed")
	
	dialog_aktif = false
	cutscene_aktif = false
	if is_instance_valid(dim_rect):
		dim_rect.visible = false
		
	get_tree().change_scene(path_scene)
	yield(get_tree(), "idle_frame")
	
	if "MainMenu" in path_scene or "mainmenu" in path_scene.to_lower():
		putar_bgm_worldvoid(1.0)
		
	yield(fade_in(1.0), "completed")
	sedang_muat_save = false
	update_mouse_cursor()
# --- FUNGSI MENCARI & MEREDUPKAN BGM SCENE AKTIF ---
func fade_out_bgm_saat_ini(durasi: float = 1.0):
	var scene_saat_ini = get_tree().current_scene
	if is_instance_valid(scene_saat_ini):
		# Cari node bernama "BGM" atau "BGMok" di scene yang sedang berjalan
		var bgm = scene_saat_ini.get_node_or_null("BGM")
		if bgm == null:
			bgm = scene_saat_ini.get_node_or_null("BGMok")
		if is_instance_valid(bgm) and (bgm is AudioStreamPlayer or bgm is AudioStreamPlayer2D) and bgm.playing:
			tween.interpolate_property(
				bgm, 
				"volume_db", 
				bgm.volume_db, 
				-80.0, 
				durasi, 
				Tween.TRANS_LINEAR, 
				Tween.EASE_IN_OUT
			)
			tween.start()

# --- FUNGSI MEMULAI & MEMPERKERAS BGM SECARA LEMBUT (FADE IN) ---
func fade_in_bgm(bgm_node: Node, durasi: float = 1.0, target_db: float = 0.0):
	if is_instance_valid(bgm_node) and (bgm_node is AudioStreamPlayer or bgm_node is AudioStreamPlayer2D):
		var start_db = bgm_node.volume_db
		if not bgm_node.playing or start_db <= -70.0:
			start_db = -45.0
			bgm_node.volume_db = -45.0
			if not bgm_node.playing:
				bgm_node.play()
		tween.interpolate_property(
			bgm_node,
			"volume_db",
			start_db,
			target_db,
			durasi,
			Tween.TRANS_QUAD,
			Tween.EASE_OUT
		)
		tween.start()

# --- HELPER BGM ZONA UNTUK PAUSE MENU ---
func get_zone_bgm() -> Node:
	var cur = get_tree().current_scene
	if is_instance_valid(cur):
		var b = cur.get_node_or_null("BGM")
		if b == null:
			b = cur.get_node_or_null("BGMok")
		if is_instance_valid(b) and (b is AudioStreamPlayer or b is AudioStreamPlayer2D):
			return b
	return null

func fade_bgm_volume(bgm_node: Node, target_db: float, durasi: float = 0.4):
	if is_instance_valid(bgm_node) and (bgm_node is AudioStreamPlayer or bgm_node is AudioStreamPlayer2D):
		tween.interpolate_property(
			bgm_node,
			"volume_db",
			bgm_node.volume_db,
			target_db,
			durasi,
			Tween.TRANS_SINE,
			Tween.EASE_OUT
		)
		tween.start()
