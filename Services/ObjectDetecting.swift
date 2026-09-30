import CoreVideo

/// Kontrak deteksi objek (D-02).
///
/// Satu-satunya tempat nama model konkret boleh muncul adalah titik injeksi di `ContentView`.
/// Mengganti model cukup mengganti implementasi protocol ini —
/// `CameraManager`, `FrameProcessor`, dan seluruh presentation layer tidak berubah.
protocol ObjectDetecting: Sendable {
    /// - Parameter pixelBuffer: frame yang sudah portrait-upright, karena rotasi
    ///   sudah ditangani `CameraManager` (D-06). Lapisan di bawah itu tidak boleh
    ///   tahu soal orientasi.
    /// - Returns: bounding box normalized 0–1, origin bottom-left (kontrak D-03).
    ///   Array kosong berarti tidak ada bola terdeteksi — bukan error.
    func detect(in pixelBuffer: CVPixelBuffer) throws -> [DetectionResult]
}
