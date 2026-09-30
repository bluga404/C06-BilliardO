import SwiftUI

/// View Pattern: menerima data via init, tidak membuat ViewModel sendiri.
///
/// Menggambar bounding box, label, dan confidence **hanya** dari koordinat yang
/// sudah dihitung `DetectionRenderer` — tidak menghitung koordinat deteksi sendiri (FR-021).
struct DetectionOverlayView: View {
    let detections: [DetectionResult]
    let videoSize: CGSize

    /// Perkiraan lebar teks label, dipakai hanya untuk memilih sisi anchor
    /// agar label tidak keluar batas layar (FR-018 AC).
    private static let estimatedCharWidth: CGFloat = 7
    private static let labelHeight: CGFloat = 18
    private static let labelGap: CGFloat = 3

    var body: some View {
        GeometryReader { geometry in
            let rendered = DetectionRenderer.render(
                detections,
                viewSize: geometry.size,
                videoSize: videoSize
            )

            ZStack(alignment: .topLeading) {
                ForEach(rendered.indices, id: \.self) { index in
                    boxView(for: rendered[index], containerSize: geometry.size)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Satu pasang bounding box + label

    private func boxView(for detection: RenderedDetection, containerSize: CGSize) -> some View {
        let rect = detection.rect
        let estimatedLabelWidth = CGFloat(detection.label.count + 5) * Self.estimatedCharWidth

        // Anchor kiri bila masih muat; jika tidak, anchor kanan agar label
        // tidak terpotong batas layar (FR-018 AC: "jika memungkinkan").
        let anchor: Alignment = rect.minX + estimatedLabelWidth <= containerSize.width
            ? .topLeading
            : .topTrailing

        // Bila ruang di atas box tidak cukup, label jatuh ke dalam box.
        let hasRoomAbove = rect.minY >= Self.labelHeight + Self.labelGap + 2

        return RoundedRectangle(cornerRadius: 4, style: .continuous)
            .stroke(Color.yellow, lineWidth: 2)
            .frame(width: rect.width, height: rect.height)
            .overlay(alignment: anchor) {
                labelView(for: detection)
                    .offset(y: hasRoomAbove
                        ? -(Self.labelHeight + Self.labelGap)
                        : Self.labelGap)
            }
            .offset(x: rect.minX, y: rect.minY)
    }

    /// FR-018 (label) + FR-019 (confidence) dalam satu baris.
    private func labelView(for detection: RenderedDetection) -> some View {
        Text("\(detection.label)  \(String(format: "%.2f", detection.confidence))")
            .font(.caption2.weight(.semibold))
            .monospacedDigit()
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .frame(height: Self.labelHeight)
            .background(Color.black.opacity(0.75), in: Capsule())
            .foregroundStyle(.white)
            .fixedSize()
    }
}
