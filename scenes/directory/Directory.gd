extends Control

const MBTI_ORDER = [
	"ISTJ", "ISFJ", "INFJ", "INTJ",
	"ISTP", "ISFP", "INFP", "INTP",
	"ESTP", "ESFP", "ENFP", "ENTP",
	"ESTJ", "ESFJ", "ENFJ", "ENTJ"
]

const ICON_LOCKED_PATH = "res://scenes/directory/icons/icon_locked.png"

var selected_index: int = 0
var slot_buttons: Array = []
var tween_wobble: Tween = null

onready var grid_container = $MainHBox/LeftSection/GridContainer
onready var detail_title = $MainHBox/RightSection/DetailVBox/TitleLabel
onready var detail_portrait = $MainHBox/RightSection/DetailVBox/PortraitContainer/PortraitTexture
onready var detail_desc = $MainHBox/RightSection/DetailVBox/DescScroll/DescLabel
onready var back_button = $Header/BackButton

func _ready():
	Global.putar_bgm_worldvoid()
	
	tween_wobble = Tween.new()
	add_child(tween_wobble)
	
	_setup_slots()
	_select_slot(0)
	if is_instance_valid(back_button):
		back_button.connect("pressed", self, "_on_back_pressed")

func _setup_slots():
	slot_buttons.clear()
	var children = grid_container.get_children()
	for i in range(min(16, children.size())):
		var btn = children[i]
		var kode = MBTI_ORDER[i]
		var is_unlocked = kode in Global.mbti_terbuka
		
		var icon_rect = btn.get_node_or_null("VBox/Icon")
		var code_label = btn.get_node_or_null("VBox/Code")
		
		if is_instance_valid(icon_rect):
			icon_rect.expand = true
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var icon_path = _get_icon_path(kode) if is_unlocked else ICON_LOCKED_PATH
			if ResourceLoader.exists(icon_path):
				icon_rect.texture = load(icon_path)
				
			if is_unlocked:
				# Ukuran icon memenuhi box (144x135) dengan margin yang rapi dan presisi
				icon_rect.rect_min_size = Vector2(124, 116)
				icon_rect.modulate = Color(1.0, 1.0, 1.0, 1.0)
			else:
				# Icon gembok terkunci berukuran 48x48 tepat di tengah box
				icon_rect.rect_min_size = Vector2(48, 48)
				icon_rect.modulate = Color(0.75, 0.80, 0.90, 0.6)
				
		if is_instance_valid(code_label):
			# Sembunyikan label di dalam slot agar icon badge tampil bersih dan leluasa (nama & kode tampil di panel kanan)
			code_label.visible = false
			code_label.text = ""
			
		btn.connect("pressed", self, "_on_slot_clicked", [i])
		slot_buttons.append(btn)

func _get_icon_path(kode: String) -> String:
	var path_new = "res://aset/Icons Dir/icon_" + kode.to_lower() + ".png"
	if ResourceLoader.exists(path_new):
		return path_new
	return ICON_LOCKED_PATH

func _get_char_portrait_path(kode: String) -> String:
	var path_char = "res://aset/MBTI Chars/" + kode + ".png"
	if ResourceLoader.exists(path_char):
		return path_char
	return ""

func _on_slot_clicked(idx: int):
	var kode = MBTI_ORDER[idx]
	var is_unlocked = kode in Global.mbti_terbuka
	
	if not is_unlocked:
		# SFX tombol terkunci & animasi gembok goyang
		Global.play_sfx_locked()
		_animasi_gembok_goyang(idx)
	else:
		Global.play_sfx_button()
		
	_select_slot(idx)

func _animasi_gembok_goyang(idx: int):
	if idx < 0 or idx >= slot_buttons.size():
		return
	var btn = slot_buttons[idx]
	var icon_rect = btn.get_node_or_null("VBox/Icon")
	if is_instance_valid(icon_rect) and is_instance_valid(tween_wobble):
		var orig_x = icon_rect.rect_position.x
		tween_wobble.stop(icon_rect)
		tween_wobble.interpolate_property(icon_rect, "rect_position:x", orig_x, orig_x - 7.0, 0.05, Tween.TRANS_SINE)
		tween_wobble.interpolate_property(icon_rect, "rect_position:x", orig_x - 7.0, orig_x + 7.0, 0.09, Tween.TRANS_SINE, Tween.EASE_IN_OUT, 0.05)
		tween_wobble.interpolate_property(icon_rect, "rect_position:x", orig_x + 7.0, orig_x - 5.0, 0.08, Tween.TRANS_SINE, Tween.EASE_IN_OUT, 0.14)
		tween_wobble.interpolate_property(icon_rect, "rect_position:x", orig_x - 5.0, orig_x, 0.06, Tween.TRANS_SINE, Tween.EASE_OUT, 0.22)
		tween_wobble.start()

func _select_slot(idx: int):
	if idx < 0 or idx >= MBTI_ORDER.size():
		return
	selected_index = idx
	
	for i in range(slot_buttons.size()):
		var btn = slot_buttons[i]
		var is_sel = (i == selected_index)
		
		# Style highlight bingkai oranye menyala jika terpilih (persis mockup Image 2)
		var sb = StyleBoxFlat.new()
		sb.set_corner_radius_all(6)
		if is_sel:
			sb.bg_color = Color(0.14, 0.16, 0.22, 0.95)
			sb.border_color = Color(0.96, 0.62, 0.08, 1.0) # Orange menyala
			sb.set_border_width_all(3)
		else:
			sb.bg_color = Color(0.10, 0.11, 0.14, 0.95)
			sb.border_color = Color(0.20, 0.23, 0.30, 0.8) # Border gelap subtle
			sb.set_border_width_all(2)
		btn.add_stylebox_override("normal", sb)
		btn.add_stylebox_override("hover", sb)
		btn.add_stylebox_override("pressed", sb)
		btn.add_stylebox_override("focus", StyleBoxEmpty.new())
	
	_tampilkan_detail(MBTI_ORDER[selected_index])

func _tampilkan_detail(kode: String):
	var data = Global.get_mbti_info(kode)
	var is_unlocked = kode in Global.mbti_terbuka
	
	if is_unlocked:
		var role = data.get("role", "")
		var cls = data.get("class", "")
		var desc = data.get("desc", "")
		
		# Format judul: "Role : KODE : Class <class>" (contoh: "Inspector : ISTJ : Class Leader")
		if cls != "":
			detail_title.text = role + " : " + kode + " : Class " + cls
		else:
			detail_title.text = role + " : " + kode
			
		detail_title.modulate = Color(1.0, 1.0, 1.0, 1.0)
		detail_desc.text = desc
		detail_desc.modulate = Color(0.85, 0.90, 0.96, 1.0)
		
		var port_path = _get_char_portrait_path(kode)
		if port_path != "" and ResourceLoader.exists(port_path):
			detail_portrait.texture = load(port_path)
			detail_portrait.visible = true
		else:
			detail_portrait.visible = false
	else:
		# Jangan beri tahu nama/kode MBTI jika belum terbuka!
		detail_title.text = "[ LOCKED ]"
		detail_title.modulate = Color(0.55, 0.60, 0.68, 1.0)
		detail_desc.text = "Kepribadian ini belum ditemukan.\n\nSelesaikan petualangan di seluruh zona dan buat pilihan sesuai kata hatimu untuk membuka kepribadian ini ke dalam Directory!"
		detail_desc.modulate = Color(0.55, 0.60, 0.68, 1.0)
		
		# Tidak perlu menampilkan siluet terkunci
		detail_portrait.texture = null
		detail_portrait.visible = false

func _on_back_pressed():
	Global.play_sfx_button()
	Global.pindah_ke_scene("res://scenes/main_menu/MainMenu.tscn")

func _input(event):
	# Navigasi keyboard (WASD / Panah)
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var row = selected_index / 4
		var col = selected_index % 4
		if event.scancode == KEY_W or event.scancode == KEY_UP:
			row = max(0, row - 1)
			_select_slot(row * 4 + col)
		elif event.scancode == KEY_S or event.scancode == KEY_DOWN:
			row = min(3, row + 1)
			_select_slot(row * 4 + col)
		elif event.scancode == KEY_A or event.scancode == KEY_LEFT:
			col = max(0, col - 1)
			_select_slot(row * 4 + col)
		elif event.scancode == KEY_D or event.scancode == KEY_RIGHT:
			col = min(3, col + 1)
			_select_slot(row * 4 + col)
		elif event.scancode == KEY_ESCAPE:
			_on_back_pressed()
