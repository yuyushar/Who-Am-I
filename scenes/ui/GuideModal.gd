extends CanvasLayer

onready var overlay = $Overlay
onready var panel = $CenterContainer/Panel
onready var btn_tutup = $CenterContainer/Panel/VBoxContainer/BottomContainer/BtnTutup
onready var tween = $Tween

var is_terbuka: bool = false
var _was_paused_before: bool = false

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	visible = false
	overlay.modulate.a = 0.0
	panel.modulate.a = 0.0
	panel.rect_scale = Vector2(0.92, 0.92)
	
	if is_instance_valid(btn_tutup):
		btn_tutup.connect("pressed", self, "tutup")

func buka():
	if is_terbuka:
		return
	is_terbuka = true
	visible = true
	
	_was_paused_before = get_tree().paused
	get_tree().paused = true
	Global.guide_modal_terbuka = true
	Global.update_mouse_cursor()
	
	# Turunkan volume BGM zona saat panduan terbuka (seperti pause menu, fade ke -14 dB)
	var zone_bgm = Global.get_zone_bgm()
	if is_instance_valid(zone_bgm):
		zone_bgm.pause_mode = Node.PAUSE_MODE_PROCESS
		Global.fade_bgm_volume(zone_bgm, -14.0, 0.35)
	
	if panel.rect_size.x > 0:
		panel.rect_pivot_offset = panel.rect_size * 0.5
	else:
		panel.rect_pivot_offset = panel.rect_min_size * 0.5
		
	tween.stop_all()
	tween.interpolate_property(overlay, "modulate:a", overlay.modulate.a, 1.0, 0.22, Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.interpolate_property(panel, "modulate:a", panel.modulate.a, 1.0, 0.22, Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.interpolate_property(panel, "rect_scale", Vector2(0.92, 0.92), Vector2(1.0, 1.0), 0.25, Tween.TRANS_BACK, Tween.EASE_OUT)
	tween.start()
	
	if is_instance_valid(btn_tutup):
		btn_tutup.release_focus()

func tutup():
	if not is_terbuka:
		return
	is_terbuka = false
	
	Global.play_sfx_button()
	
	# Kembalikan volume BGM jika pause menu tidak sedang terbuka
	var zone_bgm = Global.get_zone_bgm()
	if is_instance_valid(zone_bgm) and not Global.pause_menu_terbuka:
		Global.fade_bgm_volume(zone_bgm, 0.0, 0.35)
	
	tween.stop_all()
	tween.interpolate_property(overlay, "modulate:a", overlay.modulate.a, 0.0, 0.16, Tween.TRANS_SINE, Tween.EASE_IN)
	tween.interpolate_property(panel, "modulate:a", panel.modulate.a, 0.0, 0.16, Tween.TRANS_SINE, Tween.EASE_IN)
	tween.interpolate_property(panel, "rect_scale", panel.rect_scale, Vector2(0.94, 0.94), 0.16, Tween.TRANS_SINE, Tween.EASE_IN)
	tween.start()
	yield(tween, "tween_all_completed")
	if is_instance_valid(self):
		visible = false
		Global.guide_modal_terbuka = false
		if not _was_paused_before and not Global.pause_menu_terbuka:
			get_tree().paused = false
		Global.update_mouse_cursor()

func _input(event):
	if is_terbuka and event is InputEventKey and event.is_pressed() and not event.is_echo() and event.scancode == KEY_ESCAPE:
		tutup()
		get_tree().set_input_as_handled()
