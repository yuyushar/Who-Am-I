extends Area2D

signal dialog_selesai(key_dialog)

export(Resource) var dialogue_resource
export(String) var dialogue_start_key = "start"

onready var label_interaksi = $Label
var player_dalam_area = false
var dialog_sedang_berjalan = false
var label_base_y: float = -60.0

func _ready():
	atur_tampilan_label()
	label_interaksi.hide()
	connect("body_entered", self, "_on_body_entered")
	connect("body_exited", self, "_on_body_exited")
	connect("visibility_changed", self, "_on_visibility_changed")
	_update_solid_collision()
	
	# Hubungkan telinga NPC ke toa global DialogueManager HANYA SEKALI
	if not DialogueManager.is_connected("dialogue_finished", self, "_on_dialog_tutup"):
		DialogueManager.connect("dialogue_finished", self, "_on_dialog_tutup")

func _process(_delta):
	if not is_instance_valid(label_interaksi):
		return
		
	# Sembunyikan label saat cutscene atau dialog sedang berlangsung
	if Global.cutscene_aktif or Global.dialog_aktif or Global.is_dialogue_playing():
		if label_interaksi.visible:
			label_interaksi.hide()
		return
		
	# Tampilkan dan beri efek melayang bernyawa (floating bobbing) jika player di dekat NPC
	if player_dalam_area and not dialog_sedang_berjalan:
		if not label_interaksi.visible:
			label_interaksi.show()
		var float_y = sin(OS.get_ticks_msec() * 0.005) * 3.0
		label_interaksi.rect_position.y = label_base_y + float_y
	else:
		if label_interaksi.visible:
			label_interaksi.hide()

func _on_visibility_changed():
	_update_solid_collision()

func _update_solid_collision():
	var col = get_node_or_null("SolidBody/CollisionShape2D")
	if is_instance_valid(col):
		col.set_deferred("disabled", not is_visible_in_tree())

func atur_tampilan_label():
	if not is_instance_valid(label_interaksi):
		return
	
	# 1. Gunakan DynamicFont OpenSans-Bold yang tajam dan nyaman dibaca
	var font = DynamicFont.new()
	var font_res = load("res://addons/dialogue_manager/example_balloon/Open_Sans/OpenSans-Bold.ttf")
	if font_res:
		font.font_data = font_res
		font.size = 13
		font.outline_size = 2
		font.outline_color = Color(0.06, 0.06, 0.10, 0.95)
		font.use_filter = true
		label_interaksi.set("custom_fonts/font", font)
	
	# 2. Pewarnaan teks: Putih gading cerah dengan bayangan kontras
	label_interaksi.set("custom_colors/font_color", Color(1.0, 0.98, 0.92, 1.0))
	label_interaksi.set("custom_colors/font_color_shadow", Color(0, 0, 0, 0.85))
	label_interaksi.set("custom_constants/shadow_offset_x", 1)
	label_interaksi.set("custom_constants/shadow_offset_y", 2)
	
	# 3. Desain pill / rounded badge semi-transparan yang rapi dan elegan
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.06, 0.08, 0.12, 0.82)
	bg_style.corner_radius_top_left = 6
	bg_style.corner_radius_top_right = 6
	bg_style.corner_radius_bottom_right = 6
	bg_style.corner_radius_bottom_left = 6
	bg_style.border_width_left = 1
	bg_style.border_width_top = 1
	bg_style.border_width_right = 1
	bg_style.border_width_bottom = 1
	bg_style.border_color = Color(0.95, 0.82, 0.45, 0.75) # Border keemasan halus
	bg_style.content_margin_left = 8.0
	bg_style.content_margin_right = 8.0
	bg_style.content_margin_top = 2.0
	bg_style.content_margin_bottom = 2.0
	label_interaksi.set("custom_styles/normal", bg_style)
	
	# Teks interaksi yang tegas
	label_interaksi.text = "Tekan [F]"
	
	# Kompensasi skala: jika NPC diperkecil (misal scale 0.42), label diperbesar balik
	var sx = abs(scale.x) if abs(scale.x) > 0.001 else 1.0
	var sy = abs(scale.y) if abs(scale.y) > 0.001 else 1.0
	label_interaksi.rect_scale = Vector2(1.0 / sx, 1.0 / sy)
	
	# Hitung batas paling atas kepala sprite NPC
	var sprite_node = get_node_or_null("Sprite")
	var top_offset = -60.0
	if is_instance_valid(sprite_node) and sprite_node.texture:
		var tex_h = sprite_node.texture.get_height() * abs(sprite_node.scale.y)
		top_offset = sprite_node.position.y - (tex_h * 0.5)
	
	# Posisikan label melayang pas di atas kepala NPC
	var label_w = 90.0
	var label_h = 24.0
	label_interaksi.rect_size = Vector2(label_w, label_h)
	label_interaksi.align = Label.ALIGN_CENTER
	label_interaksi.valign = Label.VALIGN_CENTER
	
	var pos_x = - (label_w * label_interaksi.rect_scale.x) * 0.5
	var jarak_atas_kepala = 8.0 # Jarak dekat di atas kepala NPC
	label_base_y = top_offset - (jarak_atas_kepala / sy) - (label_h * label_interaksi.rect_scale.y)
	label_interaksi.rect_position = Vector2(pos_x, label_base_y)

func _on_body_entered(body):
	if body.name == "Player" or body.is_in_group("player"):
		player_dalam_area = true
		if not dialog_sedang_berjalan and not Global.cutscene_aktif and not Global.dialog_aktif:
			label_interaksi.show()

func _on_body_exited(body):
	if body.name == "Player" or body.is_in_group("player"):
		player_dalam_area = false
		label_interaksi.hide()

func _unhandled_input(event):
	# Blokir tombol interaksi jika ada cutscene atau dialog yang sedang berlangsung
	if Global.cutscene_aktif or Global.dialog_aktif or Global.is_dialogue_playing():
		return
	if player_dalam_area and not dialog_sedang_berjalan and event.is_action_pressed("interact"):
		if dialogue_resource:
			buka_dialog()

func buka_dialog():
	dialog_sedang_berjalan = true
	label_interaksi.hide()
	Global.play_sfx_encounter()
	Global.mulai_dialog()
	# Berikan referensi NPC, Global, dan current scene ke DialogueManager
	var extra_states = [self, Global]
	var current_scene = get_tree().current_scene
	if is_instance_valid(current_scene):
		extra_states.append(current_scene)
	DialogueManager.show_example_dialogue_balloon(dialogue_start_key, dialogue_resource, extra_states)

func _on_dialog_tutup():
	# Karena toa global didengar SEMUA NPC, pastikan hanya NPC yang sedang aktif yang bereaksi
	if dialog_sedang_berjalan:
		dialog_sedang_berjalan = false
		emit_signal("dialog_selesai", dialogue_start_key)
		
		# Kemunculan kembali tombol [F] hanya jika player di area dan cutscene tidak aktif
		if player_dalam_area and not Global.cutscene_aktif and not Global.dialog_aktif:
			label_interaksi.show()
