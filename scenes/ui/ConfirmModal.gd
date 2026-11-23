extends CanvasLayer

signal dikonfirmasi(hasil) # true jika Ya, false jika Batal

onready var overlay = $Overlay
onready var panel = $CenterContainer/Panel
onready var title_label = $CenterContainer/Panel/VBoxContainer/TitleLabel
onready var message_label = $CenterContainer/Panel/VBoxContainer/MessageLabel
onready var btn_ya = $CenterContainer/Panel/VBoxContainer/HBoxContainer/BtnYa
onready var btn_tidak = $CenterContainer/Panel/VBoxContainer/HBoxContainer/BtnTidak
onready var tween = $Tween

var _callback_ya: FuncRef = null
var _callback_tidak: FuncRef = null
var is_terbuka: bool = false

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	visible = false
	overlay.modulate.a = 0.0
	panel.modulate.a = 0.0
	panel.rect_scale = Vector2(0.9, 0.9)
	
	btn_ya.connect("pressed", self, "_on_ya_pressed")
	btn_tidak.connect("pressed", self, "_on_tidak_pressed")
	btn_ya.connect("mouse_entered", self, "_on_hover_sfx")
	btn_tidak.connect("mouse_entered", self, "_on_hover_sfx")

func _on_hover_sfx():
	Global.play_sfx_hover()

func tampilkan(pesan: String, teks_ya: String = "> Sure", teks_tidak: String = "> Pass", judul: String = "KONFIRMASI", callback_ya: FuncRef = null, callback_tidak: FuncRef = null):
	_callback_ya = callback_ya
	_callback_tidak = callback_tidak
	
	title_label.text = judul
	message_label.text = pesan
	if btn_ya.has_method("set_display_text"):
		btn_ya.set_display_text(teks_ya)
	else:
		btn_ya.text = teks_ya
		
	if btn_tidak.has_method("set_display_text"):
		btn_tidak.set_display_text(teks_tidak)
	else:
		btn_tidak.text = teks_tidak
	
	visible = true
	is_terbuka = true
	
	tween.stop_all()
	tween.interpolate_property(overlay, "modulate:a", overlay.modulate.a, 1.0, 0.20, Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.interpolate_property(panel, "modulate:a", panel.modulate.a, 1.0, 0.20, Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.interpolate_property(panel, "rect_scale", Vector2(0.92, 0.92), Vector2(1.0, 1.0), 0.22, Tween.TRANS_BACK, Tween.EASE_OUT)
	tween.start()
	
	# Lepas fokus tombol agar tidak auto menyala dan tidak terjadi accidental double-click
	if is_instance_valid(btn_tidak):
		btn_tidak.release_focus()
	if is_instance_valid(btn_ya):
		btn_ya.release_focus()

func tutup():
	if not is_terbuka:
		return
	is_terbuka = false
	
	tween.stop_all()
	tween.interpolate_property(overlay, "modulate:a", overlay.modulate.a, 0.0, 0.16, Tween.TRANS_SINE, Tween.EASE_IN)
	tween.interpolate_property(panel, "modulate:a", panel.modulate.a, 0.0, 0.16, Tween.TRANS_SINE, Tween.EASE_IN)
	tween.interpolate_property(panel, "rect_scale", panel.rect_scale, Vector2(0.94, 0.94), 0.16, Tween.TRANS_SINE, Tween.EASE_IN)
	tween.start()
	yield(tween, "tween_all_completed")
	visible = false

func _on_ya_pressed():
	Global.play_sfx_button()
	tutup()
	emit_signal("dikonfirmasi", true)
	if _callback_ya != null and _callback_ya.is_valid():
		_callback_ya.call_func()

func _on_tidak_pressed():
	Global.play_sfx_button()
	tutup()
	emit_signal("dikonfirmasi", false)
	if _callback_tidak != null and _callback_tidak.is_valid():
		_callback_tidak.call_func()

func _input(event):
	if is_terbuka and event is InputEventKey and event.is_pressed() and not event.is_echo() and event.scancode == KEY_ESCAPE:
		_on_tidak_pressed()
		get_tree().set_input_as_handled()

