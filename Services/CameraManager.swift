import AVFoundation
import CoreGraphics
import Foundation
import UIKit

// MARK: - Tipe state kamera

enum CameraPermission: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

enum CameraError: Error, Equatable, Sendable, LocalizedError {
    case cameraNotFound
    case configurationFailed

    /// Pesan user-facing (E-03, E-04) — Bahasa Indonesia, tanpa detail teknis.
    var errorDescription: String? {
        switch self {
        case .cameraNotFound:
            return "Kamera tidak ditemukan."
        case .configurationFailed:
            return "Kamera tidak dapat dimulai. Coba tutup dan buka kembali aplikasi."
        }
    }
}

/// Snapshot state kamera yang dikirim ke presentation layer.
struct CameraState: Equatable, Sendable {
    var permission: CameraPermission = .notDetermined
    var isSessionRunning: Bool = false
    var videoSize: CGSize = .zero
    var error: CameraError?
}

// MARK: - CameraManager

/// Service Pattern: `final class`, dependency di-inject via `init`.
///
/// Tanggung jawab: konfigurasi session, permission, rotasi buffer (90°),
/// setup delegate, meneruskan buffer ke `FrameProcessor`.
///
/// **Tidak boleh**: mengetahui model apa yang dipakai; membuat business logic deteksi.
final class CameraManager: NSObject, @unchecked Sendable {

    // MARK: Dependencies

    private let frameProcessor: FrameProcessor
    private let onStateChange: @MainActor @Sendable (CameraState) -> Void

    // MARK: Session

    private let session = AVCaptureSession()

    /// Satu-satunya `DispatchQueue` di seluruh pipeline.
    ///
    /// Ini adalah *delegate queue* yang diwajibkan AVFoundation, sekaligus tempat
    /// inference berjalan (PERF-03 / aturan backpressure #2). Antrean ini tidak
    /// pernah menyimpan frame — `alwaysDiscardsLateVideoFrames` membuang frame
    /// sebelum sampai ke delegate.
    private let sessionQueue = DispatchQueue(label: "BilliardO.cameraSession")

    private let lock = NSLock()
    private var state = CameraState()
    private var isConfigured = false
    private var observers: [NSObjectProtocol] = []

    /// Session dibagikan ke `CameraPreview` untuk menampilkan stream kamera.
    /// Hanya dibaca, tidak pernah dikonfigurasi dari luar.
    var captureSession: AVCaptureSession { session }

    init(
        frameProcessor: FrameProcessor,
        onStateChange: @escaping @MainActor @Sendable (CameraState) -> Void
    ) {
        self.frameProcessor = frameProcessor
        self.onStateChange = onStateChange
        super.init()
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver(_:))
    }

    // MARK: - Permission (FR-001, FR-002)

    /// Dipanggil saat view muncul (FR-005).
    ///
    /// System dialog hanya ditampilkan saat status `notDetermined` (FR-001).
    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            update { $0.permission = .notDetermined }
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                if granted {
                    self.start()
                } else {
                    self.update { $0.permission = .denied }
                }
            }

        case .authorized:
            update { $0.permission = .authorized }
            startSession()

        case .denied:
            update { $0.permission = .denied }

        case .restricted:
            update { $0.permission = .restricted }

        @unknown default:
            update { $0.permission = .denied }
        }
    }

    /// FR-005: session dihentikan saat view hilang atau aplikasi di-background.
    func stop() {
        sessionQueue.async { [self] in
            if session.isRunning {
                session.stopRunning()
            }
            update { $0.isSessionRunning = false }
        }
    }

    // MARK: - Lifecycle aplikasi (FR-005, E-08)

    func observeApplicationLifecycle() {
        let center = NotificationCenter.default
        observers = [
            center.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: nil
            ) { [weak self] _ in self?.stop() },
            center.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil,
                queue: nil
            ) { [weak self] _ in self?.start() },
        ]
    }

    // MARK: - Session configuration (FR-003, FR-006)

    private func startSession() {
        sessionQueue.async { [self] in
            if !isConfigured {
                guard configure() else { return }
                applyVideoRotation()
                isConfigured = true
            }
            guard !session.isRunning else {
                update { $0.isSessionRunning = true }
                return
            }
            session.startRunning()
            update { $0.isSessionRunning = session.isRunning }
        }
    }

    /// Konfigurasi session. Selalu menutup `beginConfiguration()` lewat `defer`,
    /// termasuk pada jalur kegagalan, sehingga session tidak pernah tertinggal
    /// dalam state setengah jadi.
    @discardableResult
    private func configure() -> Bool {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        if session.canSetSessionPreset(.hd1920x1080) {
            session.sessionPreset = .hd1920x1080
        }

        guard let camera = rearCamera() else {
            fail(.cameraNotFound)
            return false
        }

        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: camera)
        } catch {
            fail(.configurationFailed)
            return false
        }
        guard session.canAddInput(input) else {
            fail(.configurationFailed)
            return false
        }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        // FR-003: kamera yang membuang frame, bukan antrian yang menumpuk.
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        guard session.canAddOutput(output) else {
            fail(.configurationFailed)
            return false
        }
        session.addOutput(output)

        // FR-003: activeVideoMinFrameDuration / activeVideoMaxFrameDuration
        // sengaja tidak disentuh — capture FPS dibiarkan bebas.
        output.setSampleBufferDelegate(self, queue: sessionQueue)

        videoOutput = output
        return true
    }

    // MARK: - Rotation (FR-006)

    /// Kandidat sudut, diurutkan sesuai konvensi perangkat fisik lebih dulu.
    ///
    /// `videoRotationAngle` bersifat **relatif terhadap orientasi native sumber**.
    /// Sensor perangkat fisik native-nya landscape, jadi 90° menghasilkan portrait.
    /// Mock camera Simulator native-nya portrait, sehingga 90° justru menghasilkan
    /// landscape. Kandidat kedua (0°) menutup selisih itu sehingga AC FR-006 —
    /// "buffer yang diterima FrameProcessor sudah portrait upright" — berlaku
    /// di kedua lingkungan tanpa pengecualian.
    private let rotationCandidates: [CGFloat] = [90, 0]
    private var rotationIndex = 0
    private var isOrientationVerified = false
    private var videoOutput: AVCaptureVideoDataOutput?

    /// FR-006: satu-satunya tempat rotasi ditangani.
    ///
    /// Dipanggil setelah `commitConfiguration()` karena dukungan sudut rotasi
    /// pada connection baru diketahui setelah session selesai dikonfigurasi.
    private func applyVideoRotation() {
        guard let connection = videoOutput?.connection(with: .video) else { return }

        while rotationIndex < rotationCandidates.count {
            let angle = rotationCandidates[rotationIndex]
            if connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
                return
            }
            rotationIndex += 1
        }
    }

    /// Kandidat sudut berikutnya, dipanggil bila frame ternyata masih landscape.
    private func advanceRotation() {
        rotationIndex += 1
        if rotationIndex < rotationCandidates.count {
            applyVideoRotation()
        } else {
            // Kedua kandidat sudah dicoba — tidak ada rotasi lain yang memungkinkan.
            // Frame tetap diteruskan agar session tidak berhenti total.
            isOrientationVerified = true
        }
    }

    private func rearCamera() -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(for: .video)
    }

    private func fail(_ error: CameraError) {
        update {
            $0.error = error
            $0.isSessionRunning = false
        }
    }

    // MARK: - State publication

    private func update(_ mutate: @Sendable (inout CameraState) -> Void) {
        let snapshot: CameraState = {
            lock.lock()
            defer { lock.unlock() }
            mutate(&state)
            return state
        }()

        Task { @MainActor [onStateChange] in
            onStateChange(snapshot)
        }
    }
}

// MARK: - Frame intake (FR-007)

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Verifikasi kontrak FR-006 sekali, terhadap frame pertama yang sampai.
        if !isOrientationVerified {
            guard CVPixelBufferGetWidth(pixelBuffer) <= CVPixelBufferGetHeight(pixelBuffer) else {
                advanceRotation()
                return
            }
            isOrientationVerified = true
            publishVideoSize(CGSize(
                width: CVPixelBufferGetWidth(pixelBuffer),
                height: CVPixelBufferGetHeight(pixelBuffer)
            ))
        }

        frameProcessor.process(sampleBuffer: sampleBuffer)
    }

    /// Dimensi buffer dalam orientasi portrait upright, dikirim sekali saja.
    /// Dipakai `DetectionRenderer` agar overlay sejajar dengan preview.
    private func publishVideoSize(_ size: CGSize) {
        update { $0.videoSize = size }
    }
}
