extends Control

onready var name_panel = $NameInputPanel
onready var name_input = $NameInputPanel/VBoxContainer/NameInput
onready var confirm_btn = $NameInputPanel/VBoxContainer/ConfirmButton
onready var fade_rect = $FadeRect
onready var guider_sprite = $CharacterLayer/Guider
onready var player_sprite = $CharacterLayer/Player

var dialog_resource = load("res://dialogues/prologue.tres")

# Variabel untuk melacak progres dan referensi balon
var is_dialog_kedua = false
var balon_aktif = null 
var is_pindah_sedang_jalan = false

var base_guider_y = -147.125
var base_player_y = -89.0

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	Global.putar_bgm_worldvoid()
	name_panel.hide()
	name_input.connect("text_entered", self, "_on_name_input_text_entered")
	if not confirm_btn.is_connected("pressed", self, "_on_ConfirmButton_pressed"):
		confirm_btn.connect("pressed", self, "_on_ConfirmButton_pressed")
	
	# 1. Bikin layar hitam pekat saat game dibuka
	Global.fade_rect.modulate.a = 1.0
	
	# 2. TUNGGU sampai fade in selesai (2.5 detik)
	yield(Global.fade_in(2.5), "completed")
	
	# 3. Baru panggil dialog setelah layar benar-benar terang!
	tampilkan_dialog("start")

func _process(_delta):
	# Efek melayang halus di dimensi void (zero-gravity breathing)
	var t = OS.get_ticks_msec() * 0.002
	if is_instance_valid(guider_sprite):
		guider_sprite.position.y = base_guider_y + sin(t * 1.6) * 5.0
	if is_instance_valid(player_sprite):
		player_sprite.position.y = base_player_y + sin(t * 1.1) * 3.0

func tampilkan_dialog(titik_mulai):
	if is_instance_valid(balon_aktif):
		balon_aktif.queue_free()
		balon_aktif = null
		
	var baris_dialog = yield(DialogueManager.get_next_dialogue_line(titik_mulai, dialog_resource, [self, Global]), "completed")
	
	if baris_dialog != null:
		balon_aktif = load("res://addons/dialogue_manager/example_balloon/example_balloon.tscn").instance()
		balon_aktif.dialogue_line = baris_dialog
		balon_aktif.dialogue_resource = dialog_resource
		self.add_child(balon_aktif)
		balon_aktif.connect("actioned", self, "tampilkan_dialog")
	else:
		balon_aktif = null
		
		# Jika dialog selesai diklik sampai habis secara normal:
		if not is_dialog_kedua:
			# Selesai dialog pertama -> Munculkan input nama
			munculkan_input_nama()
		else:
			# Selesai dialog kedua (setelah isi nama) -> Pindah ke zona acak!
			pindah_ke_zona()

func _input(event):
	# Jika panel nama sedang muncul dan user mengetik di keyboard, pastikan fokus ada di name_input
	if is_instance_valid(name_panel) and name_panel.visible:
		if event is InputEventKey and event.is_pressed():
			if event.scancode != KEY_ENTER and event.scancode != KEY_KP_ENTER:
				if is_instance_valid(name_input) and not name_input.has_focus() and not confirm_btn.has_focus():
					name_input.grab_focus()
					name_input.caret_position = name_input.text.length()

func munculkan_input_nama():
	# Hapus balon dialog jika masih ada di layar agar tidak overlap
	if is_instance_valid(balon_aktif):
		balon_aktif.queue_free()
		balon_aktif = null
		
	Global.reset_dialog_speakers()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	name_panel.show()
	name_input.grab_focus()
	name_input.caret_position = name_input.text.length()

func _on_name_input_text_entered(_text):
	_on_confirm_pressed()

func _on_confirm_pressed():
	if is_dialog_kedua:
		return
		
	var nama = name_input.text.strip_edges()
	if nama != "":
		Global.play_sfx_button()
		Global.player_name = nama
		is_dialog_kedua = true
		
		name_panel.hide()
		
		if is_instance_valid(balon_aktif):
			balon_aktif.queue_free()
			balon_aktif = null
			
		Global.reset_dialog_speakers()
		tampilkan_dialog("ask_name")
	else:
		print("Nama belum diisi!")

func pindah_ke_zona():
	if is_pindah_sedang_jalan:
		return
	is_pindah_sedang_jalan = true
	
	if is_instance_valid(balon_aktif):
		balon_aktif.queue_free()
	
	# Out dari Prologue dibuat agak lama (2.5 detik), 
	# lalu In ke Zona 1 dibuat normal/cepat (1.0 detik)
	Global.pindah_zona_acak(2.5, 1.0)

func _on_ConfirmButton_pressed():
	_on_confirm_pressed()
