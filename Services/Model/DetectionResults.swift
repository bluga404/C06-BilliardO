import Combine
import CoreGraphics
import Foundation

/// ViewModel pattern: `@MainActor`, `ObservableObject`, `@Published private(set)`.
///
/// Satu-satunya jembatan antara hasil inference dan SwiftUI.
/// Tidak berisi logika inference apa pun.
@MainActor
final class DetectionResults: ObservableObject {
    /// Jumlah kegagalan inference berturut-turut.
    /// E-06: kegagalan pertama tidak ditampilkan; kegagalan berulang ditampilkan.
    static let failureWarningThreshold = 3

    @Published private(set) var detections: [DetectionResult] = []
    @Published private(set) var videoSize: CGSize = .zero
    @Published private(set) var consecutiveInferenceFailures: Int = 0

    var isDetectingDegraded: Bool {
        consecutiveInferenceFailures >= DetectionResults.failureWarningThreshold
    }

    /// Inference berhasil — termasuk ketika hasilnya kosong (empty state, E-07).
    func publish(detections: [DetectionResult]) {
        self.detections = detections
        consecutiveInferenceFailures = 0
    }

    /// Dimensi buffer kamera dalam orientasi portrait upright,
    /// dipakai `DetectionRenderer` untuk menghitung area preview.
    func publish(videoSize: CGSize) {
        guard videoSize != .zero else { return }
        self.videoSize = videoSize
    }

    func publishInferenceFailure() {
        consecutiveInferenceFailures += 1
    }
}
