import Combine
import SwiftUI

/// Titik komposisi utama (FR-022).
///
/// **Satu-satunya tempat** di seluruh aplikasi yang menyebut nama model konkret.
/// Mengganti model = mengubah `Self.modelName` di sini.
struct ContentView: View {
    // MARK: - Titik injeksi model (ubah di sini saja)

    private static let modelName = "BilliardBallDetector2-10k"

    // MARK: - State

    @StateObject private var results = DetectionResults()
    @StateObject private var cameraState = CameraStateHolder()
    @State private var configuration = CameraConfiguration()
    @State private var cameraManager: CameraManager?
    @State private var modelPhase: ModelPhase = .loading
    @State private var showValidation = false

    private enum ModelPhase: Equatable {
        case loading
        case ready
        case failed
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch modelPhase {
            case .loading:
                ProgressView("Memuat model...")
                    .foregroundStyle(.white)

            case .failed:
                modelErrorView

            case .ready:
                if let cameraManager {
                    cameraContent(manager: cameraManager)
                } else {
                    ProgressView("Menyalakan kamera...")
                        .foregroundStyle(.white)
                }
            }

            validationButton
        }
        .task { await loadModelAndStartCamera() }
        .sheet(isPresented: $showValidation) {
            NavigationStack {
                ModelValidationView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Selesai") { showValidation = false }
                        }
                    }
            }
        }
    }

    // MARK: - Kamera

    private func cameraContent(manager: CameraManager) -> some View {
        CameraView(
            cameraState: cameraState.state,
            session: manager.captureSession,
            results: results
        )
        .onDisappear { manager.stop() }
    }

    // MARK: - State model

    private var modelErrorView: some View {
        // E-05: pesan tanpa detail teknis internal.
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
            Text("Model deteksi tidak dapat dimuat. Coba instal ulang aplikasi.")
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .foregroundStyle(.white)
    }

    private var validationButton: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    showValidation = true
                } label: {
                    Image(systemName: "stethoscope")
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Validasi model")
                .padding(.trailing, 16)
                .padding(.top, 8)
            }
            Spacer()
        }
    }

    // MARK: - Pemuatan model (FR-011, FR-012)

    @MainActor
    private func loadModelAndStartCamera() async {
        guard modelPhase == .loading, cameraManager == nil else { return }

        let detector: any ObjectDetecting
        do {
            // FR-011 AC: loading tidak memblokir main thread.
            detector = try await Task.detached(priority: .userInitiated) {
                try CoreMLModelService(resource: Self.modelName)
            }.value
        } catch {
            print("[ContentView] model gagal dimuat: \(error.localizedDescription)")
            modelPhase = .failed
            return
        }

        startCamera(detector: detector)
        modelPhase = .ready
    }

    @MainActor
    private func startCamera(detector: any ObjectDetecting) {
        let processor = FrameProcessor(
            detector: detector,
            configuration: configuration,
            onResults: { [results] detections in
                results.publish(detections: detections)
            },
            onError: { [results] _ in
                results.publishInferenceFailure()
            }
        )

        let manager = CameraManager(frameProcessor: processor) { [cameraState, results] state in
            cameraState.state = state
            if state.videoSize != .zero {
                results.publish(videoSize: state.videoSize)
            }
        }
        manager.observeApplicationLifecycle()
        manager.start()

        cameraManager = manager
    }
}

// MARK: - Holder state kamera

/// Referensi agar callback `@Sendable` dari `CameraManager` dapat memperbarui
/// state SwiftUI tanpa menyimpan salinan struct `View`.
@MainActor
final class CameraStateHolder: ObservableObject {
    @Published var state = CameraState()
}

#Preview {
    ContentView()
}
