import CoreGraphics
import CoreVideo
import SwiftUI
import UIKit

// MARK: - Model Validation (tanpa kamera)
/// Validasi model sesuai MV-001 s.d. MV-004.
///
/// Berjalan di Simulator, tanpa kamera dan tanpa camera permission, karena
/// `ObjectDetecting.detect(in:)` menerima `CVPixelBuffer` — bukan kamera.
struct ModelValidationView: View {
    @State private var phase: Phase = .idle
    @State private var modelLabels: Set<String> = []
    @State private var extraLog: [String] = []

    enum Phase: Equatable {
        case idle
        case imageMissing
        case modelFailed(String)
        case running
        case noDetections
        case detected([DetectionResult])
    }

    var body: some View {
        List {
            Section("Validasi Model") {
                Button("Jalankan Validasi") {
                    Task { @MainActor in await runValidation() }
                }
                .disabled(isRunning)

                Text("Memvalidasi model tanpa kamera (MV-001). Jalankan di Simulator.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !modelLabels.isEmpty {
                Section("Class model (\(modelLabels.count))") {
                    Text(modelLabels.sorted().joined(separator: ", "))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            } else if phase != .idle {
                Section("Class model") {
                    Text("metadata.json tidak diparse — validasi class dilewati (bukan lulus).")
                        .foregroundStyle(.orange)
                }
            }

            switch phase {
            case .idle:
                EmptyView()

            case .imageMissing:
                Section {
                    Text("Gambar validasi 'smoketest' tidak ditemukan di Assets.xcassets. Tambahkan foto meja biliar yang berisi bola dengan nama 'smoketest' lalu jalankan ulang.")
                        .foregroundStyle(.orange)
                }

            case .modelFailed(let message):
                Section("Error State (MV-003)") {
                    Text(message)
                        .foregroundStyle(.red)
                }

            case .running:
                Section("Loading") {
                    ProgressView("Menjalankan inference...")
                }

            case .noDetections:
                Section("Empty State (MV-003)") {
                    Text("Model berhasil dimuat dan inference berjalan, tetapi 0 observation.")
                        .foregroundStyle(.orange)
                    Text("Ini bukan error model. Periksa apakah gambar memuat bola dengan jelas.")
                        .font(.footnote)
                }

            case .detected(let results):
                Section("Hasil (MV-002)") {
                    Text("\(results.count) bola terdeteksi")
                        .font(.headline)
                    ForEach(results.indices, id: \.self) { index in
                        detectionRow(results[index])
                    }
                }
            }

            if !extraLog.isEmpty {
                Section("Log") {
                    ForEach(extraLog.indices, id: \.self) { index in
                        Text(extraLog[index])
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Validasi Model")
        .task { await runValidation() }
    }

    private var isRunning: Bool {
        if case .running = phase { return true }
        return false
    }

    // MARK: - Hasil per deteksi
    private func detectionRow(_ result: DetectionResult) -> some View {
        let box = result.boundingBox
        let isKnownLabel: Bool? = modelLabels.isEmpty ? nil : modelLabels.contains(result.label)
        let isConfidenceInRange = (0.0...1.0).contains(result.confidence)
        let isBoxNormalized = (0.0...1.0).contains(box.origin.x)
            && (0.0...1.0).contains(box.origin.y)
            && (0.0...1.0).contains(box.size.width)
            && (0.0...1.0).contains(box.size.height)

        return VStack(alignment: .leading, spacing: 4) {
            Text("\(result.label)  \(Int(result.confidence * 100))%")
                .font(.body.monospaced())

            Text("bbox x:\(box.origin.x, specifier: "%.3f") y:\(box.origin.y, specifier: "%.3f") w:\(box.size.width, specifier: "%.3f") h:\(box.size.height, specifier: "%.3f")")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                statusText(isKnownLabel, label: "class model")
                statusText(isConfidenceInRange, label: "confidence 0–1")
                statusText(isBoxNormalized, label: "bbox normalized 0–1")
            }
            .font(.caption2)
        }
        .padding(.vertical, 2)
    }

    /// Tiga state: `nil` = daftar class tidak tersedia (tidak dihitung lulus),
    /// `true` = lulus, `false` = gagal.
    private func statusText(_ passed: Bool?, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon(for: passed))
            Text(label)
        }
        .foregroundStyle(color(for: passed))
    }

    private func icon(for passed: Bool?) -> String {
        switch passed {
        case .some(true): "checkmark.circle.fill"
        case .some(false): "xmark.circle.fill"
        case .none: "questionmark.circle.fill"
        }
    }

    private func color(for passed: Bool?) -> Color {
        switch passed {
        case .some(true): .green
        case .some(false): .red
        case .none: .gray
        }
    }

    // MARK: - Validasi
    private func runValidation() async {
        phase = .running
        modelLabels = []
        extraLog.removeAll()

        guard let image = UIImage(named: "smoketest")?.cgImage else {
            phase = .imageMissing
            appendLog("gambar 'smoketest' tidak ditemukan")
            return
        }
        appendLog("gambar \(image.width)x\(image.height) dimuat")

        guard let pixelBuffer = makePixelBuffer(from: image) else {
            phase = .modelFailed("Gambar tidak dapat dikonversi ke CVPixelBuffer.")
            return
        }

        let service: CoreMLModelService
        do {
            service = try CoreMLModelService(resource: "BilliardBallDetector2-10k")
        } catch {
            let message = error.localizedDescription
            phase = .modelFailed(message)
            appendLog("model gagal load: \(message)")
            return
        }

        modelLabels = Set(service.availableLabels)
        appendLog("model dimuat, \(service.availableLabels.count) class")

        do {
            let results = try service.detect(in: pixelBuffer)
            if results.isEmpty {
                phase = .noDetections
                appendLog("inference OK, 0 observation")
            } else {
                phase = .detected(results)
                appendLog("inference OK, \(results.count) observation")
            }
        } catch {
            let message = error.localizedDescription
            phase = .modelFailed(message)
            appendLog("inference gagal: \(message)")
        }
    }

    private func appendLog(_ line: String) {
        extraLog.append(line)
        print("[ModelValidation] \(line)")
    }

    // MARK: - CGImage → CVPixelBuffer
    private func makePixelBuffer(from image: CGImage) -> CVPixelBuffer? {
        let width = image.width
        let height = image.height

        let attributes: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
        ]

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
    }
}

#Preview {
    NavigationStack {
        ModelValidationView()
    }
}
