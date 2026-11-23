# Who Am I

**Who Am I** adalah game eksplorasi 2D berbasis cerita yang dirancang untuk mendeteksi kecenderungan tipe personalitas **MBTI** (*Myers-Briggs Type Indicator*) pemain melalui interaksi dan pengambilan keputusan di sepanjang permainan.

---

## Sinopsis

Kamu tersadar di hamparan kehampaan tanpa ingatan tentang siapa dirimu yang sebenarnya. Ditemani oleh sesosok pemandu misterius, langkah kakimu akan membawamu melintasi 4 dimensi dunia yang berbeda untuk mencari kembali serpihan kesadaran yang tercerai-berai.

Setiap keputusan dan pertimbangan yang kamu pilih saat berinteraksi dengan warga maupun entitas di setiap dunia akan merefleksikan kecenderungan personalitasmu, hingga akhirnya mengungkap identitas sejati di akhir cerita.

---

## Fitur Utama

- **4 Dimensi Dunia yang Berbeda**:
  1. **Zone 01** — Desa Festival (*Extraversion / Introversion*)
  2. **Zone 02** — Taman Kota Modern (*Sensing / Intuition*)
  3. **Zone 03** — Megapolis Futuristik *The Nexus* (*Thinking / Feeling*)
  4. **Zone 04** — Kepulauan Terapung di Atas Awan (*Judging / Perceiving*)
- **Sistem Dialog Interaktif**: Pilihan dialog dan tindakan yang memengaruhi perhitungan skor MBTI.
- **Directory & Statistik MBTI**: Melacak progres dan hasil identifikasi tipe personalitas.
- **Panduan & Menu Jeda**: Dilengkapi *Guide*, *About*, dan *Pause Menu* untuk kenyamanan bermain.

---

## Kontrol Permainan

| Tombol | Aksi |
| :--- | :--- |
| `W` `A` `S` `D` | Bergerak (Atas, Kiri, Bawah, Kanan) |
| `Shift` | Berlari (*Sprint*) |
| `F` | Berinteraksi / Berbicara dengan NPC |
| `Klik Kiri Mouse` | Memilih opsi dialog & navigasi menu |

---

## Cara Menjalankan

### 1. Melalui File Build (Windows)
1. Unduh file rilis (`.zip`) pada halaman **Releases** di repositori GitHub ini.
2. Ekstrak file `.zip` tersebut.
3. Jalankan `WhoAmI.exe`.

### 2. Melalui Godot Engine (Source Code)
1. Pastikan **Godot Engine 3.6.1 (stable)** sudah terpasang.
2. Clone atau unduh repositori ini.
3. Buka Godot Project Manager, pilih **Import**, lalu arahkan ke file `project.godot`.
4. Jalankan proyek dengan menekan `F5`.

---

## Struktur Proyek

```text
WhoAmI/
├── addons/             # Plugin eksternal (Dialogue Manager)
├── aset/               # Aset gambar, audio, dan font
├── dialogues/          # File skrip dialog (.tres) untuk prolog dan tiap zona
├── scenes/             # Scene UI, karakter, NPC, prolog, ending, dan zona
├── scripts/            # Skrip logika game, player, shader, dan Global.gd
├── mbti_data.json      # Data deskripsi dan profil tipe MBTI
├── project.godot       # Konfigurasi utama proyek Godot
└── export_presets.cfg  # Konfigurasi ekspor build Windows
```

---

## Teknologi yang Digunakan

- **Game Engine**: Godot 3.6.1 stable
- **Bahasa Pemrograman**: GDScript
- **Plugin**: [Dialogue Manager](addons/dialogue_manager)

---

## Pengembang & Kredit

- **Naufal Hanif Satria Wijayanto** (`K3524064`)
- **Yusharyahya Al-Ghifari** (`K3524070`)
- **Dosen Pembimbing**: Febri Liantoni, S.ST., M.Kom

*Proyek ini dibuat untuk memenuhi tugas mata kuliah **Praktikum Multimedia 2**.*
