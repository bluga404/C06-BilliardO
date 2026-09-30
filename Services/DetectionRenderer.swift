import CoreGraphics

/// Satu deteksi yang sudah siap digambar, dalam koordinat piksel layar.
struct RenderedDetection: Equatable, Sendable {
    let label: String
    let confidence: Float
    /// Origin kiri-atas (koordinat SwiftUI), sudah di-clamp ke area video.
    let rect: CGRect
}

/// Mengonversi `DetectionResult` (normalized 0–1, origin bottom-left sesuai
/// kontrak D-03) menjadi koordinat layar (origin kiri-atas, piksel).
///
/// File ini **tidak meng-import SwiftUI** — semua perhitungan koordinat,
/// termasuk pembalikan sumbu Y, ada di sini dan tidak ada di `DetectionOverlayView` (FR-021).
enum DetectionRenderer {

    /// Area tempat video digambar di dalam view, mengikuti aturan aspect-fit
    /// (`AVCaptureVideoPreviewLayer.videoGravity == .resizeAspect`).
    ///
    /// Preview dan overlay harus memakai aturan yang sama agar bounding box
    /// sejajar dengan bola di preview tanpa crop.
    static func videoRect(viewSize: CGSize, videoSize: CGSize) -> CGRect {
        guard viewSize.width > 0, viewSize.height > 0,
              videoSize.width > 0, videoSize.height > 0 else { return .zero }

        let scale = min(viewSize.width / videoSize.width, viewSize.height / videoSize.height)
        let fitted = CGSize(width: videoSize.width * scale, height: videoSize.height * scale)
        return CGRect(
            x: (viewSize.width - fitted.width) / 2,
            y: (viewSize.height - fitted.height) / 2,
            width: fitted.width,
            height: fitted.height
        )
    }

    /// Konversi satu batch deteksi ke koordinat layar.
    ///
    /// Deteksi yang hasilnya jatuh sepenuhnya di luar area video dibuang,
    /// sehingga bounding box tidak pernah tergambar di luar preview (FR-017).
    static func render(
        _ detections: [DetectionResult],
        viewSize: CGSize,
        videoSize: CGSize
    ) -> [RenderedDetection] {
        let content = videoRect(viewSize: viewSize, videoSize: videoSize)
        guard content.width > 0, content.height > 0 else { return [] }

        return detections.compactMap { detection in
            let box = detection.boundingBox

            // Pembalikan sumbu Y: normalized bottom-left → layar top-left.
            let rect = CGRect(
                x: content.minX + box.minX * content.width,
                y: content.minY + (1 - box.maxY) * content.height,
                width: box.width * content.width,
                height: box.height * content.height
            ).intersection(content)

            guard !rect.isNull, !rect.isEmpty, rect.width > 0.5, rect.height > 0.5 else {
                return nil
            }

            return RenderedDetection(
                label: detection.label,
                confidence: detection.confidence,
                rect: rect
            )
        }
    }
}
