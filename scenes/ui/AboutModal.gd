extends CanvasLayer

# ==============================================================================
# DATA MODULAR KREDIT & TENTANG GAME
# (Bisa diedit langsung di Inspector Godot atau disesuaikan di variabel bawah ini)
# ==============================================================================
export(String) var judul_modal = "[ TENTANG GAME INI ]"

export(String, MULTILINE) var teks_sinopsis = (
	"Kamu tersadar di hamparan kehampaan tanpa ingatan tentang siapa dirimu yang sebenarnya. " +
	"Ditemani oleh sesosok pemandu misterius nan cerewet, langkah kakimu akan membawamu " +
	"melintasi 4 dimensi dunia yang asing dan penuh teka-teki—mencari kembali serpihan kesadaran yang tercerai-berai."
)

export(String) var header_alur = "APA YANG AKAN KAMU LAKUKAN?"

export(String, MULTILINE) var teks_alur_eksplorasi = (
	"• Menjelajahi Berbagai Dimensi Dunia\n" +
	"  Jelajahi setiap sudut wilayah—mulai dari kedamaian desa festival yang asri, rindangnya taman kota modern, " +
	"megapolis futuristik The Nexus, hingga kepulauan terapung di atas awan.\n\n" +
	"• Berinteraksi & Mengambil Keputusan\n" +
	"  Bicaralah dengan warga atau entitas yang kamu jumpai. Setiap dari mereka memendam dilema dan persoalan hidup. " +
	"Pilihlah jalan keluar dan berikan pertimbanganmu—tidak ada pilihan yang benar atau salah, sebab setiap keputusanmu " +
	"akan merefleksikan caramu memandang kenyataan.\n\n" +
	"• Menemui Penjaga Gerbang (Gatekeeper)\n" +
	"  Setelah seluruh urusan dan bantuanmu pada warga di dunia tersebut tuntas, pergilah menemui Gatekeeper " +
	"di batas dimensi untuk membuka gerbang transisi menuju dunia berikutnya.\n\n" +
	"• Menyingkap Tabir Jati Diri di Akhir Cerita\n" +
	"  Di penghujung seluruh pengembaraan, jejak keputusan, cara pandang, dan respon yang kamu pilih " +
	"akan disintesis untuk mengungkap identitas sejati yang selama ini tersembunyi."
)

export(String) var header_kredit = "PENGEMBANG & KREDIT"

export(Array, String) var daftar_pengembang = [
	"Naufal Hanif Satria Wijayanto (K3524064)",
	"Yusharyahya Al-Ghifari (K3524070)"
]

export(String) var tujuan_proyek = "Menyelesaikan tugas mata kuliah \"Praktikum Multimedia 2\""

export(String) var dosen_pembimbing = "Febri Liantoni, S.ST., M.Kom"

export(Array, String) var penguji_media = [
	"XXX (Penguji Media)",
	"XXX (Penguji Media)",
	"XXX (Penguji Media)"
]

export(String) var mesin_pengembang = "Godot 3.6.1 stable"

# ==============================================================================
# NODE REFERENCES
# ==============================================================================
onready var overlay = $Overlay
onready var panel = $CenterContainer/Panel
onready var scroll_container = $CenterContainer/Panel/VBoxContainer/ScrollContainer
onready var lbl_judul = $CenterContainer/Panel/VBoxContainer/TitleLabel
onready var lbl_sinopsis = $CenterContainer/Panel/VBoxContainer/ScrollContainer/MarginContainer/ListVBox/SinopsisLabel
onready var lbl_header_alur = $CenterContainer/Panel/VBoxContainer/ScrollContainer/MarginContainer/ListVBox/HeaderAlurLabel
onready var lbl_alur = $CenterContainer/Panel/VBoxContainer/ScrollContainer/MarginContainer/ListVBox/AlurLabel
onready var lbl_header_kredit = $CenterContainer/Panel/VBoxContainer/ScrollContainer/MarginContainer/ListVBox/HeaderKreditLabel
onready var lbl_kredit = $CenterContainer/Panel/VBoxContainer/ScrollContainer/MarginContainer/ListVBox/KreditLabel
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
	
	_update_konten_ui()
	
	if is_instance_valid(btn_tutup):
		btn_tutup.connect("pressed", self, "tutup")

func _update_konten_ui():
	if is_instance_valid(lbl_judul):
		lbl_judul.text = judul_modal
	if is_instance_valid(lbl_sinopsis):
		lbl_sinopsis.text = teks_sinopsis
	if is_instance_valid(lbl_header_alur):
		lbl_header_alur.text = header_alur
	if is_instance_valid(lbl_alur):
		lbl_alur.text = teks_alur_eksplorasi
	if is_instance_valid(lbl_header_kredit):
		lbl_header_kredit.text = header_kredit
	if is_instance_valid(lbl_kredit):
		lbl_kredit.text = _format_kredit_text()

func _format_kredit_text() -> String:
	var out = "Game ini dibuat oleh 2 pria hebat:\n"
	for dev in daftar_pengembang:
		out += "  • " + dev + "\n"
	out += "\nTujuan Proyek:\n  " + tujuan_proyek + "\n"
	out += "\nSpecial Thanks To:\n"
	out += "  • Dosen Pembimbing: " + dosen_pembimbing + "\n"
	for penguji in penguji_media:
		out += "  • " + penguji + "\n"
	out += "\nMesin Pengembang:\n  " + mesin_pengembang
	return out

func buka():
	if is_terbuka:
		return
	is_terbuka = true
	visible = true
	
	_was_paused_before = get_tree().paused
	get_tree().paused = true
	Global.about_modal_terbuka = true
	Global.update_mouse_cursor()
	
	var zone_bgm = Global.get_zone_bgm()
	if is_instance_valid(zone_bgm):
		zone_bgm.pause_mode = Node.PAUSE_MODE_PROCESS
		Global.fade_bgm_volume(zone_bgm, -14.0, 0.35)
	
	_update_konten_ui()
	if is_instance_valid(scroll_container):
		scroll_container.scroll_vertical = 0
	
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
		Global.about_modal_terbuka = false
		if not _was_paused_before and not Global.pause_menu_terbuka:
			get_tree().paused = false
		Global.update_mouse_cursor()

func _input(event):
	if is_terbuka and event is InputEventKey and event.is_pressed() and not event.is_echo() and event.scancode == KEY_ESCAPE:
		tutup()
		get_tree().set_input_as_handled()
