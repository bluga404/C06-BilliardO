import AVFoundation
import SwiftUI
import UIKit

/// FR-004: `AVCaptureVideoPreviewLayer` dibungkus `UIViewRepresentable`.
///
/// `videoGravity` diatur ke `.resizeAspect` agar preview menampilkan **seluruh**
/// frame tanpa crop — prasyarat agar bounding box dari `DetectionRenderer`
/// sejajar dengan bola di preview (FR-017, FR-021).
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewContainerView {
        let view = PreviewContainerView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspect
        applyRotation(to: view.previewLayer)
        return view
    }

    func updateUIView(_ view: PreviewContainerView, context: Context) {
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspect
        // FR-004 AC: rotasi diatur setelah session terpasang, bukan saat inisialisasi
        // awal, karena `connection` bernilai `nil` sebelum layer punya session.
        // `updateUIView` berjalan setelah `makeUIView`, setara `viewDidAppear`.
        applyRotation(to: view.previewLayer)
    }

    private func applyRotation(to layer: AVCaptureVideoPreviewLayer) {
        guard let connection = layer.connection,
              connection.isVideoRotationAngleSupported(90) else { return }
        connection.videoRotationAngle = 90
    }
}

/// UIView yang me-layout `AVCaptureVideoPreviewLayer` mengikuti bounds-nya.
final class PreviewContainerView: UIView {
    let previewLayer = AVCaptureVideoPreviewLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        previewLayer.videoGravity = .resizeAspect
        layer.addSublayer(previewLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}
