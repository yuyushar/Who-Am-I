extends CanvasLayer

onready var overlay = $Overlay
onready var menu_box = $MenuBox
onready var btn_persist = $MenuBox/ButtonsContainer/PersistButton
onready var btn_guide = $MenuBox/ButtonsContainer/GuideButton
onready var btn_store_terminate = $MenuBox/ButtonsContainer/StoreTerminateButton
onready var btn_terminate = $MenuBox/ButtonsContainer/TerminateButton
onready var tween = $Tween

var confirm_modal = null
var guide_modal = null
var is_animating: bool = false
var target_box_y: float = 180.0

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	visible = false
	overlay.modulate.a = 0.0
	menu_box.rect_position.y = -450.0
	
	btn_persist.connect("pressed", self, "_on_persist_pressed")
	btn_guide.connect("pressed", self, "_on_guide_pressed")
	btn_store_terminate.connect("pressed", self, "_on_store_terminate_pressed")
	btn_terminate.connect("pressed", self, "_on_terminate_pressed")
	_siapkan_confirm_modal()
	_siapkan_guide_modal()

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

func _on_guide_pressed():
	if is_instance_valid(guide_modal):
		guide_modal.buka()

func buka():
	if Global.is_dialogue_playing():
		return
	if visible and not is_animating:
		return
	is_animating = true
	visible = true
	get_tree().paused = true
	Global.pause_menu_terbuka = true
	Global.update_mouse_cursor()
	
	# Turunkan volume BGM zona saat pause, tetapi biarkan tetap berputar (fade ke -14 dB)
	var zone_bgm = Global.get_zone_bgm()
	if is_instance_valid(zone_bgm):
		zone_bgm.pause_mode = Node.PAUSE_MODE_PROCESS
		Global.fade_bgm_volume(zone_bgm, -14.0, 0.35)
	
	var vp_size = get_viewport().get_visible_rect().size
	target_box_y = max(80.0, (vp_size.y - menu_box.rect_size.y) * 0.42)
	
	menu_box.rect_position.y = -450.0
	overlay.modulate.a = 0.0
	
	tween.stop_all()
	# Slide down dari atas ke posisi tengah dengan animasi elastis halus (TRANS_BACK, EASE_OUT)
	tween.interpolate_property(menu_box, "rect_position:y", -450.0, target_box_y, 0.42, Tween.TRANS_BACK, Tween.EASE_OUT)
	# Fade-in overlay gelap transparan
	tween.interpolate_property(overlay, "modulate:a", 0.0, 1.0, 0.30, Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.start()
	yield(tween, "tween_all_completed")
	is_animating = false

func tutup():
	if is_animating or not visible:
		return
	is_animating = true
	
	if is_instance_valid(confirm_modal) and confirm_modal.is_terbuka:
		confirm_modal.tutup()
	if is_instance_valid(guide_modal) and guide_modal.is_terbuka:
		guide_modal.tutup()
	
	# Kembalikan volume BGM zona ke normal (0.0 dB)
	var zone_bgm = Global.get_zone_bgm()
	if is_instance_valid(zone_bgm):
		Global.fade_bgm_volume(zone_bgm, 0.0, 0.35)
		
	tween.stop_all()
	# Slide up kembali ke atas layar
	tween.interpolate_property(menu_box, "rect_position:y", menu_box.rect_position.y, -450.0, 0.25, Tween.TRANS_BACK, Tween.EASE_IN)
	tween.interpolate_property(overlay, "modulate:a", overlay.modulate.a, 0.0, 0.22, Tween.TRANS_SINE, Tween.EASE_IN)
	tween.start()
	yield(tween, "tween_all_completed")
	
	visible = false
	get_tree().paused = false
	Global.pause_menu_terbuka = false
	Global.update_mouse_cursor()
	is_animating = false

func _on_persist_pressed():
	tutup()

func _on_store_terminate_pressed():
	if is_animating:
		return
	if is_instance_valid(confirm_modal):
		confirm_modal.tampilkan(
			"Simpan seluruh progres perjalanan saat ini dan kembali ke Menu Utama?",
			"> Sure",
			"> Pass",
			"SIMPAN PROGRES",
			funcref(self, "_eksekusi_store_terminate")
		)
		return
	_eksekusi_store_terminate()

func _eksekusi_store_terminate():
	# Simpan seluruh progres petualangan saat ini ke user://game_progress.save
	Global.simpan_game_progres()
	
	# Tutup pause & unpause
	visible = false
	get_tree().paused = false
	Global.pause_menu_terbuka = false
	
	# Mulai BGM worldvoid saat kembali ke Main Menu
	Global.putar_bgm_worldvoid(1.0)
	Global.pindah_ke_scene("res://scenes/main_menu/MainMenu.tscn")

func _on_terminate_pressed():
	if is_animating:
		return
	if is_instance_valid(confirm_modal):
		confirm_modal.tampilkan(
			"Seluruh progres yang belum tersimpan di dunia ini akan hilang.\nYakin ingin keluar ke Menu Utama?",
			"> Sure",
			"> Pass",
			"TINGGALKAN DUNIA",
			funcref(self, "_eksekusi_terminate")
		)
		return
	_eksekusi_terminate()

func _eksekusi_terminate():
	# Tutup pause & unpause
	visible = false
	get_tree().paused = false
	Global.pause_menu_terbuka = false
	Global.reset_game_total()
	
	# Mulai BGM worldvoid saat kembali ke Main Menu
	Global.putar_bgm_worldvoid(1.0)
	Global.pindah_ke_scene("res://scenes/main_menu/MainMenu.tscn")

func _input(event):
	if is_instance_valid(confirm_modal) and confirm_modal.is_terbuka:
		return
	if is_instance_valid(guide_modal) and guide_modal.is_terbuka:
		return
	# Jika pause menu sedang aktif dan player menekan ESC lagi -> Resume / Persist!
	if visible and event is InputEventKey and event.is_pressed() and not event.is_echo() and event.scancode == KEY_ESCAPE:
		tutup()
		get_tree().set_input_as_handled()
