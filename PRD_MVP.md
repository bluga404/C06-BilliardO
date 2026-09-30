# Product Requirements Document — BilliardO MVP

**Pilar:** Real-time Camera Detection  
**Versi:** 0.1 — Draft Awal  
**Tanggal:** 2026-09-29  
**Status:** Draft — Belum Disetujui  
**Bahasa Dokumen:** Indonesia (istilah teknis tetap dalam Bahasa Inggris)

---

## Daftar Isi

1. [Product Overview](#41-product-overview)
2. [Problem Statement](#42-problem-statement)
3. [Target Users](#43-target-users)
4. [Product Goals](#44-product-goals)
5. [Non-Goals](#45-non-goals)
6. [User Journey](#46-user-journey)
7. [Core User Flow](#47-core-user-flow)
8. [Functional Requirements](#48-functional-requirements)
9. [Technical Architecture](#49-technical-architecture)
10. [Core ML Integration](#410-core-ml-integration)
11. [Kontrak Koordinat](#411-kontrak-koordinat)
12. [Performance & Backpressure](#412-performance--backpressure)
13. [Model Validation Tanpa Kamera](#413-model-validation-tanpa-kamera)
14. [Error Handling](#414-error-handling)
15. [UX Requirements](#415-ux-requirements)
16. [Acceptance Criteria](#416-acceptance-criteria)
17. [Edge Cases](#417-edge-cases)
18. [Data & Privacy](#418-data--privacy)
19. [MVP Scope](#419-mvp-scope)
20. [Risks & Technical Constraints](#420-risks--technical-constraints)
21. [Open Questions](#421-open-questions)
22. [Future Considerations](#422-future-considerations)
- [Assumptions](#assumptions)
- [Decisions Needed](#decisions-needed)
- [Out of Scope](#out-of-scope)
- [Recommended Next Steps](#recommended-next-steps)

---

## 4.1 Product Overview

| Item | Detail |
|------|--------|
| **Product name** | BilliardO |
| **Product type** | Aplikasi iOS native |
| **Platform** | iPhone — iOS 26.0 ke atas, Portrait only |
| **Satu kalimat** | BilliardO membantu pemain biliar mengabadikan dan meninjau momen permainan dengan mendeteksi bola secara real-time langsung dari kamera iPhone. |

### Product Vision

BilliardO menjadi alat bantu rekam-tinjauan bagi pemain biliar yang ingin mendokumentasikan permainan mereka secara mudah, tanpa perangkat eksternal, dan tanpa koneksi internet.

### MVP Scope

PRD ini mencakup **satu pilar MVP saja**: **Real-time Camera Detection** — kemampuan aplikasi mendeteksi bola biliar dari kamera secara real-time dan menampilkan hasilnya sebagai bounding box di layar.

Pilar kedua (deteksi pada video yang diunggah dari galeri) dan pilar ketiga (penyimpanan hasil detection) berada di **luar cakupan PRD ini**.

---

## 4.2 Problem Statement

### Situasi saat ini

Pemain biliar yang ingin meninjau ulang momen permainan mereka saat ini bergantung pada rekaman video biasa dari kamera bawaan iPhone. Video tersebut merekam keseluruhan meja tanpa penanda visual yang memberi konteks tentang posisi bola.

### Masalah pengguna

Meninjau ulang rekaman video biasa membutuhkan waktu dan fokus ekstra. Tidak ada cara mudah untuk melihat posisi seluruh bola secara sekilas dalam satu frame tanpa menonton ulang rekaman satu per satu.

### Pain points

- Tidak ada penanda otomatis atas posisi bola dalam rekaman.
- Pemain harus mengandalkan ingatan atau menghentikan video secara manual untuk memahami posisi bola.
- Tidak ada solusi ringan berbasis iPhone yang bekerja tanpa perangkat eksternal.

### Mengapa ini penting

Sebagian pemain biliar ingin memahami dan memperbaiki permainan mereka. Kemampuan melihat posisi bola secara terstruktur adalah langkah awal yang memungkinkan tinjauan tersebut.

### Workaround saat ini

**Assumption / To Validate** — Belum ada data kualitatif tentang workaround yang digunakan pemain. Kemungkinan mencakup: menonton ulang video secara manual, menggunakan screenshot, atau tidak melakukan tinjauan sama sekali.

---

## 4.3 Target Users

### Pengguna Primer

**Assumption / To Validate** — Pemain biliar hobi hingga semi-profesional yang menggunakan iPhone dan tertarik mendokumentasikan permainan mereka. Tidak ada data demografis tervalidasi saat ini.

**Konteks penggunaan:** Dalam ruang biliar saat sesi bermain aktif. Cahaya ruangan bisa bervariasi (lampu meja khusus, pencahayaan ambient).

**Motivasi:** Ingin meninjau kualitas permainan dan posisi bola tanpa peralatan tambahan.

**Kendala:** Tidak boleh ada setup rumit; aplikasi harus langsung bisa dipakai saat sesi.

### Pengguna Sekunder

**Assumption / To Validate** — Pelatih atau rekan bermain yang ingin mengamati permainan dari sudut pandang kamera. Kebutuhan spesifik belum tervalidasi.

### Catatan

Tidak semua pemain biliar memiliki kebutuhan yang sama. PRD ini tidak mengasumsikan kebutuhan di luar yang diuraikan di atas. Data validasi pengguna harus dikumpulkan setelah MVP.

---

## 4.4 Product Goals

### User Goals

- Pengguna dapat membuka kamera dan langsung melihat bola biliar terdeteksi secara real-time tanpa konfigurasi manual.
- Pengguna dapat melihat bounding box yang sejajar dengan posisi bola di layar.
- Pengguna mendapat umpan balik visual yang jelas ketika tidak ada bola terdeteksi.

### Product Goals

- MVP bisa dikerjakan oleh tim kecil dalam satu iterasi.
- Pipeline deteksi dapat dipahami dan di-maintain tanpa memerlukan pengetahuan khusus tentang internal Core ML.
- Arsitektur memungkinkan penggantian model tanpa mengubah lapisan kamera dan UI.

### Technical Goals

Setiap technical goal di bawah mencerminkan keputusan yang sudah final (D-01 s.d. D-08):

| ID | Technical Goal |
|----|----------------|
| TG-01 | Inference menggunakan `VNCoreMLModel` + `VNCoreMLRequest` (D-01). |
| TG-02 | Model dapat ditukar hanya dengan mengubah satu titik injeksi di `ContentView`, tanpa menyentuh kamera maupun UI (D-02). |
| TG-03 | `DetectionResult.boundingBox` selalu dalam format normalized 0–1, origin bottom-left, portrait upright (D-03). |
| TG-04 | Tidak ada antrean frame tanpa batas; `alwaysDiscardsLateVideoFrames = true`; inference di serial queue (D-04). |
| TG-05 | `inferenceFramesPerSecond` dapat dikonfigurasi, terpisah dari frame rate kamera (D-05). |
| TG-06 | Rotasi buffer ditangani di `CameraManager` dengan `videoRotationAngle = 90` (D-06). |
| TG-07 | Seluruh inference berjalan on-device, tanpa backend dan tanpa cloud (D-07). |
| TG-08 | `CoreMLModelService.detect(in:)` dapat divalidasi di Simulator menggunakan still image tanpa kamera (D-08). |

---

## 4.5 Non-Goals

Fitur berikut secara eksplisit **tidak termasuk** dalam MVP ini:

| Fitur | Alasan |
|-------|--------|
| Video upload dari galeri / PhotosPicker | Pilar MVP berikutnya |
| Penyimpanan atau persistensi hasil detection | Belum ada kebutuhan tervalidasi |
| Automatic highlight generation | Di luar pilar ini |
| Ball trajectory prediction | Di luar pilar ini |
| Shot classification | Di luar pilar ini |
| AI coaching | Di luar pilar ini |
| Score keeping | Di luar pilar ini |
| Replay generation | Di luar pilar ini |
| Cloud video storage | Tidak relevan; semua on-device |
| Multiplayer / tournament / social network | Di luar scope produk |
| Multi-camera | Tidak ada kebutuhan |
| Deteksi pada gambar statis dari galeri | Di luar pilar ini |

---

## 4.6 User Journey

```
Open App
  → [Pemeriksaan permission kamera]
  → [Jika notDetermined] → Request permission
  → [Jika denied]        → Tampilkan layar permission denied + tombol ke Settings
  → [Jika authorized]    → Configure AVCaptureSession
  → Camera preview tampil
  → Start detection (otomatis)
  → Live detection result (bounding box di atas bola)
  → [Background app]     → Session berhenti; bounding box hilang
  → [Return to app]      → Session restart; detection resume
  → Exit
```

### Penjelasan Setiap Tahap

| Tahap | Deskripsi | Kondisi Gagal |
|-------|-----------|---------------|
| **Open App** | Aplikasi diluncurkan, `ContentView` ditampilkan. | — |
| **Camera Permission** | `CameraManager` memeriksa status otorisasi AVCaptureDevice. Jika `notDetermined`, system alert ditampilkan. | Jika pengguna menolak (denied) atau sistem membatasi (restricted). |
| **Camera Preview** | `AVCaptureVideoPreviewLayer` ditampilkan setelah session dikonfigurasi. | Tidak ada kamera tersedia, atau session gagal dikonfigurasi. |
| **Start Detection** | Detection dimulai otomatis begitu session berjalan. Tidak perlu interaksi tambahan dari pengguna. | Model gagal dimuat. |
| **Live Detection Result** | Bounding box ditampilkan di atas setiap bola yang terdeteksi, beserta label class dan confidence score. | Tidak ada bola di frame (empty state); inference error. |
| **Background / Leave App** | `AVCaptureSession` dihentikan. Bounding box hilang. Tidak ada inference. | — |
| **Return** | Session di-restart. Detection resume dari awal. | — |
| **Exit** | Session dihentikan, resource dibebaskan. | — |

### Kondisi Permission Ditolak

Jika pengguna menolak izin kamera:
- Preview tidak ditampilkan.
- Bounding box tidak muncul.
- Aplikasi menampilkan layar permission denied dengan pesan dalam Bahasa Indonesia dan tombol yang mengarahkan pengguna ke **Pengaturan** sistem.
- Pengguna tidak bisa menggunakan fitur apa pun sampai permission diberikan.

---

## 4.7 Core User Flow

```
User membuka aplikasi
  → App memeriksa status permission kamera
      → notDetermined: tampilkan system permission dialog
          → Pengguna menolak → tampilkan layar permission denied
          → Pengguna mengizinkan → lanjut ke konfigurasi session
      → denied     → tampilkan layar permission denied + aksi ke Pengaturan
      → restricted → tampilkan pesan "Kamera tidak tersedia di perangkat ini"
      → authorized → lanjut ke konfigurasi session

  → Configure AVCaptureSession
      → Gagal → tampilkan error state

  → Camera preview tampil di layar

  → AVCaptureVideoDataOutput menghasilkan CMSampleBuffer per frame
      → alwaysDiscardsLateVideoFrames = true (frame lambat dibuang di level kamera)

  → FrameProcessor menerima CVPixelBuffer
      → Periksa timestamp vs inferenceFramesPerSecond
          → Terlalu cepat → buang frame, tidak ada inference
          → Cukup → teruskan ke ObjectDetecting

  → CoreMLModelService menjalankan inference
      → VNImageRequestHandler(orientation: .up)
      → VNCoreMLRequest
      → Hasil: [VNRecognizedObjectObservation]
      → Parse → [DetectionResult] (normalized bottom-left)

  → DetectionResults (ObservableObject) diperbarui

  → DetectionOverlayView dirender
      → DetectionRenderer mengonversi normalized → koordinat SwiftUI
      → Bounding box dan label digambar di atas preview

  → Loop berlanjut pada frame berikutnya
```

### State yang Mungkin pada Setiap Titik

| Titik | Happy Path | Kondisi Lain |
|-------|-----------|--------------|
| Permission check | authorized | notDetermined, denied, restricted |
| Session config | Berhasil | Tidak ada kamera, konfigurasi gagal |
| Frame output | CVPixelBuffer tersedia | — |
| FrameProcessor | Frame diteruskan | Frame dibuang (throttle) |
| Inference | [DetectionResult] non-kosong | 0 observation (tidak ada bola), error inference |
| Overlay | Bounding box tampil | Kosong (empty state), overlay tidak sejajar (bug) |
| Background | — | Session berhenti, inference berhenti |

---

## 4.8 Functional Requirements

> **Format:** Setiap requirement memiliki ID, Requirement, Description, Priority, dan Acceptance Criteria.  
> **Priority:** Must = wajib di MVP; Should = sangat direkomendasikan; Could = opsional.

---

### Kamera

---

**FR-001**  
**Requirement:** Camera permission request  
**Description:** Aplikasi meminta izin kamera kepada pengguna saat pertama kali fitur kamera diakses, menggunakan sistem otorisasi AVCaptureDevice.  
**Priority:** Must

**Acceptance Criteria:**
- System permission dialog ditampilkan saat permission status `notDetermined`.
- Dialog tidak ditampilkan ulang jika permission sudah pernah dijawab.
- Permission diproses secara asinkron; UI tidak memblokir main thread.

---

**FR-002**  
**Requirement:** Camera permission denied handling  
**Description:** Jika pengguna menolak izin kamera atau sistem membatasi akses, aplikasi menampilkan layar khusus yang menjelaskan situasi dan menyediakan aksi pemulihan.  
**Priority:** Must

**Acceptance Criteria:**
- Layar permission denied tampil jika status `denied` atau `restricted`.
- Pesan kepada pengguna ditulis dalam Bahasa Indonesia.
- Tombol "Buka Pengaturan" mengarahkan pengguna ke halaman pengaturan aplikasi di Settings iOS.
- Preview kamera tidak tampil sama sekali dalam kondisi ini.

---

**FR-003**  
**Requirement:** Session configuration  
**Description:** `CameraManager` mengonfigurasi `AVCaptureSession` dengan `AVCaptureVideoDataOutput` yang memiliki `alwaysDiscardsLateVideoFrames = true`.  
**Priority:** Must

**Acceptance Criteria:**
- Session berhasil dikonfigurasi menggunakan kamera belakang (rear camera) sebagai default.
- `alwaysDiscardsLateVideoFrames` bernilai `true` sebelum `startRunning()`.
- Konfigurasi session tidak mengunci `activeVideoMinFrameDuration` atau `activeVideoMaxFrameDuration`.
- Jika konfigurasi gagal, error dikomunikasikan ke ViewModel tanpa crash.

---

**FR-004**  
**Requirement:** Camera preview  
**Description:** Preview kamera ditampilkan di layar menggunakan `AVCaptureVideoPreviewLayer` yang dibungkus dalam `UIViewRepresentable`.  
**Priority:** Must

**Acceptance Criteria:**
- Preview tampil setelah session berjalan.
- Preview mengisi area tampilan yang ditentukan oleh design.
- `videoRotationAngle` pada connection preview layer diatur ke `90` di `viewDidAppear` (bukan `viewDidLoad`), karena `AVCaptureVideoPreviewLayer.connection` bernilai `nil` sebelum session terpasang.

---

**FR-005**  
**Requirement:** Start / stop session  
**Description:** `CameraManager` dapat memulai dan menghentikan `AVCaptureSession` sebagai respons terhadap siklus hidup aplikasi.  
**Priority:** Must

**Acceptance Criteria:**
- Session dimulai secara otomatis saat view muncul dan permission tersedia.
- Session dihentikan saat aplikasi di-background.
- Session di-restart saat aplikasi kembali ke foreground.
- Tidak ada crash atau resource leak saat start/stop berulang.

---

**FR-006**  
**Requirement:** Rotation handling  
**Description:** `CameraManager` mengatur `videoRotationAngle = 90` pada connection `AVCaptureVideoDataOutput` sehingga buffer yang sampai ke detektor sudah dalam orientasi portrait upright.  
**Priority:** Must

**Acceptance Criteria:**
- Buffer yang diterima `FrameProcessor` sudah portrait upright tanpa rotasi tambahan.
- Tidak ada kode di bawah lapisan `CameraManager` yang menangani orientasi.
- Rotasi perangkat secara fisik tidak mengubah orientasi buffer yang dikirim ke inference.

---

### Frame Processing

---

**FR-007**  
**Requirement:** Frame intake  
**Description:** `FrameProcessor` menerima `CVPixelBuffer` dari delegate `AVCaptureVideoDataOutput` dan memutuskan apakah frame diteruskan ke inference atau dibuang.  
**Priority:** Must

**Acceptance Criteria:**
- `FrameProcessor` dipanggil dari serial queue yang sama dengan delegate output video.
- Hanya satu frame yang dapat diproses pada satu waktu secara konstruksi (tidak ada queue frame).
- Frame yang dibuang tidak meninggalkan referensi yang mencegah dealokasi.

---

**FR-008**  
**Requirement:** Frame discard policy  
**Description:** Frame dibuang oleh kamera sebelum sampai ke delegate jika inference sedang berjalan, melalui mekanisme `alwaysDiscardsLateVideoFrames = true`.  
**Priority:** Must

**Acceptance Criteria:**
- Frame tidak menumpuk di buffer saat inference berjalan lebih lama dari interval capture.
- Tidak ada array atau queue yang menyimpan frame yang menunggu.
- Memory tidak bertumbuh tak terbatas saat inference lambat.

---

**FR-009**  
**Requirement:** Inference throttling  
**Description:** `FrameProcessor` membandingkan timestamp frame dengan nilai `inferenceFramesPerSecond` dan menolak frame yang terlalu cepat datang.  
**Priority:** Must

**Acceptance Criteria:**
- Frekuensi aktual inference tidak melebihi `inferenceFramesPerSecond`.
- Frame yang ditolak karena throttle tidak dikirim ke `CoreMLModelService`.
- Throttle berfungsi independent dari frame rate kamera.

---

**FR-010**  
**Requirement:** Inference frequency configuration  
**Description:** Nilai `inferenceFramesPerSecond` dapat dikonfigurasi tanpa mengubah kode `CameraManager` atau `FrameProcessor`.  
**Priority:** Should

**Acceptance Criteria:**
- `inferenceFramesPerSecond` adalah properti yang dapat diubah nilainya dari titik konfigurasi.
- Mengubah nilainya di runtime mengubah frekuensi inference tanpa memulai ulang session.
- Nilai `0` atau negatif tidak menyebabkan crash; harus ada guard atau default value.

---

### Object Detection

---

**FR-011**  
**Requirement:** Model loading  
**Description:** `CoreMLModelService` memuat `BilliardBallDetector2-10k.mlmodelc` dari app bundle saat inisialisasi.  
**Priority:** Must

**Acceptance Criteria:**
- Model dimuat dari bundle menggunakan nama resource `BilliardBallDetector2-10k.mlmodelc`.
- Loading dilakukan secara asinkron atau di background thread; tidak memblokir main thread.
- Setelah loading berhasil, status "model siap" dikomunikasikan ke ViewModel.

---

**FR-012**  
**Requirement:** Model load failure  
**Description:** Jika model gagal dimuat (file tidak ditemukan atau korup), kondisi ini ditangani secara eksplisit dan dikomunikasikan sebagai error state.  
**Priority:** Must

**Acceptance Criteria:**
- Kegagalan loading model tidak menyebabkan crash.
- Error dikomunikasikan sebagai state yang berbeda dari "tidak ada bola terdeteksi".
- Pesan error kepada pengguna ditulis dalam Bahasa Indonesia.

---

**FR-013**  
**Requirement:** Inference  
**Description:** `CoreMLModelService` menjalankan `VNCoreMLRequest` menggunakan `VNImageRequestHandler(orientation: .up)` pada setiap `CVPixelBuffer` yang diteruskan oleh `FrameProcessor`.  
**Priority:** Must

**Acceptance Criteria:**
- Setiap inference menggunakan `orientation: .up` karena buffer sudah portrait upright dari `CameraManager`.
- `imageCropAndScaleOption` diatur ke `.scaleFit` agar seluruh frame terlihat dan koordinat tidak memerlukan kompensasi crop.
- Inference berjalan di serial queue; tidak ada parallelisme yang tak terkontrol.

---

**FR-014**  
**Requirement:** Result parsing  
**Description:** Output `[VNRecognizedObjectObservation]` di-parse menjadi `[DetectionResult]` dengan properti `label`, `confidence`, dan `boundingBox`.  
**Priority:** Must

**Acceptance Criteria:**
- Setiap `VNRecognizedObjectObservation` menghasilkan tepat satu `DetectionResult`.
- `label` diambil dari `topLabelObservation.identifier`.
- `confidence` diambil dari `topLabelObservation.confidence`.
- `boundingBox` diambil dari `boundingBox` observation tanpa transformasi tambahan (sudah normalized bottom-left sesuai konvensi Vision).
- Observation dengan confidence di bawah threshold baked-in model (0.25) tidak akan muncul dalam output Vision.

---

**FR-015**  
**Requirement:** Coordinate contract enforcement  
**Description:** `CoreMLModelService` hanya mengembalikan `DetectionResult` dengan `boundingBox` dalam format normalized 0–1, origin bottom-left, relatif terhadap frame portrait upright. Model pengganti wajib mengonversi format outputnya ke kontrak ini sebelum mengembalikan hasil.  
**Priority:** Must

**Acceptance Criteria:**
- Semua nilai `boundingBox.origin.x`, `boundingBox.origin.y`, `boundingBox.size.width`, `boundingBox.size.height` berada dalam rentang 0.0–1.0.
- Tidak ada kode di luar `CoreMLModelService` yang mentransformasi atau mengasumsikan orientasi koordinat.
- Mengganti implementasi `ObjectDetecting` tidak memerlukan perubahan apa pun pada `CameraManager`, `FrameProcessor`, `DetectionRenderer`, atau `DetectionOverlayView`.

---

**FR-016**  
**Requirement:** Detection publishing  
**Description:** Hasil `[DetectionResult]` dipublikasikan ke `DetectionResults` (ObservableObject) sehingga SwiftUI dapat mererender overlay secara reaktif.  
**Priority:** Must

**Acceptance Criteria:**
- Publikasi dilakukan di main thread (karena `@MainActor` pada ViewModel).
- Setiap update inference memperbarui state; SwiftUI merender ulang overlay.
- Jika tidak ada observation, state diperbarui menjadi array kosong (bukan tidak diperbarui).

---

### Overlay

---

**FR-017**  
**Requirement:** Bounding box rendering  
**Description:** `DetectionOverlayView` menggambar bounding box di atas setiap `DetectionResult` menggunakan koordinat yang sudah dikonversi oleh `DetectionRenderer`.  
**Priority:** Must

**Acceptance Criteria:**
- Bounding box tampil di atas area bola yang terdeteksi di preview.
- Bounding box tidak tampil di luar batas preview.
- Bounding box diperbarui setiap frame inference selesai.

---

**FR-018**  
**Requirement:** Label rendering  
**Description:** Setiap bounding box menampilkan label class dari `DetectionResult.label`.  
**Priority:** Must

**Acceptance Criteria:**
- Label tampil di dekat bounding box yang bersangkutan.
- Label tidak terpotong oleh batas layar jika memungkinkan.
- Label dapat dibaca di atas preview kamera (kontras memadai).

---

**FR-019**  
**Requirement:** Confidence rendering  
**Description:** Setiap bounding box menampilkan confidence score dari `DetectionResult.confidence`.  
**Priority:** Should

**Acceptance Criteria:**
- Confidence ditampilkan dalam format persentase atau desimal (contoh: `0.87`).
- Confidence ditampilkan bersama label pada bounding box yang sama.

---

**FR-020**  
**Requirement:** Zero-detection state  
**Description:** Ketika tidak ada bola terdeteksi dalam frame, overlay tidak menampilkan bounding box, dan pengguna mendapat indikasi bahwa detection sedang berjalan (bukan berhenti).  
**Priority:** Must

**Acceptance Criteria:**
- Tidak ada bounding box muncul saat array `[DetectionResult]` kosong.
- Ada indikator visual yang menunjukkan detection sedang aktif (bukan diam tanpa informasi).
- Indikator teks atau ikon ditulis dalam Bahasa Indonesia.

---

**FR-021**  
**Requirement:** Overlay alignment dengan preview  
**Description:** `DetectionRenderer` melakukan pembalikan sumbu Y saat memetakan koordinat normalized (origin bottom-left) ke koordinat SwiftUI (origin top-left), sehingga bounding box sejajar dengan posisi bola di preview.  
**Priority:** Must

**Acceptance Criteria:**
- Bounding box secara visual sejajar dengan bola di preview kamera.
- Pembalikan sumbu Y dilakukan di `DetectionRenderer`, bukan di `DetectionOverlayView`.
- `DetectionRenderer` tidak meng-import SwiftUI.
- Alignment tetap benar ketika preview tidak ter-crop (dengan `.scaleFit`).

---

**FR-022**  
**Requirement:** Model swappability (tukar model tanpa menyentuh kamera dan UI)  
**Description:** Arsitektur wajib menyediakan titik tukar model melalui protocol `ObjectDetecting`. Hanya `ContentView` yang menyebut nama model konkret. Mengganti model = mengubah satu baris di titik injeksi.  
**Priority:** Must

Protocol yang digunakan:

```swift
protocol ObjectDetecting: Sendable {
    func detect(in pixelBuffer: CVPixelBuffer) throws -> [DetectionResult]
}
```

**Acceptance Criteria:**
- Mengganti implementasi `ObjectDetecting` di `ContentView` tidak memerlukan perubahan apa pun pada `CameraManager`, `FrameProcessor`, `DetectionRenderer`, atau `DetectionOverlayView`.
- `CameraManager` dan semua presentation layer tidak menyebut nama class model konkret secara langsung.
- Ada minimal satu acceptance criteria di sesi pengujian yang secara eksplisit mem-verifikasi ini dengan membuat mock `ObjectDetecting`.

---

## 4.9 Technical Architecture

### Pipeline

```
AVCaptureSession
  → AVCaptureVideoDataOutput
      alwaysDiscardsLateVideoFrames = true
  → CameraManager (delegate, serial queue)
      videoRotationAngle = 90 pada connection VideoDataOutput
  → FrameProcessor
      throttle gate berdasarkan inferenceFramesPerSecond
      (tidak membuat queue baru)
  → ObjectDetecting (protocol — titik tukar model)
  → CoreMLModelService
      VNCoreMLModel + VNCoreMLRequest
      orientation: .up
      imageCropAndScaleOption: .scaleFit
  → [DetectionResult]
      normalized 0–1, origin bottom-left, portrait upright
  → DetectionResults (ObservableObject, @MainActor)
  → DetectionOverlayView (SwiftUI)
  → DetectionRenderer
      konversi normalized → koordinat SwiftUI (flip sumbu Y)
```

### Tabel Tanggung Jawab

| Tipe | Tanggung Jawab | Tidak Boleh |
|------|----------------|-------------|
| `CameraManager` | Konfigurasi session, permission, rotasi buffer (90°), setup delegate, meneruskan buffer ke FrameProcessor | Mengetahui model apa yang dipakai; membuat business logic deteksi |
| `FrameProcessor` | Gate throttle berdasarkan timestamp dan `inferenceFramesPerSecond`, meneruskan buffer ke `ObjectDetecting` | Membuat DispatchQueue, OperationQueue, atau array buffer baru |
| `ObjectDetecting` | Mendefinisikan kontrak deteksi: input `CVPixelBuffer`, output `[DetectionResult]` | Mengetahui soal kamera, UI, atau orientasi |
| `CoreMLModelService` | Memuat model, menjalankan inference via Vision, meng-parse `VNRecognizedObjectObservation` | Mengakses UI, @Published properties, atau thread main secara langsung |
| `DetectionRenderer` | Mengonversi koordinat normalized (bottom-left) ke koordinat layar SwiftUI (top-left) | Meng-import SwiftUI; mengetahui soal session atau model |
| `DetectionOverlayView` | Menggambar bounding box, label, confidence menggunakan hasil dari DetectionRenderer | Menghitung koordinat sendiri; menyentuh CVPixelBuffer |
| `DetectionResults` | ObservableObject yang mempublikasikan `[DetectionResult]` ke SwiftUI | Memiliki logika inference |
| `ContentView` | Titik komposisi utama; menyebut nama model konkret; menginjeksi `CoreMLModelService` sebagai `ObjectDetecting` | Mengatur session kamera secara langsung |

### Pola Kode (sesuai Coding Standards)

- `CameraManager`, `FrameProcessor`, `CoreMLModelService` mengikuti **Service Pattern**: `final class`, dependency di-inject via `init`.
- `DetectionResults` mengikuti **ViewModel Pattern**: `@MainActor`, `ObservableObject`, `@Published private(set)`.
- `DetectionOverlayView` mengikuti **View Pattern**: menerima data via init, tidak membuat ViewModel sendiri.
- Error menggunakan tipe error enum yang didefinisikan per domain.
- Semua UI string dalam Bahasa Indonesia.

---

## 4.10 Core ML Integration

### Pipeline Inferensi

```
CMSampleBuffer (dari AVCaptureVideoDataOutput)
  → CVPixelBuffer (diambil via CMSampleBufferGetImageBuffer)
  → VNImageRequestHandler(cvPixelBuffer:, orientation: .up)
      orientation: .up karena rotasi sudah ditangani CameraManager
  → VNCoreMLRequest(model: VNCoreMLModel)
      imageCropAndScaleOption: .scaleFit
  → [VNRecognizedObjectObservation]
  → parse → [DetectionResult]
      label:       topLabel.identifier
      confidence:  topLabel.confidence
      boundingBox: observation.boundingBox (normalized, bottom-left)
```

### Threshold Baked-in

Model `BilliardBallDetector2-10k` sudah memiliki threshold baked-in:
- **Confidence threshold:** 0.25 — Vision tidak akan mengembalikan observation di bawah nilai ini.
- **IoU / NMS threshold:** 0.45 — deduplikasi bounding box sudah dilakukan oleh model.

`CoreMLModelService` **tidak perlu** menerapkan filter confidence tambahan. Semua observation yang dikembalikan Vision sudah valid.

### Daftar Class Model

Model memiliki **31 `classLabels`**, dibaca saat runtime dari `metadata.json` di dalam bundle `.mlmodelc`:

```
13, 2, bag, bag0, bag1, bag2, bag3, bag4, bag5, bag6, bal14,
ball0, ball1, ball10, ball11, ball110, ball12, ball13, ball14, ball15, ball18,
ball2, ball3, ball4, ball5, ball6, ball7, ball8, ball9, flag, rod
```

Catatan penting — dua fakta ini sebelumnya salah di PRD:

1. **Bukan 18 class.** Angka 18 berasal dari ekstraksi `strings` yang default hanya membaca string ≥4 karakter, sehingga label 3-char `bag` dan `rod` tidak terbaca. Sumber yang benar adalah `classLabels` pada `metadata.json`.
2. **Bukan detektor bola saja.** Model juga mengeluarkan `bag`/`bag0`–`bag6` (lubang meja), `flag`, dan `rod`. `13`, `2`, dan `bal14` adalah label noise dari data training, tetapi tetap merupakan class resmi model.

`MLModelDescription.metadata[.creatorDefinedKey]` **tidak** memuat key `classes` untuk model ini, meskipun deskripsi output menjanjikannya — sehingga `metadata.json` dipakai sebagai sumber `classLabels`.

**Keputusan (setelah MV-002):** `DetectionOverlayView` menggambar **semua** `DetectionResult` apa pun class-nya, termasuk deteksi non-bola. Filtering bola dilakukan di iterasi berikutnya jika diperlukan.

### Jika Model Diganti ke Keluarga YOLO Lain

Output YOLO biasanya dalam format yang berbeda:
- Origin **top-left** (bukan bottom-left seperti Vision).
- Format koordinat **center-x / center-y / width / height** (bukan x/y/width/height dari origin).
- Confidence dan NMS harus diproses secara manual.

Model pengganti tersebut **wajib** mengonversi outputnya ke kontrak D-03 sebelum mengembalikan `[DetectionResult]`. Tidak ada kode di luar `CoreMLModelService` yang boleh mengetahui format ini.

### Pilihan `imageCropAndScaleOption`

`.scaleFit` dipilih agar:
- Seluruh frame kamera terlihat (tidak ter-crop).
- Koordinat bounding box langsung valid tanpa kompensasi crop.
- Alignment overlay dan preview konsisten.

---

## 4.11 Kontrak Koordinat

### Definisi

| Properti | Nilai |
|----------|-------|
| **Format** | Normalized `CGRect`, semua nilai dalam rentang 0.0–1.0 |
| **Origin** | Bottom-left (konvensi Vision) |
| **Relatif terhadap** | Frame portrait yang sudah upright |
| **Siapa yang produce** | `CoreMLModelService` (atau implementasi `ObjectDetecting` mana pun) |
| **Siapa yang consume** | `DetectionRenderer` |

### Alur Transformasi

```
[VNRecognizedObjectObservation.boundingBox]
  normalized, origin bottom-left
    ↓
[DetectionResult.boundingBox]
  tidak berubah; kontrak terjaga
    ↓
[DetectionRenderer]
  flip sumbu Y: y_screen = 1.0 - (boundingBox.origin.y + boundingBox.height)
  scale ke ukuran view
    ↓
[DetectionOverlayView]
  koordinat SwiftUI, origin top-left, unit pixel
```

### Aturan Penegakan Kontrak

1. **Hanya `CameraManager` yang menangani rotasi.** Tidak ada kode di bawah lapisan capture yang boleh tahu soal orientasi.
2. **`DetectionRenderer` melakukan satu-satunya flip sumbu Y.** Tidak ada transformasi koordinat di tempat lain.
3. **Model pengganti wajib mengonversi outputnya sendiri** ke format normalized bottom-left sebelum mengembalikan `DetectionResult`.
4. **`DetectionOverlayView` tidak menghitung koordinat sendiri.** Ia hanya menggunakan koordinat yang sudah disediakan `DetectionRenderer`.

### Acceptance Criteria Koordinat

- Bounding box yang tampil di layar secara visual sejajar dengan bola yang tampak di preview kamera.
- Alignment tetap benar di semua ukuran layar iPhone yang didukung (iOS 26+, iPhone).
- Tidak ada kode di luar `DetectionRenderer` yang melakukan transformasi koordinat terhadap `boundingBox`.

---

## 4.12 Performance & Backpressure

> **Semua angka performa ditulis sebagai target yang perlu divalidasi (`Baseline: TBD`). Tidak ada angka yang dikarang.**

### Requirement Performa

| ID | Requirement | Target | Metode Validasi |
|----|-------------|--------|-----------------|
| PERF-01 | Inference FPS dapat dikonfigurasi, terpisah dari capture FPS | `inferenceFramesPerSecond` bisa diubah | Manual, unit test |
| PERF-02 | Frame discard di level kamera (`alwaysDiscardsLateVideoFrames = true`) | Tidak ada frame menumpuk | Profiling Instruments |
| PERF-03 | Tidak ada queue frame tanpa batas | Dilarang `DispatchQueue` buffer, `OperationQueue`, array frame | Code review |
| PERF-04 | Waktu load model | Baseline: TBD | XCTest, Instruments |
| PERF-05 | Latency inference per frame (frame time) | Baseline: TBD | Instruments, XCTest |
| PERF-06 | UI tetap responsif saat inference berjalan | Main thread tidak diblokir | Instruments Thread Checker |
| PERF-07 | Penggunaan memori saat inference berjalan | Baseline: TBD | Instruments Allocations |
| PERF-08 | Beban baterai dan thermal throttling saat session berjalan continuous | Baseline: TBD | Device testing, Instruments Energy |
| PERF-09 | Perilaku saat app di-background saat inference sedang berjalan | Session berhenti; inference berhenti; tidak crash | Manual testing |

### Aturan Backpressure (Wajib)

Aturan berikut adalah **hard requirement**, bukan preferensi:

1. `alwaysDiscardsLateVideoFrames = true` — kamera yang membuang frame, bukan yang menumpuk di antrian.
2. Inference berjalan di **serial queue yang sama** dengan delegate output video — secara konstruksi hanya satu frame yang diproses.
3. `FrameProcessor` menolak frame berdasarkan timestamp terhadap `inferenceFramesPerSecond`.
4. **Dilarang** membuat `DispatchQueue` antrian frame, `OperationQueue`, atau buffer array di mana pun.

---

## 4.13 Model Validation Tanpa Kamera

### Latar Belakang

Karena `ObjectDetecting.detect(in:)` menerima `CVPixelBuffer` dan bukan kamera, model dapat divalidasi tanpa kamera, tanpa permission, dan di Simulator. **Ini adalah prasyarat, bukan opsi.** Jika model tidak menghasilkan observation, seluruh requirement real-time tidak dapat diimplementasikan dengan benar.

### Requirement Validasi Model

**MV-001**  
**Requirement:** Jalankan `CoreMLModelService.detect(in:)` pada `CVPixelBuffer` yang dibuat dari still image.  
**Priority:** Must

**Acceptance Criteria:**
- Still image (foto meja biliar dengan bola) dikonversi menjadi `CVPixelBuffer`.
- `CoreMLModelService.detect(in: pixelBuffer)` dapat dipanggil tanpa session kamera aktif.
- Tidak membutuhkan device fisik; berjalan di Simulator.
- Tidak membutuhkan camera permission.

---

**MV-002**  
**Requirement:** Output validasi mencakup label, confidence, dan bounding box.  
**Priority:** Must

**Acceptance Criteria:**
- Setiap `DetectionResult` dalam output memiliki `label` yang valid (salah satu dari 31 class model — lihat `classLabels` di `metadata.json` hasil kompilasi `.mlmodelc`).
- Setiap `DetectionResult` memiliki `confidence` dalam rentang 0.0–1.0.
- Setiap `DetectionResult` memiliki `boundingBox` yang normalized (nilai 0.0–1.0).

---

**MV-003**  
**Requirement:** Failure state model dibedakan dari "tidak ada bola di frame".  
**Priority:** Must

**Acceptance Criteria:**
- Jika model gagal load, output adalah error (throw atau error state), bukan array kosong.
- Jika model load berhasil tetapi tidak ada bola di gambar, output adalah array kosong `[]`.
- Kedua kondisi ini tidak dapat dikacaukan dalam UI; error state dan empty state memiliki representasi yang berbeda.

---

**MV-004**  
**Requirement:** Hasil validasi model menentukan kelayakan seluruh implementasi real-time.  
**Priority:** Must

**Acceptance Criteria:**
- Validasi model dilakukan **sebelum** implementasi `CameraManager` dan `FrameProcessor`.
- Jika validasi model gagal (0 observation pada gambar yang jelas berisi bola), pengembangan real-time pipeline dihentikan sampai model diperbaiki atau diganti.

---

## 4.14 Error Handling

> User-facing behavior ditulis dalam Bahasa Indonesia.

| # | Error | Trigger | User-Facing Behavior | Recovery Action |
|---|-------|---------|---------------------|-----------------|
| E-01 | Camera permission ditolak | Pengguna menolak system dialog | "BilliardO memerlukan akses kamera. Buka Pengaturan untuk mengizinkan." | Tombol "Buka Pengaturan" → iOS Settings |
| E-02 | Camera permission restricted | Status `restricted` dari AVCaptureDevice | "Kamera tidak tersedia di perangkat ini." | Tidak ada; kondisi ini tidak bisa diubah pengguna |
| E-03 | Tidak ada kamera tersedia | Device tidak memiliki rear camera | "Kamera tidak ditemukan." | Tidak ada |
| E-04 | Gagal konfigurasi session | Exception saat `beginConfiguration` / `commitConfiguration` | "Kamera tidak dapat dimulai. Coba tutup dan buka kembali aplikasi." | Tutup dan buka ulang aplikasi |
| E-05 | Model gagal load | File tidak ditemukan di bundle, atau format korup | "Model deteksi tidak dapat dimuat. Coba instal ulang aplikasi." | Tidak ada recovery otomatis |
| E-06 | Inference failure | `VNImageRequestHandler.perform` melempar error | Tidak ditampilkan ke pengguna saat pertama; jika berulang, tampilkan "Deteksi mengalami masalah." | Lanjut ke frame berikutnya; error dicatat di log |
| E-07 | Tidak ada object terdeteksi | Array result kosong | Tidak ada bounding box; indikator "Tidak ada bola terdeteksi" | Tidak ada; ini adalah empty state normal |
| E-08 | App di-background saat inference berjalan | Notifikasi `applicationDidEnterBackground` | Preview menghilang; detection berhenti | Otomatis resume saat app kembali ke foreground |
| E-09 | Preview layer gagal terpasang | `AVCaptureVideoPreviewLayer.connection` nil saat assignment | Preview tidak muncul; tidak ada crash | Pastikan rotasi diatur di `viewDidAppear` |

---

## 4.15 UX Requirements

> Semua teks yang terlihat oleh pengguna ditulis dalam Bahasa Indonesia.

| State | Deskripsi | Indikator UI |
|-------|-----------|--------------|
| **Loading state** | Model sedang dimuat dari bundle | Indikator loading (spinner atau teks "Memuat model...") |
| **Detection state** | Session berjalan, inference aktif, bola terdeteksi | Bounding box + label + confidence di atas preview |
| **Empty state** | Session berjalan, inference aktif, tidak ada bola di frame | Preview tampil; teks "Tidak ada bola terdeteksi" atau ikon yang relevan |
| **Error state** | Terjadi error (model gagal, session gagal) | Pesan error dalam Bahasa Indonesia; tombol recovery jika tersedia |
| **Permission state** | Belum ada jawaban permission | System dialog ditampilkan (tidak ada UI kustom) |
| **Permission denied state** | Permission ditolak atau restricted | Layar khusus dengan penjelasan dan tombol "Buka Pengaturan" |

### Aturan UX

1. Pengguna selalu tahu dalam keadaan apa aplikasi berada.
2. Tidak ada state diam tanpa penjelasan (loading tanpa indikator, bukan error tanpa pesan).
3. Semua teks user-facing ditulis dalam Bahasa Indonesia.
4. Pesan error tidak mengekspos detail teknis internal ke pengguna.

---

## 4.16 Acceptance Criteria

Format: **Given / When / Then**

---

**AC-01 — Camera detection berjalan otomatis**

```
Given pengguna telah memberikan izin kamera
When pengguna membuka layar kamera
Then preview kamera ditampilkan
And inference dimulai secara otomatis
And bounding box muncul di atas bola yang terdeteksi
```

---

**AC-02 — Permission denied menampilkan layar recovery**

```
Given pengguna belum memberikan izin kamera
When aplikasi pertama kali dibuka
Then system permission dialog ditampilkan

Given pengguna menolak permission
When layar kamera dibuka
Then preview tidak tampil
And pesan "BilliardO memerlukan akses kamera" tampil dalam Bahasa Indonesia
And tombol "Buka Pengaturan" tersedia dan mengarah ke pengaturan aplikasi
```

---

**AC-03 — Bounding box sejajar dengan bola**

```
Given kamera sedang aktif dan minimal satu bola ada dalam frame
When inference selesai dijalankan
Then bounding box tampil tepat di atas area bola di preview
And tidak ada bounding box yang tampil di luar area bola
And alignment tetap benar di berbagai ukuran layar iPhone
```

---

**AC-04 — Empty state ditampilkan saat tidak ada bola**

```
Given inference sedang berjalan
When tidak ada bola dalam frame selama inference
Then tidak ada bounding box yang tampil
And ada indikator visual bahwa detection sedang aktif (bukan diam)
```

---

**AC-05 — Model gagal load menghasilkan error state, bukan empty state**

```
Given model tidak dapat dimuat dari bundle
When aplikasi dibuka
Then aplikasi menampilkan pesan error dalam Bahasa Indonesia
And state ini berbeda secara visual dari empty state "tidak ada bola"
And tidak ada crash
```

---

**AC-06 — Model dapat ditukar tanpa mengubah kamera dan UI (verifikasi D-02)**

```
Given ada implementasi mock yang conform ke ObjectDetecting
When implementasi mock diinjeksi di ContentView sebagai pengganti CoreMLModelService
Then CameraManager tidak perlu diubah
And FrameProcessor tidak perlu diubah
And DetectionOverlayView tidak perlu diubah
And DetectionRenderer tidak perlu diubah
And pipeline tetap menghasilkan bounding box dari output mock
```

---

**AC-07 — Tidak ada penumpukan frame saat inference lambat (verifikasi D-04)**

```
Given inference sedang berjalan dan membutuhkan waktu lebih lama dari interval capture
When frame baru datang dari AVCaptureVideoDataOutput
Then frame baru dibuang di level kamera (alwaysDiscardsLateVideoFrames)
And tidak ada antrian frame yang bertumbuh
And memori tidak bertumbuh secara tidak terbatas selama sesi berjalan
```

---

**AC-08 — Validasi model di Simulator (verifikasi D-08)**

```
Given sebuah still image berisi bola biliar dikonversi menjadi CVPixelBuffer
When CoreMLModelService.detect(in: pixelBuffer) dipanggil di Simulator
Then output adalah [DetectionResult] dengan minimal satu elemen
And setiap elemen memiliki label valid (salah satu dari 31 `classLabels` model — lihat §4.10)
And setiap elemen memiliki boundingBox yang normalized (0.0–1.0)
And tidak diperlukan kamera atau camera permission
```

---

**AC-09 — Background dan resume**

```
Given session kamera dan inference sedang berjalan
When aplikasi di-background
Then session dihentikan
And inference berhenti
And tidak ada crash

When aplikasi kembali ke foreground
Then session di-restart
And inference resume secara otomatis
```

---

## 4.17 Edge Cases

| Edge Case | Perilaku yang Diharapkan |
|-----------|--------------------------|
| Tidak ada bola dalam frame | Empty state ditampilkan; tidak ada bounding box |
| Sangat banyak bola dalam frame | Semua bola yang terdeteksi di atas threshold 0.25 ditampilkan; UI tidak crash meskipun banyak box |
| Bola sebagian tertutup | Bola yang terdeteksi tetap mendapat bounding box; bola yang tidak terdeteksi tidak mendapat bounding box |
| Bola keluar frame | Bounding box tidak muncul untuk bola yang keluar frame |
| Kamera bergerak cepat | Motion blur dapat memengaruhi akurasi; bounding box mungkin tidak stabil — **Assumption / To Validate** |
| Pencahayaan rendah | Akurasi model mungkin menurun — **To Validate** |
| Refleksi pada bola | Dapat menyebabkan false negative atau false positive — **To Validate** |
| Kamera terlalu dekat | Model mungkin kesulitan mengenali bola yang sangat besar di frame — **To Validate** |
| Kamera terlalu jauh | Model mungkin tidak mendeteksi bola yang terlalu kecil — **To Validate** |
| Preview ter-crop karena aspect ratio berbeda | `AVCaptureVideoPreviewLayer.videoGravity = .resizeAspect` menampilkan seluruh frame tanpa crop; `imageCropAndScaleOption: .scaleFit` hanya menjamin **model** melihat seluruh frame. `DetectionRenderer.videoRect` menghitung area yang sama sehingga overlay sejajar |
| Rotasi perangkat | Hanya portrait yang didukung di MVP; rotasi fisik tidak mengubah orientasi buffer yang dikirim ke inference |
| App di-background lalu di-resume | Session di-restart; detection resume; tidak ada crash; tidak ada frame lama yang tertinggal |
| App keluar saat session berjalan | Session dihentikan dengan benar; resource dibebaskan |
| Device lama yang tidak mendukung komputasi neural cepat | Inference mungkin lambat; frame discard policy mencegah penumpukan; FPS efektif inference rendah — **To Validate** |

---

## 4.18 Data & Privacy

| Aspek | Kebijakan |
|-------|-----------|
| **Pemrosesan video** | Semua frame diproses **on-device**. Tidak ada data yang dikirim ke server atau cloud. |
| **Kamera permission** | Wajib; dijelaskan dalam `NSCameraUsageDescription` di build settings. Teks permission: *"BilliardO membutuhkan akses kamera untuk merekam/mengunggah video dari galeri user."* |
| **Nasib frame setelah diproses** | Frame (`CVPixelBuffer`) harus segera dibebaskan setelah inference selesai. Tidak ada frame yang disimpan di memori atau disk. |
| **Persistensi hasil detection** | Tidak ada di MVP. Hasil detection tidak disimpan ke disk, database, atau cloud. |
| **Log dan analytics** | **Open Question** — Apakah crash logging atau analytics perlu ditambahkan? Jika ya, harus dipastikan tidak mencakup data frame atau hasil detection. |

---

## 4.19 MVP Scope

| Fitur | MVP | Masa Depan | Alasan |
|-------|-----|------------|--------|
| Camera permission | Ya | — | Prasyarat |
| Camera preview | Ya | — | Prasyarat |
| Live inference | Ya | — | Pilar utama |
| Bounding box overlay | Ya | — | Pilar utama |
| Validasi model tanpa kamera | Ya | — | Prasyarat implementasi real-time |
| Inference throttling (inferenceFramesPerSecond) | Ya | — | Backpressure requirement |
| Model swappability (ObjectDetecting protocol) | Ya | — | Hard architectural requirement |
| Video upload dari galeri | Tidak | Ya | Pilar MVP berikutnya |
| Persistensi hasil detection | Tidak | Ya | Belum ada kebutuhan tervalidasi |
| Ganti model ke keluarga YOLO lain | Tidak (implementasi) | Ya | Arsitektur sudah siap; implementasi menyusul |
| Multi-camera | Tidak | Tidak | Tidak ada kebutuhan |
| AI coaching | Tidak | Tidak | Di luar visi produk |
| Social network / multiplayer | Tidak | Tidak | Di luar visi produk |

---

## 4.20 Risks & Technical Constraints

### Product Risk

| Risiko | Tingkat | Catatan |
|--------|---------|---------|
| Akurasi model 31 class pada kondisi pencahayaan ruang biliar yang bervariasi | Tinggi | Harus divalidasi di device fisik dalam berbagai kondisi cahaya |
| Pengguna tidak memahami cara memegang kamera untuk hasil optimal | Sedang | UX guidance mungkin diperlukan di iterasi berikutnya |

### UX Risk

| Risiko | Tingkat | Catatan |
|--------|---------|---------|
| Bounding box bergerak-gerak (jitter) saat kamera tidak stabil | Sedang | Tidak ada stabilisasi di MVP; To Validate |
| Pengguna tidak tahu perbedaan empty state dan error state | Sedang | Desain state harus jelas dan berbeda |
| Pesan permission tidak cukup jelas untuk mendorong pengguna mengizinkan | Rendah | Teks `NSCameraUsageDescription` sudah ada |

### ML Risk

| Risiko | Tingkat | Catatan |
|--------|---------|---------|
| Model perlu dilatih ulang jika akurasi tidak cukup | Tinggi | Model adalah binary besar (±32 MB); pelatihan ulang membutuhkan waktu |
| 31 class model mungkin tidak mencakup semua bola yang dipakai pemain | Sedang | Open Question; perlu divalidasi dengan pemain nyata |
| False positive atau false negative pada kondisi pencahayaan ekstrem | Tinggi | To Validate |
| Confidence threshold 0.25 mungkin terlalu rendah atau terlalu tinggi | Sedang | Threshold baked-in; tidak bisa diubah tanpa melatih ulang model |

### Engineering Risk

| Risiko | Tingkat | Catatan |
|--------|---------|---------|
| Inference latency pada device mid-range | Sedang | Baseline: TBD; harus diuji di device nyata |
| Thermal throttling saat session berjalan lama (>15 menit) | Sedang | Baseline: TBD |
| Bounding box alignment antara preview dan overlay tidak tepat | Tinggi | Koordinat flip sumbu Y harus diimplementasikan dengan benar |
| Perilaku rotasi device tidak konsisten | Rendah | MVP hanya portrait; `videoRotationAngle = 90` sudah ditetapkan |
| `Services/` belum terdaftar sebagai synchronized group di Xcode target | Tinggi | Harus ditambahkan lebih dulu sebelum file di Services/ bisa dikompilasi |
| Model binary besar (±32 MB) dalam bundle app | Sedang | Memperbesar ukuran app; tidak bisa di-hotswap tanpa update app |

---

## 4.21 Open Questions

Pertanyaan berikut masih terbuka dan belum memiliki jawaban yang tervalidasi:

| # | Pertanyaan | Owner |
|---|-----------|-------|
| OQ-01 | Apakah confidence threshold tambahan di atas 0.25 yang sudah baked-in diperlukan di level aplikasi? | ML / Product |
| OQ-02 | Berapa FPS inference yang bisa dicapai di device mid-range, dan apakah itu cukup untuk pengalaman yang baik? | Engineering |
| OQ-03 | Apakah 31 class sudah cukup untuk mencakup semua bola yang dipakai pemain di berbagai jenis permainan biliar? | ML / Product |
| OQ-04 | Bagaimana cara membedakan "tidak ada bola dalam frame" dari "model gagal" di UI secara efektif? | Design / Engineering |
| OQ-05 | Berapa lama sesi boleh berjalan secara continuous sebelum thermal throttling menjadi masalah nyata? | Engineering |
| OQ-06 | Apakah crash logging atau analytics perlu ditambahkan, dan jika ya, apakah ada batasan privasi yang harus diperhatikan? | Product |

> Keputusan D-01 sampai D-08 sudah final dan tidak termasuk dalam open questions ini.

---

## 4.22 Future Considerations

Hal-hal berikut **bukan** bagian dari MVP ini dan tidak boleh dimasukkan ke dalam requirement saat ini:

- **Video upload detection** — pilar MVP berikutnya (deteksi pada video yang diunggah dari galeri/PhotosPicker)
- **Deteksi pada video yang diunggah pengguna**
- **Highlight detection** — menandai momen penting secara otomatis
- **Shot classification** — mengidentifikasi jenis pukulan
- **Ball trajectory** — memvisualisasikan lintasan bola
- **Shot replay** — memutar ulang pukulan tertentu
- **Automatic clip generation** — membuat highlight otomatis
- **Player statistics** — statistik permainan pemain
- **AI-assisted analysis** — analisis permainan berbasis AI
- **Penggantian ke model YOLO keluarga lain** — arsitektur sudah siap via `ObjectDetecting`; implementasi menyusul

---

## Assumptions

| # | Asumsi | Alasan Ditandai Sebagai Asumsi |
|---|--------|-------------------------------|
| A-01 | Pengguna primer adalah pemain biliar hobi hingga semi-profesional yang menggunakan iPhone | Tidak ada data user research yang tervalidasi |
| A-02 | Pengguna berada di dalam ruang biliar saat menggunakan aplikasi | Konteks penggunaan belum diverifikasi secara langsung |
| A-03 | Workaround saat ini termasuk menonton ulang video manual atau screenshot | Tidak ada data kualitatif tentang perilaku saat ini |
| A-04 | Motion blur saat kamera bergerak cepat dapat memengaruhi akurasi deteksi | Belum divalidasi di device fisik |
| A-05 | Model dapat mendeteksi bola dengan akurasi yang cukup dalam berbagai kondisi pencahayaan ruang biliar | Belum divalidasi; bergantung pada distribusi data training |
| A-06 | 31 class dalam model sudah mencakup semua bola yang relevan bagi sebagian besar pemain | Belum dikonfirmasi dengan pemain nyata |

---

## Decisions Needed

Keputusan berikut masih harus dibuat oleh product / design / engineering — **di luar** keputusan yang sudah final (D-01 s.d. D-08):

| # | Keputusan | Siapa yang Memutuskan | Batas Waktu |
|---|-----------|----------------------|-------------|
| DN-01 | Desain visual layar permission denied (layout, warna, ikon) | Design | Sebelum implementasi FR-002 |
| DN-02 | Desain visual empty state dan loading state | Design | Sebelum implementasi FR-020 |
| DN-03 | Nilai default `inferenceFramesPerSecond` yang akan digunakan | Engineering / Product | Sebelum implementasi FR-010 |
| DN-04 | Apakah crash logging / analytics akan ditambahkan di MVP | Product | Sebelum build pertama |
| DN-05 | Desain bounding box: warna, ketebalan garis, posisi label | Design | Sebelum implementasi FR-017 |
| DN-06 | Teks lengkap semua UI string dalam Bahasa Indonesia | Product / Design | Sebelum implementasi FR-020, FR-002 |
| DN-07 | Apakah `Services/` perlu segera ditambahkan sebagai synchronized group sebelum implementasi dimulai | Engineering | Segera — risiko tinggi |

---

## Out of Scope

Hal berikut sengaja tidak dibuat di MVP ini:

- Video upload dari galeri (PhotosPicker)
- Penyimpanan atau persistensi hasil detection ke disk maupun cloud
- Backend, API, atau layanan cloud apa pun
- Fitur coaching, analisis, atau statistik
- Social network, multiplayer, atau fitur komunitas
- Deteksi pada gambar statis dari galeri
- Shot classification dan ball trajectory

---

## Recommended Next Steps

Urutan pekerjaan yang direkomendasikan setelah PRD ini selesai — tanpa langsung menulis kode:

1. **Validasi model (prioritas tertinggi)**
   - Buat test sederhana yang memanggil `CoreMLModelService.detect(in:)` dengan still image berisi bola biliar di Simulator.
   - Konfirmasi model menghasilkan observation dengan label, confidence, dan boundingBox yang valid.
   - Jika model tidak menghasilkan observation: hentikan implementasi real-time sampai model diperbaiki. Seluruh requirement pipeline bergantung pada hasil validasi ini.

2. **Tambahkan `Services/` sebagai synchronized group di Xcode target**
   - Saat ini `Services/` belum terdaftar. Harus diselesaikan sebelum file Swift baru di dalamnya bisa dikompilasi.

3. **Design review**
   - Review state-state UX: loading, detection, empty, error, permission denied.
   - Finalisasi semua UI string dalam Bahasa Indonesia.
   - Desain bounding box: warna, ketebalan, posisi label.

4. **Engineering kick-off**
   - Review seluruh PRD ini bersama tim engineering.
   - Finalisasi keputusan di bagian "Decisions Needed" sebelum implementasi dimulai.
   - Tentukan nilai default `inferenceFramesPerSecond` berdasarkan profiling awal.

5. **Implementasi bertahap** (urutan yang disarankan)
   - `DetectionResult` dan `ObjectDetecting` protocol (tidak ada dependency)
   - `CoreMLModelService` (dapat divalidasi di Simulator)
   - `CameraManager` (membutuhkan device fisik)
   - `FrameProcessor` (bergantung pada `ObjectDetecting`)
   - `DetectionRenderer` (bergantung pada kontrak koordinat)
   - `DetectionResults` (ObservableObject)
   - `DetectionOverlayView` (bergantung pada semua komponen di atas)
   - Integrasi di `ContentView`

6. **Pengujian di device fisik**
   - Validasi alignment bounding box dengan bola nyata.
   - Validasi backpressure (tidak ada penumpukan frame).
   - Validasi perilaku background/resume.
   - Validasi thermal throttling pada sesi panjang.

---

*Dokumen ini adalah living document. Perbarui setiap kali ada keputusan baru yang diambil atau open question yang terjawab.*
