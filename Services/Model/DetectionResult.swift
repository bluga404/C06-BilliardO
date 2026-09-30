import CoreGraphics

/// Satu hasil deteksi bola.
///
/// `boundingBox` mengikuti kontrak koordinat D-03:
/// normalized 0–1, origin bottom-left, relatif terhadap frame portrait yang sudah upright.
/// Setiap implementasi `ObjectDetecting` wajib mengonversi outputnya ke format ini.
struct DetectionResult: Equatable {
    let label: String
    let confidence: Float
    let boundingBox: CGRect
}
