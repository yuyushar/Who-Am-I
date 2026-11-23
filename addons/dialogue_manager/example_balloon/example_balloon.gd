extends CanvasLayer


signal actioned(next_id)


onready var balloon := $Balloon
onready var margin := $Balloon/Margin
onready var character_label := $Balloon/Margin/VBox/Character
onready var dialogue_label := $Balloon/Margin/VBox/Dialogue
onready var responses_menu := $Balloon/Margin/VBox/Responses
onready var response_template := $ResponseTemplate

var portraits: Control
var portrait_left: TextureRect
var portrait_right: TextureRect

var dialogue_resource: Resource
var dialogue_line: Dictionary
var is_waiting_for_input: bool = false
var can_select_response: bool = false


func _ready() -> void:
	if dialogue_line.size() == 0:
		queue_free()
		return
	
	add_to_group("dialogue_balloon")
	
	var global_node = get_node_or_null("/root/Global")
	if global_node != null:
		global_node.dialog_aktif = true
		if is_instance_valid(global_node.dim_rect) and not global_node.cutscene_aktif:
			global_node.dim_rect.visible = true
			
	apply_zone_theme()
	_ensure_portrait_nodes()
	
	if not dialogue_label.is_connected("spoke", self, "_on_dialogue_spoke"):
		dialogue_label.connect("spoke", self, "_on_dialogue_spoke")
	
	response_template.hide()
	balloon.modulate.a = 0
	if portraits:
		portraits.modulate.a = 0
	
	var viewport_size = balloon.get_viewport_rect().size
	balloon.anchor_right = 1
	balloon.rect_min_size = Vector2(viewport_size.x * 0.9, 0)
	balloon.rect_size = Vector2.ZERO
	
	var speaker_name = dialogue_line.character
	if global_node != null and speaker_name == "Player" and global_node.player_name != "":
		speaker_name = global_node.player_name
		
	character_label.visible = speaker_name != ""
	if "redacted" in speaker_name.to_lower():
		if not ("[shake" in speaker_name.to_lower()):
			character_label.bbcode_text = "[shake rate=20 level=10]" + speaker_name + "[/shake]"
		else:
			character_label.bbcode_text = speaker_name
	else:
		character_label.bbcode_text = speaker_name
	
	dialogue_label.rect_size.x = balloon.rect_size.x - margin.get("custom_constants/margin_left") - margin.get("custom_constants/margin_right")
	dialogue_label.dialogue_line = dialogue_line
	yield(dialogue_label.reset_height(), "completed")
	
	# Show any responses we have
	if dialogue_line.responses.size() > 0:
		for response in dialogue_line.responses:
			# Duplicate the template so we can grab the fonts, sizing, etc
			var item: RichTextLabel = response_template.duplicate(0)
			item.name = "Response" + str(responses_menu.get_child_count())
			if not response.is_allowed:
				item.name += "Disallowed"
			item.fit_content_height = true
			item.scroll_active = false
			item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			item.bbcode_text = response.text
			item.connect("mouse_entered", self, "_on_response_mouse_entered", [item])
			item.connect("gui_input", self, "_on_response_gui_input", [item])
			item.show()
			responses_menu.add_child(item)
	
	# Make sure our responses get included in the height reset
	responses_menu.modulate.a = 0.0
	responses_menu.visible = true
	margin.rect_size = Vector2(0, 0)
	
	yield(get_tree(), "idle_frame")
	
	# Hitung tinggi dinamis tiap opsi respon agar teks panjang (seperti opsi Moxie) tidak terpotong!
	for child in responses_menu.get_children():
		if child is RichTextLabel and child.visible:
			var content_h = child.get_content_height()
			var target_h = max(45.0, content_h + 16.0)
			child.rect_min_size = Vector2(0, target_h)
			
	yield(get_tree(), "idle_frame")

	balloon.rect_min_size = margin.rect_size
	balloon.rect_size = Vector2(0, 0)
	balloon.rect_global_position = Vector2((viewport_size.x - balloon.rect_size.x) * 0.5, viewport_size.y - balloon.rect_size.y - viewport_size.y * 0.02)
	
	# Update posisi dan aset portrait karakter
	setup_portraits(viewport_size)
		
	# Pastikan menu respon tersembunyi selama teks dialog sedang diketik
	responses_menu.visible = false

	# Show our box & portraits
	balloon.modulate.a = 1
	if portraits:
		portraits.modulate.a = 1
	
	if dialogue_line.text != "":
		dialogue_label.type_out()
		yield(dialogue_label, "finished")
	
	# Menu pilihan jawaban HANYA muncul setelah teks dialog selesai diketik sepenuhnya
	if dialogue_line.responses.size() > 0:
		if global_node != null:
			global_node.set_pilihan_dialog_aktif(true)
		responses_menu.modulate.a = 0.0
		responses_menu.visible = true
		margin.rect_size = Vector2(0, 0)
		yield(get_tree(), "idle_frame")
		balloon.rect_min_size = margin.rect_size
		balloon.rect_size = Vector2.ZERO
		balloon.rect_global_position = Vector2((viewport_size.x - balloon.rect_size.x) * 0.5, viewport_size.y - balloon.rect_size.y - viewport_size.y * 0.02)
		setup_portraits(viewport_size)
		configure_focus()
		is_waiting_for_input = true
		
		# Animasi fade-in halus untuk menu respon
		var t = Tween.new()
		add_child(t)
		t.interpolate_property(responses_menu, "modulate:a", 0.0, 1.0, 0.22, Tween.TRANS_SINE, Tween.EASE_OUT)
		t.start()
		
		# Kunci pemilihan respon selama 0.35 detik (350 ms) agar pemain tidak sengaja langsung memilih opsi
		can_select_response = false
		yield(get_tree().create_timer(0.35), "timeout")
		can_select_response = true
		if is_instance_valid(t):
			t.queue_free()
	elif dialogue_line.time != null:
		var time = dialogue_line.text.length() * 0.02 if dialogue_line.time == "auto" else dialogue_line.time.to_float()
		yield(get_tree().create_timer(time), "timeout")
		next(dialogue_line.next_id)
	else:
		is_waiting_for_input = true
		balloon.focus_mode = Control.FOCUS_ALL
		balloon.grab_focus()

func apply_zone_theme() -> void:
	var scene_name = ""
	var current_scene = get_tree().current_scene
	if is_instance_valid(current_scene):
		scene_name = current_scene.filename.to_lower()
		if scene_name == "":
			scene_name = current_scene.name.to_lower()
			
	var resource_path = ""
	if dialogue_resource != null:
		resource_path = dialogue_resource.resource_path.to_lower()
		
	var is_fantasy = ("zone01" in scene_name) or ("village" in scene_name) or ("village" in resource_path)
	var is_modern = ("zone02" in scene_name) or ("modern" in scene_name) or ("modern" in resource_path)
	var is_future = ("zone03" in scene_name) or ("future" in scene_name) or ("future" in resource_path)
	var is_skycity = ("zone04" in scene_name) or ("skycity" in scene_name) or ("skycity" in resource_path)
	
	var box_style = StyleBoxFlat.new()
	box_style.corner_radius_top_left = 14
	box_style.corner_radius_top_right = 14
	box_style.corner_radius_bottom_right = 14
	box_style.corner_radius_bottom_left = 14
	box_style.border_width_left = 3
	box_style.border_width_top = 3
	box_style.border_width_right = 3
	box_style.border_width_bottom = 3
	box_style.shadow_size = 12
	box_style.shadow_offset = Vector2(0, 6)
	
	var resp_normal_style = StyleBoxFlat.new()
	resp_normal_style.corner_radius_top_left = 8
	resp_normal_style.corner_radius_top_right = 8
	resp_normal_style.corner_radius_bottom_right = 8
	resp_normal_style.corner_radius_bottom_left = 8
	resp_normal_style.content_margin_left = 22.0
	resp_normal_style.content_margin_right = 22.0
	resp_normal_style.content_margin_top = 8.0
	resp_normal_style.content_margin_bottom = 8.0
	resp_normal_style.border_width_left = 1
	resp_normal_style.border_width_top = 1
	resp_normal_style.border_width_right = 1
	resp_normal_style.border_width_bottom = 1
	
	var resp_focus_style = StyleBoxFlat.new()
	resp_focus_style.corner_radius_top_left = 8
	resp_focus_style.corner_radius_top_right = 8
	resp_focus_style.corner_radius_bottom_right = 8
	resp_focus_style.corner_radius_bottom_left = 8
	resp_focus_style.content_margin_left = 24.0
	resp_focus_style.content_margin_right = 24.0
	resp_focus_style.content_margin_top = 10.0
	resp_focus_style.content_margin_bottom = 10.0
	resp_focus_style.border_width_left = 3
	resp_focus_style.border_width_top = 3
	resp_focus_style.border_width_right = 3
	resp_focus_style.border_width_bottom = 3
	resp_focus_style.shadow_size = 10
	resp_focus_style.shadow_offset = Vector2(0, 4)
	
	var char_color = Color(1.0, 1.0, 1.0, 1.0)
	var text_color = Color(0.96, 0.96, 0.98, 1.0)
	
	if is_fantasy:
		# --- TEMA 1: DESA FANTASI (World 1: Kayu Hangat & Emas Kerajaan) ---
		box_style.bg_color = Color(0.11, 0.08, 0.05, 0.94)
		box_style.border_color = Color(0.85, 0.67, 0.30, 1.0)
		box_style.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
		
		char_color = Color(1.0, 0.86, 0.40, 1.0)
		text_color = Color(0.97, 0.95, 0.90, 1.0)
		
		resp_normal_style.bg_color = Color(0.18, 0.13, 0.09, 0.82)
		resp_normal_style.border_color = Color(0.50, 0.38, 0.20, 0.85)
		
		resp_focus_style.bg_color = Color(0.38, 0.28, 0.12, 0.95)
		resp_focus_style.border_color = Color(1.0, 0.85, 0.40, 1.0)
		resp_focus_style.shadow_size = 6
		resp_focus_style.shadow_color = Color(0.85, 0.67, 0.30, 0.3)
		
	elif is_modern:
		# --- TEMA 2: MODERN ANIME CITY (World 2: Cyber Slate & Sky Cyan) ---
		box_style.bg_color = Color(0.07, 0.10, 0.17, 0.94)
		box_style.border_color = Color(0.30, 0.68, 1.0, 1.0)
		box_style.shadow_color = Color(0.02, 0.05, 0.14, 0.70)
		
		char_color = Color(0.42, 0.90, 1.0, 1.0)
		text_color = Color(0.95, 0.98, 1.0, 1.0)
		
		resp_normal_style.bg_color = Color(0.11, 0.16, 0.26, 0.82)
		resp_normal_style.border_color = Color(0.24, 0.42, 0.70, 0.85)
		
		resp_focus_style.bg_color = Color(0.14, 0.32, 0.60, 0.95)
		resp_focus_style.border_color = Color(0.45, 0.92, 1.0, 1.0)
		resp_focus_style.shadow_size = 6
		resp_focus_style.shadow_color = Color(0.30, 0.68, 1.0, 0.35)
		
	elif is_future:
		# --- TEMA 3: THE NEXUS / FUTURE CYBER (World 3: Holographic Neon & Obsidian Tech) ---
		box_style.bg_color = Color(0.04, 0.07, 0.14, 0.94)
		box_style.border_color = Color(0.0, 0.88, 1.0, 1.0) # Neon Cyan
		box_style.shadow_color = Color(0.0, 0.50, 0.90, 0.55)
		box_style.shadow_size = 14
		box_style.shadow_offset = Vector2(0, 4)
		
		char_color = Color(0.20, 0.95, 1.0, 1.0) # Bright Hologram Cyan
		text_color = Color(0.92, 0.97, 1.0, 1.0) # Crisp Sci-Fi White
		
		resp_normal_style.bg_color = Color(0.06, 0.12, 0.22, 0.85)
		resp_normal_style.border_color = Color(0.18, 0.50, 0.75, 0.85)
		resp_normal_style.border_width_left = 2
		resp_normal_style.border_width_top = 2
		resp_normal_style.border_width_right = 2
		resp_normal_style.border_width_bottom = 2
		
		resp_focus_style.bg_color = Color(0.08, 0.28, 0.55, 0.95)
		resp_focus_style.border_color = Color(0.15, 0.98, 1.0, 1.0)
		resp_focus_style.shadow_size = 10
		resp_focus_style.shadow_color = Color(0.0, 0.85, 1.0, 0.45)
		
	elif is_skycity:
		# --- TEMA 4: SKY CITY / CELESTIAL HAVEN (World 4: Royal Azure & Celestial Gold) ---
		box_style.bg_color = Color(0.06, 0.11, 0.22, 0.94) # Deep Celestial Navy
		box_style.border_color = Color(0.96, 0.82, 0.42, 1.0) # Radiant Celestial Gold
		box_style.shadow_color = Color(0.0, 0.22, 0.48, 0.60) # Sunlit Azure Glow Shadow
		box_style.shadow_size = 14
		box_style.shadow_offset = Vector2(0, 5)
		
		char_color = Color(1.0, 0.88, 0.48, 1.0) # Luminous Astrolabe Gold
		text_color = Color(0.96, 0.98, 1.0, 1.0) # Pristine Pearl White
		
		resp_normal_style.bg_color = Color(0.09, 0.16, 0.30, 0.85)
		resp_normal_style.border_color = Color(0.85, 0.72, 0.38, 0.85)
		resp_normal_style.border_width_left = 2
		resp_normal_style.border_width_top = 2
		resp_normal_style.border_width_right = 2
		resp_normal_style.border_width_bottom = 2
		
		resp_focus_style.bg_color = Color(0.14, 0.32, 0.58, 0.96) # Royal Airship Blue
		resp_focus_style.border_color = Color(1.0, 0.92, 0.55, 1.0) # Shimmering Gold
		resp_focus_style.shadow_size = 10
		resp_focus_style.shadow_color = Color(0.96, 0.82, 0.42, 0.45)
		
	else:
		# --- TEMA PROLOGUE / DEFAULT: COSMIC VOID (Astral Midnight & Violet) ---
		box_style.bg_color = Color(0.09, 0.07, 0.15, 0.94)
		box_style.border_color = Color(0.68, 0.52, 0.95, 1.0)
		box_style.shadow_color = Color(0.0, 0.0, 0.0, 0.70)
		
		char_color = Color(0.85, 0.75, 1.0, 1.0)
		text_color = Color(0.96, 0.95, 0.98, 1.0)
		
		resp_normal_style.bg_color = Color(0.15, 0.11, 0.24, 0.82)
		resp_normal_style.border_color = Color(0.45, 0.34, 0.68, 0.85)
		
		resp_focus_style.bg_color = Color(0.30, 0.20, 0.50, 0.95)
		resp_focus_style.border_color = Color(0.85, 0.65, 1.0, 1.0)
		resp_focus_style.shadow_size = 6
		resp_focus_style.shadow_color = Color(0.68, 0.52, 0.95, 0.35)
		
	balloon.add_stylebox_override("panel", box_style)
	
	character_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	character_label.add_color_override("default_color", char_color)
	character_label.set("custom_colors/font_color_shadow", Color(0, 0, 0, 0.85))
	character_label.set("custom_constants/shadow_offset_x", 1)
	character_label.set("custom_constants/shadow_offset_y", 1)
	
	dialogue_label.add_color_override("default_color", text_color)
	dialogue_label.set("custom_colors/font_color_shadow", Color(0, 0, 0, 0.85))
	dialogue_label.set("custom_constants/shadow_offset_x", 1)
	dialogue_label.set("custom_constants/shadow_offset_y", 1)
	
	response_template.add_color_override("default_color", text_color)
	response_template.set("custom_colors/font_color_shadow", Color(0, 0, 0, 0.85))
	response_template.set("custom_constants/shadow_offset_x", 1)
	response_template.set("custom_constants/shadow_offset_y", 1)
	response_template.add_stylebox_override("normal", resp_normal_style)
	response_template.add_stylebox_override("focus", resp_focus_style)


func _ensure_portrait_nodes() -> void:
	if has_node("Portraits"):
		portraits = $Portraits
		if portraits.has_node("PortraitLeft"):
			portrait_left = $Portraits/PortraitLeft
		if portraits.has_node("PortraitRight"):
			portrait_right = $Portraits/PortraitRight
	
	if portraits == null:
		portraits = Control.new()
		portraits.name = "Portraits"
		portraits.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(portraits)
		move_child(portraits, 0) # Taruh di belakang Balloon
	
	if portrait_left == null:
		portrait_left = TextureRect.new()
		portrait_left.name = "PortraitLeft"
		portrait_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait_left.expand = true
		portrait_left.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portraits.add_child(portrait_left)
		
	if portrait_right == null:
		portrait_right = TextureRect.new()
		portrait_right.name = "PortraitRight"
		portrait_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait_right.expand = true
		portrait_right.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portraits.add_child(portrait_right)


func setup_portraits(_viewport_size: Vector2) -> void:
	if not portraits or not portrait_left or not portrait_right:
		return
	
	var global_node = get_node_or_null("/root/Global")
	if global_node == null:
		portrait_left.visible = false
		portrait_right.visible = false
		return
	
	var current_speaker = dialogue_line.get("character", "")
	var next_id = dialogue_line.get("next_id", "")
	
	var speaker_info = global_node.update_dialog_speakers(current_speaker, dialogue_resource, next_id)
	var left_char = speaker_info.get("left_char", "")
	var right_char = speaker_info.get("right_char", "")
	var active_side = speaker_info.get("active_side", "")
	
	var portrait_size = Vector2(300, 320)
	var overlap_y = 30.0
	var target_y = balloon.rect_global_position.y + overlap_y - portrait_size.y
	
	# === SISI KIRI ===
	if left_char != "":
		var left_key = global_node.get_character_key(left_char)
		# Jika hanya 1 orang dalam dialog, karakter kiri bicara terus (_dialog1)
		var is_left_talking = (active_side == "left") or (active_side == "" and right_char == "")
		var left_tex = global_node.get_portrait_texture(left_key, is_left_talking)
		if left_tex != null:
			portrait_left.texture = left_tex
			portrait_left.rect_min_size = portrait_size
			portrait_left.rect_size = portrait_size
			portrait_left.rect_pivot_offset = portrait_size / 2.0
			
			# PENGATURAN ARAH HADAP (SISI KIRI):
			# Seluruh NPC (termasuk C, Myra, Ronnie di Zone 4) aset dasarnya menghadap kiri.
			# Jika berada di kiri, dibalik (flip_h = true) agar menghadap ke kanan (ke lawan bicara).
			# Karakter Player, Guide, Gatekeeper aslinya sudah hadap kanan, jadi tidak perlu diflip (flip_h = false).
			var left_faces_left_by_default = not (left_key in ["p", "g", "gk"])
			if "flip_h" in portrait_left:
				portrait_left.set("flip_h", left_faces_left_by_default)
			portrait_left.rect_scale = Vector2(1, 1)
			portrait_left.rect_position = Vector2(balloon.rect_global_position.x + 30.0, target_y)
			
			# PENGATURAN CAHAYA (BICARA VS DIAM):
			if global_node.is_portrait_fallback_dimmed(left_key, is_left_talking):
				portrait_left.modulate = Color(0.45, 0.45, 0.45, 1.0)
			else:
				portrait_left.modulate = Color(1.0, 1.0, 1.0, 1.0)
				
			portrait_left.visible = true
		else:
			portrait_left.visible = false
	else:
		portrait_left.visible = false
	
	# === SISI KANAN ===
	if right_char != "":
		var right_key = global_node.get_character_key(right_char)
		var is_right_talking = (active_side == "right")
		var right_tex = global_node.get_portrait_texture(right_key, is_right_talking)
		if right_tex != null:
			portrait_right.texture = right_tex
			portrait_right.rect_min_size = portrait_size
			portrait_right.rect_size = portrait_size
			portrait_right.rect_pivot_offset = portrait_size / 2.0
			
			# PENGATURAN ARAH HADAP (SISI KANAN):
			# Seluruh NPC (termasuk C, Myra, Ronnie di Zone 4) aset dasarnya SUDAH menghadap kiri.
			# Karena ditaruh di kanan, JANGAN dibalik (flip_h = false) agar tetap menghadap ke kiri (ke lawan bicara).
			# Karakter seperti Player, Guide, atau Gatekeeper yang aslinya hadap kanan, baru dibalik (flip_h = true).
			var right_faces_left_by_default = not (right_key in ["p", "g", "gk"])
			if "flip_h" in portrait_right:
				portrait_right.set("flip_h", not right_faces_left_by_default)
			portrait_right.rect_scale = Vector2(1, 1)
			
			var target_right_x = balloon.rect_global_position.x + balloon.rect_size.x - portrait_size.x - 30.0
			portrait_right.rect_position = Vector2(target_right_x, target_y)
			
			# PENGATURAN CAHAYA (BICARA VS DIAM):
			if global_node.is_portrait_fallback_dimmed(right_key, is_right_talking):
				portrait_right.modulate = Color(0.45, 0.45, 0.45, 1.0)
			else:
				portrait_right.modulate = Color(1.0, 1.0, 1.0, 1.0)
				
			portrait_right.visible = true
		else:
			portrait_right.visible = false
	else:
		portrait_right.visible = false


func _unhandled_input(event: InputEvent) -> void:
	# Jika dialog sedang aktif, tangani input tombol navigasi dialog
	get_tree().set_input_as_handled()
	
	var is_confirm = event.is_action_pressed("ui_accept") or event.is_action_pressed("interact") \
		or (event is InputEventKey and event.pressed and not event.echo and (event.scancode == KEY_F or event.scancode == KEY_SPACE or event.scancode == KEY_ENTER)) \
		or (event is InputEventMouseButton and event.is_pressed() and event.button_index == BUTTON_LEFT)
	var is_up = event.is_action_pressed("move_up") or event.is_action_pressed("ui_up") \
		or (event is InputEventKey and event.pressed and not event.echo and (event.scancode == KEY_W or event.scancode == KEY_UP))
	var is_down = event.is_action_pressed("move_down") or event.is_action_pressed("ui_down") \
		or (event is InputEventKey and event.pressed and not event.echo and (event.scancode == KEY_S or event.scancode == KEY_DOWN))
	
	# 1. Jika teks masih mengetik, tekan tombol konfirmasi (F/Space) untuk langsung menampilkan teks penuh
	if is_instance_valid(dialogue_label) and dialogue_label.is_typing and dialogue_label.percent_visible < 1.0:
		if is_confirm:
			dialogue_label.percent_visible = 1.0
			dialogue_label.is_typing = false
			dialogue_label.has_finished = true
			dialogue_label.emit_signal("finished")
			return
			
	if not is_waiting_for_input:
		return
		
	# 2. Jika ada menu pilihan respon (Options Menu):
	if dialogue_line.responses.size() > 0:
		var items = get_responses()
		if items.size() > 0:
			var curr_idx = -1
			for i in range(items.size()):
				if items[i].has_focus():
					curr_idx = i
					break
			if curr_idx == -1:
				curr_idx = 0
				items[0].grab_focus()
				
			if is_up:
				var prev_idx = (curr_idx - 1 + items.size()) % items.size()
				items[prev_idx].grab_focus()
			elif is_down:
				var next_idx = (curr_idx + 1) % items.size()
				items[next_idx].grab_focus()
			elif is_confirm:
				if not can_select_response:
					return
				if curr_idx >= 0 and curr_idx < items.size():
					next(dialogue_line.responses[items[curr_idx].get_index()].next_id)
		return
		
	# 3. Jika dialog narasi biasa (tanpa opsi): Tekan F atau Space untuk lanjut ke dialog berikutnya
	if is_confirm:
		next(dialogue_line.next_id)


func next(next_id: String) -> void:
	var global_node = get_node_or_null("/root/Global")
	if global_node != null:
		global_node.set_pilihan_dialog_aktif(false)
	emit_signal("actioned", next_id)
	queue_free()

func _exit_tree() -> void:
	var global_node = get_node_or_null("/root/Global")
	if global_node != null:
		global_node.set_pilihan_dialog_aktif(false)


### Helpers


func configure_focus() -> void:
	responses_menu.show()
	
	var items = get_responses()
	for i in items.size():
		var item: Control = items[i]
		
		item.focus_mode = Control.FOCUS_ALL
		
		item.focus_neighbour_left = item.get_path()
		item.focus_neighbour_right = item.get_path()
		
		if i == 0:
			item.focus_neighbour_top = item.get_path()
			item.focus_previous = item.get_path()
		else:
			item.focus_neighbour_top = items[i - 1].get_path()
			item.focus_previous = items[i - 1].get_path()
		
		if i == items.size() - 1:
			item.focus_neighbour_bottom = item.get_path()
			item.focus_next = item.get_path()
		else:
			item.focus_neighbour_bottom = items[i + 1].get_path()
			item.focus_next = items[i + 1].get_path()
	
	items[0].grab_focus()


func get_responses() -> Array:
	var items: Array = []
	for child in responses_menu.get_children():
		if "disallowed" in child.name.to_lower(): continue
		items.append(child)
		
	return items


### Signals


func _on_response_mouse_entered(item):
	if not "disallowed" in item.name.to_lower():
		item.grab_focus()
		var global_node = get_node_or_null("/root/Global")
		if global_node != null and global_node.has_method("play_sfx_hover"):
			global_node.play_sfx_hover()


func _on_response_gui_input(event, item):
	if "disallowed" in item.name.to_lower(): return
	if not can_select_response: return
	
	var is_click = event is InputEventMouseButton and event.is_pressed() and event.button_index == 1
	var is_key_confirm = (event.is_action_pressed("ui_accept") or event.is_action_pressed("interact") \
		or (event is InputEventKey and event.pressed and not event.echo and (event.scancode == KEY_F or event.scancode == KEY_SPACE or event.scancode == KEY_ENTER)))
	
	var is_up = event.is_action_pressed("move_up") or event.is_action_pressed("ui_up") \
		or (event is InputEventKey and event.pressed and not event.echo and (event.scancode == KEY_W or event.scancode == KEY_UP))
	var is_down = event.is_action_pressed("move_down") or event.is_action_pressed("ui_down") \
		or (event is InputEventKey and event.pressed and not event.echo and (event.scancode == KEY_S or event.scancode == KEY_DOWN))
		
	if is_up or is_down:
		var items = get_responses()
		if items.size() > 0:
			var curr_idx = items.find(item)
			if curr_idx == -1:
				curr_idx = 0
			if is_up:
				var prev_idx = (curr_idx - 1 + items.size()) % items.size()
				items[prev_idx].grab_focus()
				var global_node = get_node_or_null("/root/Global")
				if global_node != null and global_node.has_method("play_sfx_hover"):
					global_node.play_sfx_hover()
			elif is_down:
				var next_idx = (curr_idx + 1) % items.size()
				items[next_idx].grab_focus()
				var global_node = get_node_or_null("/root/Global")
				if global_node != null and global_node.has_method("play_sfx_hover"):
					global_node.play_sfx_hover()
		get_tree().set_input_as_handled()
		return
	
	if is_click or (is_key_confirm and item in get_responses()):
		var global_node = get_node_or_null("/root/Global")
		if global_node != null and global_node.has_method("play_sfx_button"):
			global_node.play_sfx_button()
		next(dialogue_line.responses[item.get_index()].next_id)


# When there are no response options the balloon itself is the clickable thing
func _on_Balloon_gui_input(event):
	var is_click = event is InputEventMouseButton and event.is_pressed() and event.button_index == 1
	var is_key_confirm = (event.is_action_pressed("ui_accept") or event.is_action_pressed("interact") \
		or (event is InputEventKey and event.pressed and not event.echo and (event.scancode == KEY_F or event.scancode == KEY_SPACE or event.scancode == KEY_ENTER)))
	
	if not (is_click or is_key_confirm):
		return
	
	get_tree().set_input_as_handled()
	
	# Jika teks masih mengetik, klik mouse atau tombol konfirmasi langsung menampilkan teks penuh
	if is_instance_valid(dialogue_label) and dialogue_label.is_typing and dialogue_label.percent_visible < 1.0:
		dialogue_label.percent_visible = 1.0
		dialogue_label.is_typing = false
		dialogue_label.has_finished = true
		dialogue_label.emit_signal("finished")
		return
	
	if not is_waiting_for_input:
		return
	
	next(dialogue_line.next_id)

func _on_dialogue_spoke(letter: String, _speed: float) -> void:
	if letter != " " and letter != "\n" and letter != "\t":
		var is_redacted: bool = false
		if dialogue_line != null and dialogue_line.has("character"):
			var char_name = str(dialogue_line.character).to_lower()
			if "redacted" in char_name:
				is_redacted = true
		var global_node = get_node_or_null("/root/Global")
		if global_node != null and global_node.has_method("play_sfx_dialog"):
			global_node.play_sfx_dialog(is_redacted)
