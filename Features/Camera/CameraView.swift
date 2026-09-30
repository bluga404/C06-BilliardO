import AVFoundation
import SwiftUI

/// Komposisi preview kamera + overlay deteksi + seluruh state UX (§4.15).
///
/// Tidak membuat ViewModel sendiri — semua data masuk lewat init.
struct CameraView: View {
    let cameraState: CameraState
    let session: AVCaptureSession
    @ObservedObject var results: DetectionResults

    var body: some View {
        ZStack {
            switch cameraState.permission {
            case .notDetermined:
                ProgressView("Meminta izin kamera...")

            case .denied:
                PermissionDeniedView(
                    message: "BilliardO memerlukan akses kamera. Buka Pengaturan untuk mengizinkan.",
                    showsSettingsButton: true
                )

            case .restricted:
                PermissionDeniedView(
                    message: "Kamera tidak tersedia di perangkat ini.",
                    showsSettingsButton: false
                )

            case .authorized:
                authorizedContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
    }

    // MARK: - Setelah permission diberikan

    @ViewBuilder
    private var authorizedContent: some View {
        if let error = cameraState.error {
            CameraErrorView(message: error.errorDescription ?? "")
        } else if cameraState.isSessionRunning {
            runningContent
        } else {
            ProgressView("Menyalakan kamera...")
                .foregroundStyle(.white)
        }
    }

    private var runningContent: some View {
        ZStack {
            CameraPreview(session: session)

            DetectionOverlayView(
                detections: results.detections,
                videoSize: results.videoSize
            )

            VStack {
                Spacer()
                statusBanner
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Indikator status (FR-020, E-06, E-07)

    @ViewBuilder
    private var statusBanner: some View {
        if results.isDetectingDegraded {
            Label("Deteksi mengalami masalah.", systemImage: "exclamationmark.triangle.fill")
                .statusChip(background: .orange)
        } else if results.detections.isEmpty {
            HStack(spacing: 6) {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                Text("Mendeteksi — tidak ada bola terdeteksi")
            }
            .statusChip(background: .black.opacity(0.75))
        }
    }
}

// MARK: - Sub-view state

/// FR-002 / E-01 / E-02. Preview kamera tidak tampil sama sekali di kondisi ini.
private struct PermissionDeniedView: View {
    let message: String
    let showsSettingsButton: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.slash.fill")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            Text(message)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if showsSettingsButton {
                Button("Buka Pengaturan") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .foregroundStyle(.white)
    }
}

/// E-04. Tanpa detail teknis (§4.15 Aturan UX #4).
private struct CameraErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(message)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .foregroundStyle(.white)
    }
}

// MARK: - Helper

private extension View {
    func statusChip(background: Color) -> some View {
        padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(background, in: Capsule())
        .font(.footnote.weight(.medium))
        .foregroundStyle(.white)
    }
}
