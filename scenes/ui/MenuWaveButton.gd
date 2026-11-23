tool
extends Button
class_name MenuWaveButton

export(String) var display_text: String = "> Button"
export(Color) var text_color_normal: Color = Color(1.0, 1.0, 1.0, 1.0)
export(Color) var text_color_hover: Color = Color(1.0, 1.0, 0.7, 1.0)
export(Color) var text_color_disabled: Color = Color(0.42, 0.44, 0.50, 0.45)

# Efek getaran persis dialog [redacted]: [shake rate=20 level=10]
export(bool) var enable_shake: bool = true
export(float) var shake_rate: float = 20.0
export(float) var shake_level: float = 10.0

# Opsi efek wave lama jika sewaktu-waktu dibutuhkan
export(bool) var enable_wave: bool = false
export(float) var wave_amplitude: float = 16.0
export(float) var wave_frequency: float = 6.0

var rtl: RichTextLabel
var base_pos_x: float = 0.0
var is_hovering: bool = false
var font_ref: Font = null
var is_initialized: bool = false

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	flat = true
	base_pos_x = rect_position.x
	focus_mode = Control.FOCUS_NONE
	
	# Hilangkan seluruh border/outline bawaan Godot (focus, pressed, hover, normal)
	var empty_box = StyleBoxEmpty.new()
	add_stylebox_override("focus", empty_box)
	add_stylebox_override("pressed", empty_box)
	add_stylebox_override("hover", empty_box)
	add_stylebox_override("normal", empty_box)
	add_stylebox_override("disabled", empty_box)
	
	if not is_initialized:
		_setup_rtl()
		
	if not is_connected("mouse_entered", self, "_on_mouse_enter"):
		connect("mouse_entered", self, "_on_mouse_enter")
	if not is_connected("mouse_exited", self, "_on_mouse_exit"):
		connect("mouse_exited", self, "_on_mouse_exit")
	if not is_connected("focus_entered", self, "_on_mouse_enter"):
		connect("focus_entered", self, "_on_mouse_enter")
	if not is_connected("focus_exited", self, "_on_mouse_exit"):
		connect("focus_exited", self, "_on_mouse_exit")
	if not is_connected("pressed", self, "_on_button_pressed"):
		connect("pressed", self, "_on_button_pressed")
	if not is_connected("resized", self, "_update_rtl_layout"):
		connect("resized", self, "_update_rtl_layout")
		
	_update_rtl_layout()

func _gui_input(event):
	# Blokir tombol Enter agar tombol UI tidak bisa dipicu oleh Enter
	if event is InputEventKey and (event.scancode == KEY_ENTER or event.scancode == KEY_KP_ENTER):
		accept_event()

func _on_button_pressed():
	if Engine.editor_hint:
		return
	var global = get_node_or_null("/root/Global")
	if global != null and global.has_method("play_sfx_button"):
		global.play_sfx_button()

func _setup_rtl():
	is_initialized = true
	if text != "" and (display_text == "> Button" or display_text == ""):
		display_text = text
	text = ""
	
	font_ref = get_font("font")
	
	rtl = RichTextLabel.new()
	rtl.name = "WaveLabel"
	rtl.bbcode_enabled = true
	rtl.scroll_active = false
	rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rtl.pause_mode = Node.PAUSE_MODE_PROCESS
	
	if font_ref != null:
		rtl.add_font_override("normal_font", font_ref)
		
	add_child(rtl)
	_update_rtl_layout()
	_refresh_display()

func _update_rtl_layout():
	if not is_instance_valid(rtl):
		return
		
	if font_ref == null:
		font_ref = get_font("font")
		if font_ref != null and is_instance_valid(rtl):
			rtl.add_font_override("normal_font", font_ref)
			
	var font_h = font_ref.get_height() if font_ref != null else 36.0
	var btn_h = rect_size.y if rect_size.y > 0 else rect_min_size.y
	if btn_h <= 0:
		btn_h = 54.0
		
	var v_offset = max(-6.0, round((btn_h - font_h) * 0.5))
	
	rtl.anchor_left = 0.0
	rtl.anchor_top = 0.0
	rtl.anchor_right = 1.0
	rtl.anchor_bottom = 0.0
	rtl.margin_left = 0.0
	rtl.margin_top = v_offset
	rtl.margin_right = 20.0
	rtl.margin_bottom = v_offset + font_h + 16.0

func _notification(what):
	if what == NOTIFICATION_RESIZED:
		_update_rtl_layout()

func _process(delta):
	if Engine.editor_hint:
		return
	if disabled:
		return
	if is_hovering:
		# Bergerak maju sedikit ke kanan saat dihover agar terasa responsif & mantap
		rect_position.x = lerp(rect_position.x, base_pos_x + 8.0, 18.0 * delta)
	else:
		if abs(rect_position.x - base_pos_x) > 0.2:
			rect_position.x = lerp(rect_position.x, base_pos_x, 15.0 * delta)
		else:
			rect_position.x = base_pos_x

func _on_mouse_enter():
	if disabled:
		return
	is_hovering = true
	_refresh_display()
	if not Engine.editor_hint:
		var global = get_node_or_null("/root/Global")
		if global != null and global.has_method("play_sfx_hover"):
			global.play_sfx_hover()

func _on_mouse_exit():
	if disabled:
		return
	is_hovering = false
	_refresh_display()

func set_display_text(new_text: String):
	display_text = new_text
	_refresh_display()

func _set(property, value):
	if property == "display_text":
		display_text = value
		_refresh_display()
		return true
	return false

func set_colors(normal_c: Color, hover_c: Color, dis_c: Color = Color(0.42, 0.44, 0.50, 0.45)):
	text_color_normal = normal_c
	text_color_hover = hover_c
	text_color_disabled = dis_c
	_refresh_display()

func set_text_color_normal(c: Color):
	text_color_normal = c
	_refresh_display()

func set_text_color_hover(c: Color):
	text_color_hover = c
	_refresh_display()

func set_text_color_disabled(c: Color):
	text_color_disabled = c
	_refresh_display()

func set_button_disabled(is_dis: bool):
	disabled = is_dis
	mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN if is_dis else Control.CURSOR_POINTING_HAND
	if is_dis:
		is_hovering = false
	_refresh_display()

func _refresh_display():
	if not is_instance_valid(rtl):
		return
		
	var is_centered = (align == 1) # ALIGN_CENTER
	var wrap_open = "[center]" if is_centered else ""
	var wrap_close = "[/center]" if is_centered else ""
	
	if disabled:
		var hex_dis = text_color_disabled.to_html(false)
		rtl.bbcode_text = wrap_open + "[color=#" + hex_dis + "]" + display_text + "[/color]" + wrap_close
		return
		
	if is_hovering:
		var hex_hov = text_color_hover.to_html(false)
		if enable_shake:
			rtl.bbcode_text = wrap_open + "[shake rate=" + str(shake_rate) + " level=" + str(shake_level) + "][color=#" + hex_hov + "]" + display_text + "[/color][/shake]" + wrap_close
		elif enable_wave:
			rtl.bbcode_text = wrap_open + "[wave amp=" + str(wave_amplitude) + " freq=" + str(wave_frequency) + "][color=#" + hex_hov + "]" + display_text + "[/color][/wave]" + wrap_close
		else:
			rtl.bbcode_text = wrap_open + "[color=#" + hex_hov + "]" + display_text + "[/color]" + wrap_close
	else:
		var hex_nor = text_color_normal.to_html(false)
		rtl.bbcode_text = wrap_open + "[color=#" + hex_nor + "]" + display_text + "[/color]" + wrap_close
