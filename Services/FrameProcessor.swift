import CoreMedia
import CoreVideo
import Foundation

/// Gerbang antara frame kamera dan inference.
///
/// Tanggung jawab (sesuai tabel arsitektur): throttle berdasarkan timestamp
/// terhadap `CameraConfiguration.inferenceFramesPerSecond`, lalu meneruskan
/// buffer ke `ObjectDetecting`.
///
/// **Dilarang** menambahkan `DispatchQueue`, `OperationQueue`, atau array buffer
/// ke sini (PERF-03). Backpressure ditangani oleh kamera melalui
/// `alwaysDiscardsLateVideoFrames` dan oleh serial queue delegate.
final class FrameProcessor: @unchecked Sendable {
    private let detector: any ObjectDetecting
    private let configuration: CameraConfiguration
    private let onResults: @MainActor @Sendable ([DetectionResult]) -> Void
    private let onError: @MainActor @Sendable (Error) -> Void

    /// Timestamp frame terakhir yang lolos throttle.
    ///
    /// Hanya diakses dari serial queue delegate video (satu thread), dan
    /// tetap dikunci agar aman bila dipanggil dari tempat lain.
    private let lock = NSLock()
    private var lastProcessedTimestamp: TimeInterval?

    init(
        detector: any ObjectDetecting,
        configuration: CameraConfiguration,
        onResults: @escaping @MainActor @Sendable ([DetectionResult]) -> Void,
        onError: @escaping @MainActor @Sendable (Error) -> Void
    ) {
        self.detector = detector
        self.configuration = configuration
        self.onResults = onResults
        self.onError = onError
    }

    /// Dipanggil dari serial queue delegate `AVCaptureVideoDataOutput`.
    ///
    /// Frame yang tidak lolos throttle keluar tanpa memegang referensi apa pun,
    /// sehingga buffer dapat langsung dilepas (FR-007).
    func process(sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let timestamp = CMTimeGetSeconds(sampleBuffer.presentationTimeStamp)
        guard timestamp.isFinite else { return }

        if !shouldProcess(timestamp: timestamp) { return }

        do {
            let results = try detector.detect(in: pixelBuffer)
            publish { [onResults] in onResults(results) }
        } catch {
            publish { [onError] in onError(error) }
        }
    }

    /// `true` bila frame ini berada cukup jauh dari frame terakhir yang diproses.
    ///
    /// Nilai `inferenceFramesPerSecond` dibaca di setiap pemanggilan, sehingga
    /// mengubahnya di runtime langsung berlaku tanpa restart session (FR-010).
    private func shouldProcess(timestamp: TimeInterval) -> Bool {
        let interval = 1.0 / configuration.inferenceFramesPerSecond

        lock.lock()
        defer { lock.unlock() }

        if let last = lastProcessedTimestamp, timestamp - last < interval {
            return false
        }
        lastProcessedTimestamp = timestamp
        return true
    }

    /// Publikasi hasil ke main thread (FR-016).
    ///
    /// Inference berjalan di serial queue kamera; `DetectionResults` berada di
    /// `@MainActor`, jadi pemindaian thread dilakukan di titik tunggal ini.
    private func publish(_ work: @escaping @MainActor @Sendable () -> Void) {
        Task { @MainActor in work() }
    }
}
