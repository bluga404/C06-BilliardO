Bertindak sebagai **Senior Product Manager sekaligus iOS Technical Product Manager** yang berpengalaman dalam membangun MVP aplikasi berbasis computer vision.

Saya sedang membangun sebuah aplikasi **iOS untuk membantu pemain biliar mengabadikan dan meninjau momen permainan mereka**. Aplikasi ini akan menggunakan model **YOLOv2 Object Detection dalam format Core ML Machine Learning Model** untuk mendeteksi bola biliar dari video.

## KONTEKS PRODUK

Platform:

* iOS
* Swift / SwiftUI
* MVVM architecture
* Core ML
* Vision framework jika diperlukan
* AVFoundation untuk kamera/video
* Model: YOLOv2 Object Detection dalam format `.mlmodel` / Core ML
* Target utama: iPhone

Model computer vision yang tersedia dapat melakukan object detection terhadap bola biliar. Model harus dapat digunakan untuk:

1. Mendeteksi bola dari kamera secara real-time.
2. Mendeteksi bola dari video yang diunggah oleh pengguna.

Produk masih berada pada tahap **MVP**, sehingga jangan menambahkan fitur kompleks yang belum diperlukan.

## PRODUCT CONTEXT

Problem space:
Pemain biliar terkadang ingin mengabadikan momen tertentu ketika bermain, baik untuk menyimpan momen, membagikannya, maupun meninjau kembali permainan mereka. Namun, proses dokumentasi dapat memiliki hambatan seperti kebutuhan untuk mengatur kamera, meminta bantuan teman untuk merekam, atau harus meninjau video secara manual.

Aplikasi ini mengeksplorasi bagaimana computer vision dapat digunakan untuk membantu proses dokumentasi dan peninjauan momen bermain biliar.

Core direction:
**Help billiard players capture and review moments from their games.**

Jangan mengasumsikan bahwa semua pemain membutuhkan dokumentasi, dan jangan mengasumsikan bahwa semua pemain membutuhkan analisis permainan. Pisahkan fakta, asumsi, dan keputusan produk.

## MVP

MVP harus berfokus pada kemampuan utama berikut:

### 1. Real-time Ball Detection

Pengguna dapat membuka kamera dan melihat video secara real-time.

Model Core ML mendeteksi bola biliar pada frame kamera dan menampilkan hasil detection secara visual.

Minimal output detection:

* Bounding box
* Class / jenis bola jika tersedia dari model
* Confidence score jika tersedia

### 2. Video Upload Detection

Pengguna dapat memilih video dari Photos / PhotosPicker.

Aplikasi kemudian melakukan object detection pada video tersebut.

Pengguna dapat melihat hasil detection pada video.

### 3. Detection Result

Hasil object detection harus dapat divisualisasikan di atas video/frame.

Pertimbangkan:

* bounding box
* label
* confidence
* jumlah object yang terdeteksi jika relevan

Jangan menambahkan fitur seperti automatic highlight generation, shot classification, trajectory prediction, score tracking, replay generation, atau AI coaching kecuali dijelaskan sebagai **future consideration**, bukan bagian MVP.

## TUJUAN PRD

Buat PRD yang dapat langsung digunakan oleh:

* Product Designer
* iOS Developer
* ML / Computer Vision Developer

PRD harus membantu tim memahami:

1. Apa yang sedang dibangun.
2. Siapa pengguna utamanya.
3. Masalah apa yang ingin diselesaikan.
4. Apa yang termasuk MVP.
5. Bagaimana user flow-nya.
6. Bagaimana aplikasi berinteraksi dengan model Core ML.
7. Bagaimana detection diproses dari kamera dan video.
8. Apa acceptance criteria setiap fitur.
9. Apa batasan teknis MVP.
10. Apa yang sengaja tidak dibuat.

## STRUKTUR PRD

Gunakan struktur berikut.

### 1. Product Overview

Jelaskan:

* Product name
* Product type
* Platform
* One-sentence product description
* Product vision
* MVP scope

### 2. Problem Statement

Jelaskan:

* Current situation
* User problem
* Pain points
* Why the problem matters
* Existing workaround

Jangan langsung menganggap solusi teknis sebagai problem.

### 3. Target Users

Identifikasi:

* Primary user
* Secondary user jika memang relevan
* User context
* User motivation
* User constraints

Jika informasi belum cukup, tandai sebagai **Assumption / To Validate**.

### 4. Product Goals

Pisahkan:

* User goals
* Product goals
* Technical goals

Jangan membuat business metrics yang tidak memiliki dasar.

### 5. Non-Goals

Buat daftar fitur yang secara eksplisit berada di luar MVP.

Contoh:

* Automatic highlight generation
* Ball trajectory prediction
* Automatic shot classification
* AI coaching
* Score keeping
* Tournament management
* Social network
* Cloud video storage
* Multiplayer functionality

Tambahkan hanya jika memang relevan.

### 6. User Journey

Buat user journey dari:

Open App
→ Start Camera / Select Video
→ Process Video
→ Object Detection
→ View Detection Result
→ Finish / Save / Exit

Jelaskan setiap tahap.

### 7. Core User Flows

Buat minimal dua flow:

#### Flow A — Real-time Detection

User opens app
→ Camera permission
→ Camera preview
→ Start detection
→ Capture frames
→ Preprocess frame
→ Core ML inference
→ Parse detection results
→ Draw bounding boxes
→ Display result

#### Flow B — Uploaded Video

User opens app
→ Select video
→ Load video
→ Extract frames
→ Preprocess frame
→ Core ML inference
→ Parse detection results
→ Overlay detection
→ Display processed result

Identifikasi:

* Happy path
* Error state
* Empty state
* Permission state
* Unsupported video state
* Model failure state

### 8. Functional Requirements

Buat requirement yang jelas untuk:

#### Camera

* Camera permission
* Camera preview
* Start/stop detection
* Real-time inference
* Detection overlay

#### Video Upload

* Photos permission / PhotosPicker
* Video selection
* Video validation
* Video processing
* Detection overlay
* Processing state

#### Object Detection

* Model loading
* Image preprocessing
* Inference
* Post-processing
* Confidence threshold
* Bounding box conversion
* Detection rendering

Setiap requirement harus memiliki:

* ID
* Requirement
* Description
* Priority
* Acceptance Criteria

Gunakan format:

FR-001
Requirement:
...

Acceptance Criteria:

* ...
* ...
* ...

### 9. Technical Architecture

Gunakan arsitektur:

MVVM

Jelaskan tanggung jawab:

#### View

Contoh:

* CameraView
* VideoPickerView
* DetectionResultView

#### ViewModel

Contoh:

* CameraViewModel
* VideoDetectionViewModel

#### Model / Services

Contoh:

* CoreMLModelService
* VideoProcessor
* CameraManager
* DetectionProcessor

Jangan membuat class secara berlebihan jika belum diperlukan.

### 10. Core ML Integration

Jelaskan secara teknis bagaimana model digunakan.

Bahas:

Camera Frame
→ Pixel Buffer
→ Vision / Core ML
→ YOLOv2 inference
→ Detection output
→ Post-processing
→ Bounding box
→ SwiftUI overlay

Untuk video:

Video
→ AVAsset / AVAssetReader
→ CMSampleBuffer / CVPixelBuffer
→ Model inference
→ Detection results
→ Overlay

Jelaskan kapan sebaiknya menggunakan:

* Vision framework
* Direct Core ML inference

Jika ada trade-off, jelaskan tanpa langsung menganggap salah satu sebagai pilihan mutlak.

### 11. Performance Requirements

Buat requirement untuk:

* Real-time inference
* FPS
* Frame skipping
* Model loading
* Memory usage
* Video processing
* UI responsiveness
* Battery considerations

Jika angka performa belum diketahui, gunakan **target yang perlu divalidasi**, bukan angka yang dibuat seolah-olah sudah pasti.

### 12. Error Handling

Identifikasi minimal:

* Camera permission denied
* Photos permission denied
* No camera available
* Invalid video
* Unsupported video format
* Video too long
* Model failed to load
* Inference failure
* No objects detected
* Low-confidence detection
* Processing interrupted
* App backgrounded during processing

Untuk setiap error:

* Trigger
* User-facing behavior
* Recovery action

### 13. UX Requirements

Jelaskan:

* Loading state
* Processing state
* Detection state
* Empty state
* Error state
* Permission state

Prioritaskan agar pengguna selalu mengetahui apakah aplikasi:

* sedang merekam
* sedang melakukan detection
* sedang memproses video
* selesai
* mengalami error

### 14. Acceptance Criteria

Buat acceptance criteria untuk setiap MVP feature.

Gunakan format Given / When / Then jika cocok.

Contoh:

Given camera permission has been granted
When the user starts detection
Then the application displays the camera preview and detection results in real time.

### 15. Edge Cases

Identifikasi edge cases seperti:

* Tidak ada bola dalam frame
* Banyak bola dalam frame
* Bola sebagian tertutup
* Bola keluar frame
* Kamera bergerak
* Pencahayaan rendah
* Refleksi pada bola
* Kamera terlalu dekat
* Kamera terlalu jauh
* Video portrait
* Video landscape
* Video dengan frame rate berbeda
* Video beresolusi tinggi

### 16. Data & Privacy

Jelaskan:

* Apakah video diproses locally/on-device
* Apakah video dikirim ke server
* Camera permission
* Photos permission
* Data retention
* Temporary processing data

Jika implementasi belum ditentukan, tandai sebagai **Open Question**.

### 17. MVP Scope

Buat tabel:

| Feature | MVP | Future | Reason |
| ------- | --- | ------ | ------ |

Pastikan MVP tetap kecil dan dapat dibuat oleh small team.

### 18. Risks & Technical Constraints

Identifikasi:

* YOLOv2 model accuracy
* Detection latency
* Device performance
* Thermal throttling
* Memory usage
* Video processing time
* Bounding box accuracy
* Different lighting conditions
* Camera orientation
* Model compatibility

Pisahkan:

* Product risk
* UX risk
* ML risk
* Engineering risk

### 19. Success Metrics

Gunakan metric yang dapat diukur.

Contoh kategori:

* Detection performance
* Processing performance
* Feature completion
* User task completion

Jangan membuat target angka tanpa dasar. Jika baseline belum tersedia, tuliskan **Baseline: TBD**.

### 20. Open Questions

Buat pertanyaan yang masih harus dijawab sebelum development.

Contoh:

* Berapa minimum confidence threshold?
* Apakah detection dilakukan menggunakan Vision atau direct Core ML?
* Berapa FPS yang dianggap cukup real-time?
* Apakah video diproses seluruhnya atau frame tertentu?
* Apakah hasil detection perlu disimpan?
* Apakah pengguna dapat memilih bagian video tertentu?

### 21. Future Considerations

Letakkan fitur yang mungkin dikembangkan setelah MVP, misalnya:

* Automatic highlight detection
* Shot detection
* Ball trajectory
* Shot replay
* Automatic clip generation
* Player statistics
* AI-assisted analysis

Jangan memasukkan fitur future consideration ke MVP requirements.

## IMPORTANT RULES

1. Jangan mengarang hasil user research.
2. Jangan menganggap semua billiard players memiliki kebutuhan yang sama.
3. Bedakan dengan jelas:

   * Fact
   * Assumption
   * Requirement
   * Open Question
4. Jangan menambahkan fitur hanya karena fitur tersebut secara teknis memungkinkan.
5. MVP harus tetap sederhana.
6. Jangan menjadikan computer vision sebagai tujuan produk; computer vision adalah teknologi yang mendukung produk.
7. Jangan mengubah aplikasi menjadi billiard coaching app kecuali requirement tersebut memang diberikan.
8. Jangan mengubah aplikasi menjadi social media.
9. Jangan membuat backend/cloud architecture jika local/on-device processing sudah mencukupi.
10. Jangan mengasumsikan video harus disimpan ke cloud.
11. Gunakan bahasa Indonesia.
12. Istilah teknis seperti Core ML, YOLOv2, Vision, AVFoundation, MVVM, bounding box, inference, dan confidence score boleh tetap menggunakan bahasa Inggris.
13. Jika ada informasi yang belum diketahui, tulis **TBD / To Validate / Open Question**, bukan membuat asumsi.
14. Fokus pada requirement yang dapat langsung diterjemahkan menjadi pekerjaan engineering dan design.

## OUTPUT

Hasil akhir harus berupa **Product Requirements Document yang lengkap dan siap digunakan oleh tim development**.

Gunakan:

* Heading yang jelas
* Bullet points
* Tables jika membantu
* Requirement ID
* Acceptance criteria
* User flow
* Technical architecture
* Open questions

Di bagian paling akhir, tambahkan:

### Assumptions

Semua asumsi yang digunakan.

### Decisions Needed

Keputusan yang masih harus dibuat oleh product/design/engineering.

### Out of Scope

Hal-hal yang sengaja tidak dibuat pada MVP.

### Recommended Next Step

Berikan urutan pekerjaan yang logis setelah PRD selesai, tetapi jangan langsung menulis kode.
