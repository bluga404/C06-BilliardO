# Standar Penulisan Kode

## Bahasa & Framework

- **Swift 6.0+** — selalu gunakan fitur bahasa terbaru
- **SwiftUI** — untuk semua UI. Tidak menggunakan UIKit kecuali untuk wrapper (`UIViewRepresentable`)
- **iOS 26+** — target minimum

## Naming Conventions

### Files

| Tipe | Format | Contoh |
|------|--------|--------|
| View | `[Nama]View.swift` | `FaceScanView.swift` |
| ViewModel | `[Nama]ViewModel.swift` | `FaceScanViewModel.swift` |
| Model | `[Nama].swift` | `AcneDetection.swift` |
| Service | `[Nama]Service.swift` | `AcneDetectionService.swift` |
| Factory | `[Nama]Factory.swift` | `FaceScanFactory.swift` |
| Component | `[Nama]View.swift` atau `[Nama].swift` | `GlassCard.swift` |

### Swift Code

| Elemen | Style | Contoh |
|--------|-------|--------|
| Type (struct, class, enum) | PascalCase | `AcneDetection`, `FaceScanPhase` |
| Property & method | camelCase | `holdProgress`, `startScan()` |
| Constant | camelCase | `let jpegCompressionQuality: CGFloat = 0.82` |
| Enum case | camelCase | `.scanning`, `.permissionDenied` |
| Protocol | PascalCase + deskriptif | `AppLogging`, `KeyValueStore` |
| Boolean | prefix `is`/`has`/`should` | `isModelLoaded`, `hasChanges` |

### Folder & Module

- Nama folder: **PascalCase** (`Features/`, `ViewModels/`, `Components/`)
- Satu file = satu tipe utama (jangan gabung banyak struct besar dalam satu file)
- File kecil yang terkait erat boleh digabung (contoh: semua presentation model dalam satu file)

## ViewModel Pattern

Suzuran menggunakan **ObservableObject + @Published** (bukan @Observable) karena kompatibilitas dengan seluruh codebase:

```swift
@MainActor
final class NamaViewModel: NSObject, ObservableObject {
    @Published private(set) var state: SomeState = .initial
    
    private let service: SomeService
    
    init(service: SomeService) {
        self.service = service
        super.init()
    }
    
    func doSomething() {
        // business logic
    }
}
```

**Aturan ViewModel:**
- Selalu `@MainActor` — semua state updates di main thread
- Properties yang di-publish menggunakan `private(set)` — view hanya baca, tidak menulis
- Dependencies di-inject via `init`
- Tidak boleh import `SwiftUI` kecuali untuk tipe seperti `CGFloat`, `Color` yang diperlukan

## View Pattern

```swift
struct NamaView: View {
    @ObservedObject private var viewModel: NamaViewModel
    let onDismiss: () -> Void
    
    init(viewModel: NamaViewModel, onDismiss: @escaping () -> Void) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        // UI code
    }
}
```

**Aturan View:**
- Terima ViewModel via init (jangan buat sendiri di View)
- Gunakan `@ObservedObject` untuk ViewModel yang di-inject
- Pecah body yang panjang ke computed properties atau sub-views

## Service Pattern

```swift
final class NamaService {
    private let dependency: SomeDependency
    
    init(dependency: SomeDependency = .init()) {
        self.dependency = dependency
    }
    
    func doWork() async throws -> Result {
        // implementation
    }
}
```

**Aturan Service:**
- Tidak ada protokol kecuali benar-benar perlu di-mock untuk testing
- `async throws` untuk operasi yang bisa gagal
- Tidak boleh mengakses UI atau @Published properties

## Error Handling

Semua error menggunakan `AppError` enum:

```swift
// Throwing errors
throw AppError.unknown(message: "Deskripsi error")

// Menampilkan ke user
phase = .error(message: "Pesan untuk user dalam Bahasa Indonesia")
```

## Komentar & Dokumentasi

- **MARK** untuk membagi section besar: `// MARK: - Camera Setup`
- Doc comment (`///`) untuk public API dan fungsi kompleks
- Komentar inline hanya jika logic tidak obvious
- Jangan komentar yang jelas dari kode itu sendiri

```swift
// ✅ Baik — menjelaskan "kenapa"
// Filter confidence < 0.05 karena model sering false positive di bawah threshold ini
guard conf >= confidenceThreshold else { continue }

// ❌ Buruk — menjelaskan "apa" yang sudah jelas
// Increment counter by 1
counter += 1
```

## Bahasa

- **Kode**: Bahasa Inggris (variabel, fungsi, komentar teknis)
- **UI strings**: Bahasa Indonesia (teks yang dilihat user)
- **Error messages untuk user**: Bahasa Indonesia
- **Dokumentasi**: Bahasa Indonesia untuk docs tim, Inggris untuk code docs