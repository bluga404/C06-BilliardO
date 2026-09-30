import CoreML
import CoreVideo
import Vision

/// Error domain untuk layanan model.
/// `errorDescription` adalah teks user-facing, ditulis dalam Bahasa Indonesia.
enum ModelServiceError: Error, LocalizedError {
    case resourceNotFound(resource: String)
    case loadFailed(underlying: Error)
    case inferenceFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .resourceNotFound, .loadFailed:
            return "Model deteksi tidak dapat dimuat. Coba instal ulang aplikasi."
        case .inferenceFailed:
            return "Deteksi mengalami masalah."
        }
    }
}

// MARK: - ObjectDetecting via Vision
final class CoreMLModelService: ObjectDetecting, @unchecked Sendable {
    private let visionModel: VNCoreMLModel

    /// Class yang dimiliki model, dibaca dari metadata — bukan daftar yang dikarang.
    /// Dipakai validasi MV-002 untuk memastikan label keluaran berasal dari model.
    let availableLabels: [String]

    /// - Parameter resource: nama file `.mlmodelc` di app bundle, tanpa ekstensi.
    ///   Nama model hanya disebut di titik injeksi — sengaja tidak ada default value.
    init(resource: String) throws {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "mlmodelc") else {
            throw ModelServiceError.resourceNotFound(resource: resource)
        }

        availableLabels = Self.classLabels(inCompiledModel: url)

        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all

        let model: MLModel
        do {
            model = try MLModel(contentsOf: url, configuration: configuration)
        } catch {
            throw ModelServiceError.loadFailed(underlying: error)
        }

        do {
            visionModel = try VNCoreMLModel(for: model)
        } catch {
            throw ModelServiceError.loadFailed(underlying: error)
        }
    }

    /// Daftar class dibaca dari `metadata.json` di dalam `.mlmodelc`.
    ///
    /// `MLModelDescription.metadata[.creatorDefinedKey]` tidak memuat "classes"
    /// pada model Create ML ini, padahal deskripsi output menjanjikan hal itu.
    /// `metadata.json` adalah artefak hasil kompilasi Xcode yang memuat `classLabels`.
    private static func classLabels(inCompiledModel url: URL) -> [String] {
        guard let data = try? Data(contentsOf: url.appendingPathComponent("metadata.json")),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let labels = json.first?["classLabels"] as? [String] else { return [] }
        return labels
    }

    func detect(in pixelBuffer: CVPixelBuffer) throws -> [DetectionResult] {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        let request = VNCoreMLRequest(model: visionModel)
        request.imageCropAndScaleOption = .scaleFit

        do {
            try handler.perform([request])
        } catch {
            throw ModelServiceError.inferenceFailed(underlying: error)
        }

        let observations = request.results as? [VNRecognizedObjectObservation] ?? []
        return observations.compactMap { observation in
            guard let topLabel = observation.labels.first else { return nil }
            return DetectionResult(
                label: topLabel.identifier,
                confidence: Float(topLabel.confidence),
                boundingBox: observation.boundingBox
            )
        }
    }
}
