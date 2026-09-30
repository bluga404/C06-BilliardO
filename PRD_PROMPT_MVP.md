Ber bertindak sebagai **Senior Product Manager sekaligus iOS Technical Product Manager** yang berpengalaman dalam membangun aplikasi iOS berbasis computer vision.

Saya sedang membangun **BilliardO**, aplikasi iOS untuk membantu pemain biliar mengabadikan dan meninjau momen permainan mereka. Aplikasi ini menggunakan model **object detection dalam format Core ML** untuk mendeteksi bola biliar dari kamera secara real-time.

PRD ini secara khusus mencakup **satu pilar MVP saja: Real-time Camera Detection**. Pilar kedua (video upload dari galeri) dan pilar ketiga (penyimpanan hasil) berada di luar cakupan PRD ini.

## CARA KERJA PROMPT INI

Prompt ini berisi dua hal yang tidak boleh diabaikan:

1. **Fakta Kodebase yang Sudah Terverifikasi** — daftar fakta teknis yang sudah saya konfirmasi langsung dari repository. Gunakan fakta ini apa adanya. Jangan mengarang, menebak, atau menambahkan fakta teknis yang tidak ada di daftar ini.
2. **Keputusan yang Sudah Final** — keputusan arsitektur yang sudah saya ambil. Jangan mengulang ulang pertanyaan tentang hal-hal ini, dan jangan mengusulkan pendekatan alternatif. Tulis sebagai keputusan, bukan sebagai opsi.

Semua angka performa yang belum saya berikan harus ditulis sebagai **TBD / To Validate**, bukan angka karangan.

---

## 1. FAKTA KODEBASE YANG SUDAH TERVERIFIKASI

Gunakan fakta berikut secara eksakis. Fakta ini sudah dikonfirmasi dari isi repository dan hasil build.

### Model

| Item | Nilai |
| ---- | ----- |
| Nama file | `BilliardBallDetector2-10k.mlmodel` |
| Nama resource di bundle | `BilliardBallDetector2-10k.mlmodelc` |
| Jenis | Create ML Object Detector |
| Training | Create ML Object Detector, 10.000 iterasi |
| Jumlah class | 18 |
| Nama class | `ball0` s.d. `ball15`, `ball18`, `ball110` |
| Input | Image (nama input: `imagePath`) |
| Output | `confidence`, `coordinates` |
| Confidence threshold | **0.25** — sudah baked-in di dalam model |
| IoU / NMS threshold | **0.45** — sudah baked-in di dalam model |
| Ukuran file | ± 32 MB |
| Model UID | digenerate Xcode dari nama file |
| Catatan | Threshold 0.25 dan IoU 0.45 sudah dibekukan di dalam model, sehingga Vision tidak lagi perlu memfilter sendiri |

### Proyek

| Item | Nilai |
| ---- | ----- |
| Nama aplikasi | BilliardO |
| Deployment target | iOS 27.0 |
| Bahasa | Swift, mode bahasa Swift 5 (toolchain Swift 6.4) |
| Isolasi default | `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — semua tipe yang dideklarasikan otomatis terisolasi ke MainActor |
| UI | SwiftUI, UIKit hanya untuk wrapper |
| Arsitektur | MVVM |
| Info.plist | Tidak ada file Info.plist, menggunakan `GENERATE_INFOPLIST_FILE = YES` |
| Kamera permission | `NSCameraUsageDescription` **sudah diisi** di build settings |
| Device | iPhone |
| Simulator | **Kamera tidak berfungsi di Simulator** — wajib diuji di device fisik |
| Test target | Belum ada |
| Dependency eksternal | Tidak ada (tidak ada SPM package) |

### Struktur repository

```
BilliardO/         → MyApp.swift, ContentView.swift (root app source)
Features/          → folder fitur (Home, Camera)
Services/          → CameraManager, FrameProcessor, CoreMLModelService, DetectionRenderer
Extensions/        → Assets.xcassets, Model/BilliardBallDetector2-10k.mlmodel
Documentation/     → 01_Coding_Standards.md, 02_Project_Setup.md, 03_Branching_Strategy.md
```

Project menggunakan `PBXFileSystemSynchronizedRootGroup`. File `.swift` baru di dalam `Features/` dan `Services/` akan otomatis ter-compile tanpa perlu edit `.pbxproj`. Folder `Services/` saat PRD ini dibuat **belum terdaftar** sebagai synchronized group di Xcode target, dan harus ditambahkan lebih dulu.

### Model tipe

```swift
struct DetectionResult {
    let label: String
    let confidence: Float
    let boundingBox: CGRect
}
```

`boundingBox` memakai **normalized coordinates**.

---

## 2. KEPUTUSAN YANG SUDAH FINAL

Bagian ini **tidak boleh di-query ulang** dan **tidak boleh diberi alternatif**. Tulis sebagai keputusan yang sudah diambil.

### D-01 — Inference memakai Vision, bukan direct Core ML

MVP memakai `VNCoreMLModel` + `VNCoreMLRequest` untuk menjalankan model. Alasan: model sudah dilatih dengan Create ML Object Detector, output-nya sudah berupa `confidence` + `coordinates` yang bersih, dan Vision sudah menangani preprocessing serta mapping ke `CVPixelBuffer`. Direct Core ML baru relevan jika model diganti dengan keluarga YOLO lain yang tidak kompatibel dengan Vision — dan itu adalah pekerjaan terpisah di masa depan.

### D-02 — Model harus bisa ditukar tanpa menyentuh kamera maupun UI

Ini adalah **hard requirement**, bukan preferensi. Arsitektur wajib menyediakan titik tukar model:

```swift
protocol ObjectDetecting: Sendable {
    func detect(in pixelBuffer: CVPixelBuffer) throws -> [DetectionResult]
}
```

Hanya `ContentView` yang menyebut nama model konkret. Mengganti model = mengubah satu baris di titik injeksi. `CameraManager`, `FrameProcessor`, dan seluruh presentation layer **tidak boleh berubah** ketika model diganti. PRD harus punya acceptance criteria yang secara eksplisit menguji hal ini.
acceptance criteria apa pun yang menguji bahwa mengganti model tidak merusak kamera maupun UI.

### D-03 — Kontrak koordinat

`DetectionResult.boundingBox` adalah:

- **normalized 0–1**
- **origin bottom-left** (konvensi Vision)
- relatif terhadap **frame portrait yang sudah upright**

Rotasi hanya ditangani di `CameraManager`. Tidak ada kode di bawah lapisan capture yang boleh tahu soal orientasi. Model baru yang punya format output berbeda wajib mengonversinya sendiri ke kontrak ini sebelum mengembalikan hasil.

### D-04 — Backpressure

Tidak boleh ada antrean frame yang tidak terbatas. Aturan wajib:

- `alwaysDiscardsLateVideoFrames = true` — kamera yang membuang frame, bukan yang menumpuk
- Inference berjalan di **serial queue yang sama** dengan delegate output video, sehingga secara konstruksi hanya ada satu frame yang sedang diproses
- `FrameProcessor` menolak frame berdasarkan timestamp terhadap `inferenceFramesPerSecond`
- **Dilarang** membuat `DispatchQueue` antrean frame, `OperationQueue`, atau buffer array di mana pun

### D-05 — Frekuensi inference independen dari FPS capture

`inferenceFramesPerSecond` adalah nilai konfigurabel yang **terpisah** dari frame rate kamera. Kamera tetap capturing pada frame rate device default. Mandatory: jangan pernah mengunci `activeVideoMinFrameDuration` atau `activeVideoMaxFrameDuration`, karena keduanya terkunci setelah `startRunning()` dan melempar range error.

### D-06 — Rotation di CameraManager

`CameraManager` mengatur `videoRotationAngle = 90` pada connection milik `AVCaptureVideoDataOutput` supaya buffer yang sampai ke detektor sudah portrait-upright. `CameraViewController` mengatur nilai yang sama pada connection milik `AVCaptureVideoPreviewLayer` supaya preview konsisten.

**Detail penting:** `AVCaptureVideoPreviewLayer.connection` bernilai `nil` sampai session benar-benar terpasang. Karena itu assignment rotasi pada preview layer harus dilakukan di `viewDidAppear` atau setelah `start()`, **bukan** di `viewDidLoad`.

### D-07 — Sepenuhnya on-device

Tidak ada backend, tidak ada cloud, tidak ada upload. Semua inference berjalan di perangkat.

### D-08 — Validasi model tanpa kamera

Karena `ObjectDetecting.detect(in:)` menerima `CVPixelBuffer` dan bukan kamera, model harus bisa diuji tanpa kamera, tanpa permission, dan **di Simulator**, dengan cara mengubah still image menjadi `CVPixelBuffer`.

---

## 3. TUJUAN PRD

Buat PRD yang langsung bisa dipakai oleh:

* Product Designer
* iOS Developer
* ML / Computer Vision Developer

PRD harus membantu tim memahami:

1. Apa yang sedang dibangun dan apa yang **tidak** dibangun.
2. Siapa penggunanya dan masalah apa yang diselesaikan.
3. Bagaimana user flow dari buka aplikasi sampai melihat hasil detection.
4. Bagaimana aplikasi menginteraksi dengan Core ML.
5. Bagaimana frame kamera diproses menjadi bounding box.
6. Bagaimana kontrak koordinat bekerja antara pipeline dan UI.
7. Bagaimana frame dibuang dan inference dikontrol agar tidak menumpuk.
8. Bagaimana model divalidasi tanpa kamera.
9. Apa acceptance criteria setiap requirement.
10. Apa batasan teknis, error state, dan open question yang tersisa.

## 4. STRUKTUR PRD

### 4.1 Product Overview

* Product name
* Product type
* Platform
* One-sentence product description
* Product vision
* MVP scope — **hanya real-time camera detection**

### 4.2 Problem Statement

Jelaskan current situation, user problem, pain points, why it matters, existing workaround.

Jangan langsung menjadikan solusi teknis sebagai problem. Jangan mengarang hasil user research.

### 4.3 Target Users

Primary user, secondary user, user context, motivation, constraints.

Informasi yang belum cukup ditandai sebagai **Assumption / To Validate**. Jangan mengarang demografi, umur, atau habit pemain biliar.

### 4.4 Product Goals

Pisahkan **user goals**, **product goals**, dan **technical goals**.

Technical goals harus mencerminkan keputusan D-01 sampai D-08. Jangan membuat business metrics yang tidak memiliki dasar.

### 4.5 Non-Goals

Fitur yang secara eksplisit di luar PRD ini:

* Video upload dari galeri / PhotosPicker — pilar MVP berikutnya
* Penyimpanan atau persistensi hasil detection
* Automatic highlight generation
* Ball trajectory prediction
* Shot classification
* AI coaching
* Score keeping
* Replay generation
* Cloud video storage
* Multiplayer / tournament / social network
* Multi-camera
* Deteksi pada gambar statis dari galeri

### 4.6 User Journey

```
Open App
→ Camera permission
→ Camera preview
→ Start detection
→ Live detection result
→ Background / leave app
→ Return
→ Exit
```

Jelaskan setiap tahap, termasuk apa yang terjadi jika permission ditolak.

### 4.7 Core User Flow

```
User opens app
→ App memeriksa permission status
→ If notDetermined: request permission
→ If denied: tampilkan permission state + action ke Settings
→ If authorized: configure AVCaptureSession
→ Camera preview tampil
→ AVCaptureVideoDataOutput menghasilkan frame
→ FrameProcessor memutuskan: proses atau buang
→ CoreMLModelService menjalankan inference
→ Parse VNRecognizedObjectObservation → [DetectionResult]
→ DetectionRenderer mengonversi normalized → koordinat layar
→ DetectionOverlayView menggambar bounding box
→ Loop berlanjut pada frame berikutnya
```

Untuk setiap tahap, identifikasi:

* Happy path
* Permission state (notDetermined / denied / restricted)
* No camera available
* Empty state (tidak ada bola terdeteksi)
* Error state
* Backgrounded state

### 4.8 Functional Requirements

Buat requirement untuk:

**Camera**

* Camera permission request
* Camera permission denied handling
* Session configuration
* Camera preview
* Start / stop session
* Rotation handling

**Frame Processing**

* Frame intake
* Frame discard policy
* Inference throttling
* Inference frequency configuration

**Object Detection**

* Model loading
* Model load failure
* Inference
* Result parsing
* Coordinate contract enforcement
* Detection publishing

**Overlay**

* Bounding box rendering
* Label rendering
* Confidence rendering
* Zero-detection state
* Overlay alignment dengan preview

Setiap requirement wajib memiliki:

* ID (`FR-001`, `FR-002`, …)
* Requirement
* Description
* Priority (Must / Should / Could)
* Acceptance Criteria

Format:

```
FR-001
Requirement: ...
Description: ...
Priority: Must

Acceptance Criteria:
- ...
- ...
- ...
```

### 4.9 Technical Architecture

Jelaskan pipeline secara bertahap:

```
AVCaptureSession
→ AVCaptureVideoDataOutput (alwaysDiscardsLateVideoFrames)
→ FrameProcessor (throttle gate, tidak membuat queue)
→ ObjectDetecting (protocol — titik tukar model)
→ CoreMLModelService (VNCoreMLModel, implementasi MVP)
→ [DetectionResult] normalized bottom-left
→ DetectionResults (ObservableObject)
→ DetectionOverlayView
→ DetectionRenderer (normalized → layar)
```

Sertakan tabel tanggung jawab:

| Tipe | Tanggung jawab | Tidak boleh |
| ---- | -------------- | ---------- |
| `CameraManager` | Session, permission, rotation, delegate, publish hasil | Tidak boleh tahu model apa yang dipakai |
| `FrameProcessor` | Throttle gate, input CVPixelBuffer | Tidak boleh membuat queue |
| `ObjectDetecting` | Kontrak deteksi | Tidak boleh tahu soal kamera |
| `CoreMLModelService` | Load model, jalankan inference, parse output | Tidak boleh mengakses UI |
| `DetectionRenderer` | Konversi koordinat ke layar | Tidak boleh meng-import SwiftUI |
| `DetectionOverlayView` | Menggambar hasil | Tidak boleh menghitung koordinat sendiri |

Tekankan D-02: mengganti model harus cukup mengubah titik injeksi di `ContentView`.

### 4.10 Core ML Integration

Jelaskan secara teknis:

```
CMSampleBuffer
→ CVPixelBuffer
→ VNImageRequestHandler(orientation: .up)
→ VNCoreMLRequest(VNCoreMLModel)
→ [VNRecognizedObjectObservation]
→ [DetectionResult]
```

Karena `CameraManager` sudah merotasi buffer, handler memakai `orientation: .up` dan **tidak** ada lagi koreksi orientasi di hilir.

Jelaskan juga:

* Bahwa confidence threshold 0.25 dan IoU 0.45 sudah baked-in di model, sehingga Vision tidak perlu memfilter ulang
* Apa yang harus diubah kalau model diganti ke keluarga YOLO lain (output YOLO biasanya top-left origin dan bentuk center-x/center-y, dan harus dikonversi ke kontrak D-03)
* Bahwa `imageCropAndScaleOption` sebaiknya `.scaleFit` agar seluruh frame terlihat dan koordinat tidak perlu kompensasi crop

### 4.11 Kontrak Koordinat

Spesifikasikan dengan tegas:

* `boundingBox` = normalized 0–1
* Origin = **bottom-left**
* Relatif terhadap frame portrait yang sudah upright
* `DetectionRenderer` melakukan pembalikan sumbu Y saat memetakan ke koordinat SwiftUI
* Model pengganti wajib mengonversikan format outputnya sendiri ke kontrak ini

Buat acceptance criteria yang membuktikan overlay sejajar dengan isi preview, termasuk pada kondisi preview tidak ter-crop.

### 4.12 Performance & Backpressure

Buat requirement untuk:

* Inference FPS yang dapat dikonfigurasi, terpisah dari capture FPS
* Frame discard pada level kamera
* Larangan queue frame tanpa batas
* Waktu load model
* Frame time / latency inference
* Responsive UI saat inference berjalan
* Memori
* Beban baterai dan thermal throttling
* Perilaku saat app di-background saat inference sedang berjalan

**Semua angka tulis sebagai target yang perlu divalidasi (`Baseline: TBD`), bukan angka pasti.** Jangan mengarang FPS, latency, atau megabytes.

### 4.13 Model Validation Tanpa Kamera

Buat requirement untuk memvalidasi model **tanpa kamera**:

* Menjalankan `CoreMLModelService.detect(in:)` pada `CVPixelBuffer` yang dibuat dari still image
* Tidak butuh device fisik, tidak butuh permission, bisa jalan di Simulator
* Menghasilkan output: label, confidence, bounding box
* Failure state: model gagal load, model load tapi menghasilkan 0 observation
* Output failure harus bisa dibedakan dari "tidak ada bola di frame"

Tegaskan alasannya: **jika model tidak menghasilkan observation, seluruh requirement real-time tidak dapat diimplementasikan dengan benar.** Validasi model adalah prasyarat, bukan opsi.

### 4.14 Error Handling

Identifikasi minimal:

* Camera permission ditolak
* Camera permission dibatasi (restricted)
* Tidak ada kamera tersedia
* Gagal konfigurasi session
* Model gagal load
* Inference failure / error saat menjalankan request
* Tidak ada object terdeteksi
* App di-background saat inference berjalan
* Preview layer gagal terpasang

Untuk setiap error, jelaskan:

* Trigger
* User-facing behavior — **dalam Bahasa Indonesia**
* Recovery action

### 4.15 UX Requirements

* Loading state (model sedang dimuat)
* Detection state (live)
* Empty state (preview tampil, tidak ada bounding box)
* Error state
* Permission state
* Permission denied state

Pastikan pengguna selalu tahu aplikasi sedang dalam keadaan apa. Semua user-facing string dalam **Bahasa Indonesia**.

### 4.16 Acceptance Criteria

Buat acceptance criteria untuk setiap requirement MVP. Gunakan Given / When / Then.

```
Given camera permission has been granted
When the user opens the camera screen
Then the camera preview is displayed and detection starts automatically
And bounding boxes appear over detected balls within two seconds
```

Sertakan minimal satu acceptance criteria yang secara eksplisit memverifikasi D-02 (model dapat ditukar tanpa mengubah kamera dan UI) dan satu yang memverifikasi D-04 (tidak ada penumpukan frame saat inference lambat).

### 4.17 Edge Cases

* Tidak ada bola dalam frame
* Sangat banyak bola dalam frame
* Bola sebagian tertutup
* Bola keluar frame
* Kamera bergerak cepat
* Pencahayaan rendah
* Refleksi pada bola
* Kamera terlalu dekat
* Kamera terlalu jauh
* Preview ter-crop karena aspect ratio berbeda
* Rotasi perangkat
* App di-background lalu di-resume
* App keluar saat session berjalan
* Device lama yang tidak mendukung komputasi neural yang cepat

### 4.18 Data & Privacy

* Semua video dan frame diproses **on-device**
* Tidak ada data yang dikirim ke server
* Kamera permission
* Apa yang terjadi pada frame setelah diproses (harus di-release, tidak disimpan)
* Tidak ada persistensi hasil detection di MVP

Jika ada yang belum diputuskan, tandai sebagai **Open Question**.

### 4.19 MVP Scope

| Feature | MVP | Future | Reason |
| ------- | --- | ------ | ------ |
| Camera permission | Ya | — | Prasyarat |
| Camera preview | Ya | — | Prasyarat |
| Live inference | Ya | — | Pilar utama |
| Overlay | Ya | — | Pilar utama |
| Validasi model tanpa kamera | Ya | — | Prasyarat implementasi |
| Video upload dari galeri | Tidak | Ya | Pilar MVP berikutnya |
| Persistensi hasil | Tidak | Ya | Belum ada kebutuhan tervalidasi |
| Ganti model keluarga YOLO lain | Tidak | Ya | arsitektur sudah siap, implementasi menyusul |
| Multi-camera | Tidak | Tidak | Tidak ada kebutuhan |

### 4.20 Risks & Technical Constraints

Pisahkan **product risk**, **UX risk**, **ML risk**, dan **engineering risk**.

Minimal address:

* Akurasi model 18 class pada kondisi pencahayaan berbeda
* Inference latency pada device mid-range
* Thermal throttling saat running lama
* Bounding box alignment antara preview dan overlay
* Perilaku rotasi device
* Ketergantungan pada model Core ML yang bersifat binary dan besar
* Kemungkinan model perlu dilatih ulang

### 4.21 Open Questions

Hanya pertanyaan yang benar-benar masih terbuka:

* Apakah perlu confidence threshold tambahan di atas 0.25 yang sudah baked-in?
* Berapa FPS inference yang bisa dicapai di device mid-range, dan apakah itu cukup?
* Apakah 18 class sudah cukup untuk mencakup semua bola yang dipakai pemain?
* Bagaimana membedakan "tidak ada bola" dari "model gagal" di UI?
* Apakah hasil detection perlu disimpan, dan untuk apa?
* Berapa lama session boleh berjalan continuous sebelum thermal throttling jadi masalah?

Jangan membuka kembali keputusan yang sudah final di Bagian 2.

### 4.22 Future Considerations

* Video upload detection (pilar MVP berikutnya)
* Deteksi pada video yang diunggah pengguna
* Highlight detection
* Shot classification
* Ball trajectory
* Shot replay
* Automatic clip generation
* Player statistics
* AI-assisted analysis
* Penggantian ke model YOLO keluarga lain

Jangan memasukkan future consideration ke dalam requirement MVP.

---

## 5. IMPORTANT RULES

1. Jangan mengarang hasil user research.
2. Jangan menganggap semua pemain biliar memiliki kebutuhan yang sama.
3. Bedakan dengan jelas: **Fact**, **Assumption**, **Requirement**, **Open Question**.
4. Jangan menambahkan fitur hanya karena fitur tersebut secara teknis memungkinkan.
5. MVP harus tetap sederhana dan bisa dikerjakan small team.
6. Jangan menjadikan computer vision sebagai tujuan produk; computer vision adalah teknologi yang mendukung produk.
7. Jangan menjadikan aplikasi ini sebagai aplikasi coaching.
8. Jangan menjadikan aplikasi ini sebagai social media.
9. Jangan membuat arsitektur backend/cloud.
10. Gunakan **Bahasa Indonesia** untuk seluruh isi PRD.
11. Istilah teknis seperti Core ML, Vision, AVFoundation, MVVM, bounding box, inference, confidence score, normalized coordinates, pipeline, backpressure boleh tetap dalam Bahasa Inggris.
12. Jika informasi belum diketahui, tulis **TBD / To Validate / Open Question** — jangan membuat angka atau fakta.
13. Fokus pada requirement yang bisa langsung diterjemahkan menjadi pekerjaan engineering dan design.
14. **Jangan mengarang fakta kodebase.** Gunakan hanya fakta yang tertulis di Bagian 1.
15. **Jangan mengarang angka performa.** Tulis `Baseline: TBD` untuk semua metrik.
16. **Keputusan di Bagian 2 sudah final.** Jangan uzulkan alternatif, jangan tulis sebagai opsi, jangan jadikan open question.
17. Setiap acceptance criteria harus bisa diuji — hindari kalimat seperti "berjalan dengan baik" atau "responsif".
18. Prioritaskan requirement yang bisa diverifikasi otomatis maupun manual di device fisik.

## 6. OUTPUT

Hasil akhir harus berupa **Product Requirements Document yang lengkap dan siap dipakai tim development**.

Gunakan:

* Heading yang jelas
* Bullet points
* Tables jika membantu
* Requirement ID
* Acceptance criteria
* User flow
* Kontrak koordinat dan backpressure sebagai bagian eksplisit, bukan sekadar catatan
* Diagram pipeline dalam bentuk teks

Di bagian paling akhir, tambahkan:

### Assumptions

Semua asumsi yang digunakan, beserta alasan mengapa ditandai sebagai asumsi.

### Decisions Needed

Keputusan yang masih harus dibuat oleh product / design / engineering — di luar keputusan yang sudah final di Bagian 2.

### Out of Scope

Hal yang sengaja tidak dibuat pada MVP ini.

### Recommended Next Step

Berikan urutan pekerjaan yang logis setelah PRD selesai, **tetapi jangan langsung menulis kode**. Sertakan urutan validasi model lebih dulu, karena hasilnya menentukan kelayakan seluruh requirement real-time.
