import Foundation

/// Konfigurasi pipeline kamera yang boleh diubah dari titik konfigurasi
/// tanpa menyentuh kode `CameraManager` atau `FrameProcessor` (FR-010).
final class CameraConfiguration: @unchecked Sendable {
    /// Default inference 5 FPS — terpisah dari capture FPS.
    static let defaultInferenceFramesPerSecond: Double = 5

    private let lock = NSLock()
    private var _inferenceFramesPerSecond: Double = CameraConfiguration.defaultInferenceFramesPerSecond

    /// Frekuensi inference maksimum.
    ///
    /// Nilai `<= 0` dijaga di setter dan jatuh kembali ke default,
    /// sehingga tidak pernah memicu pembagian nol di `FrameProcessor`.
    var inferenceFramesPerSecond: Double {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _inferenceFramesPerSecond
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _inferenceFramesPerSecond = newValue > 0
                ? newValue
                : CameraConfiguration.defaultInferenceFramesPerSecond
        }
    }

    init(inferenceFramesPerSecond: Double = CameraConfiguration.defaultInferenceFramesPerSecond) {
        self.inferenceFramesPerSecond = inferenceFramesPerSecond
    }
}
