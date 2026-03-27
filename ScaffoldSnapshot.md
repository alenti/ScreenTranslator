# ScreenTranslator Scaffold Snapshot

## Folder Tree

```text
ScreenTranslator
ScreenTranslator/App
ScreenTranslator/App/AppContainer.swift
ScreenTranslator/App/AppCoordinator.swift
ScreenTranslator/App/AppEnvironment.swift
ScreenTranslator/App/AppRoute.swift
ScreenTranslator/Core
ScreenTranslator/Core/Models
ScreenTranslator/Core/Models/AppError.swift
ScreenTranslator/Core/Models/AppSettings.swift
ScreenTranslator/Core/Models/OCRTextObservation.swift
ScreenTranslator/Core/Models/OverlayRenderResult.swift
ScreenTranslator/Core/Models/OverlayRenderStyle.swift
ScreenTranslator/Core/Models/ProcessingJob.swift
ScreenTranslator/Core/Models/ProcessingState.swift
ScreenTranslator/Core/Models/ScreenshotInput.swift
ScreenTranslator/Core/Models/TextBlock.swift
ScreenTranslator/Core/Models/TranslationBlock.swift
ScreenTranslator/Core/Protocols
ScreenTranslator/Core/Protocols/HistoryStoreProtocol.swift
ScreenTranslator/Core/Protocols/OCRServiceProtocol.swift
ScreenTranslator/Core/Protocols/OverlayRendererProtocol.swift
ScreenTranslator/Core/Protocols/SettingsStoreProtocol.swift
ScreenTranslator/Core/Protocols/TextGroupingServiceProtocol.swift
ScreenTranslator/Core/Protocols/TranslationServiceProtocol.swift
ScreenTranslator/Core/Services
ScreenTranslator/Core/Services/Grouping
ScreenTranslator/Core/Services/Grouping/BoundingBoxGrouper.swift
ScreenTranslator/Core/Services/Grouping/TextBlockComposer.swift
ScreenTranslator/Core/Services/Grouping/TextGroupingService.swift
ScreenTranslator/Core/Services/Input
ScreenTranslator/Core/Services/Input/ImageOrientationResolver.swift
ScreenTranslator/Core/Services/Input/ScreenshotInputBuilder.swift
ScreenTranslator/Core/Services/Input/ScreenshotNormalizer.swift
ScreenTranslator/Core/Services/OCR
ScreenTranslator/Core/Services/OCR/OCRRequestFactory.swift
ScreenTranslator/Core/Services/OCR/OCRService.swift
ScreenTranslator/Core/Services/OCR/VisionOCRService.swift
ScreenTranslator/Core/Services/Rendering
ScreenTranslator/Core/Services/Rendering/OverlayImageComposer.swift
ScreenTranslator/Core/Services/Rendering/OverlayLayoutEngine.swift
ScreenTranslator/Core/Services/Rendering/OverlayRenderer.swift
ScreenTranslator/Core/Services/Rendering/OverlayTextFitter.swift
ScreenTranslator/Core/Services/Storage
ScreenTranslator/Core/Services/Storage/HistoryStore.swift
ScreenTranslator/Core/Services/Storage/SettingsStore.swift
ScreenTranslator/Core/Services/Storage/TemporaryImageStore.swift
ScreenTranslator/Core/Services/Translation
ScreenTranslator/Core/Services/Translation/OnDeviceTranslationService.swift
ScreenTranslator/Core/Services/Translation/TranslationBatchBuilder.swift
ScreenTranslator/Core/Services/Translation/TranslationLanguageManager.swift
ScreenTranslator/Core/Services/Translation/TranslationService.swift
ScreenTranslator/Features
ScreenTranslator/Features/Debug
ScreenTranslator/Features/Debug/DebugOverlayInspectorView.swift
ScreenTranslator/Features/Debug/DebugView.swift
ScreenTranslator/Features/Errors
ScreenTranslator/Features/Errors/ErrorView.swift
ScreenTranslator/Features/Errors/ErrorViewModel.swift
ScreenTranslator/Features/Processing
ScreenTranslator/Features/Processing/ProcessingOrchestrator.swift
ScreenTranslator/Features/Processing/ProcessingView.swift
ScreenTranslator/Features/Processing/ProcessingViewModel.swift
ScreenTranslator/Features/ResultOverlay
ScreenTranslator/Features/ResultOverlay/OverlayBlockView.swift
ScreenTranslator/Features/ResultOverlay/OverlayCanvasView.swift
ScreenTranslator/Features/ResultOverlay/ResultMode.swift
ScreenTranslator/Features/ResultOverlay/ResultOverlayView.swift
ScreenTranslator/Features/ResultOverlay/ResultOverlayViewModel.swift
ScreenTranslator/Features/Settings
ScreenTranslator/Features/Settings/LanguagePreparationView.swift
ScreenTranslator/Features/Settings/SettingsView.swift
ScreenTranslator/Features/Settings/SettingsViewModel.swift
ScreenTranslator/Intents
ScreenTranslator/Intents/AppShortcutsProvider.swift
ScreenTranslator/Intents/IntentInputDecoder.swift
ScreenTranslator/Intents/IntentResultRouter.swift
ScreenTranslator/Intents/TranslateScreenshotIntent.swift
ScreenTranslator/Resources
ScreenTranslator/Resources/Assets.xcassets
ScreenTranslator/Resources/Assets.xcassets/AccentColor.colorset
ScreenTranslator/Resources/Assets.xcassets/AccentColor.colorset/Contents.json
ScreenTranslator/Resources/Assets.xcassets/AppIcon.appiconset
ScreenTranslator/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json
ScreenTranslator/Resources/Assets.xcassets/Contents.json
ScreenTranslator/Resources/Preview Content
ScreenTranslator/Resources/Preview Content/Preview Assets.xcassets
ScreenTranslator/Resources/Preview Content/Preview Assets.xcassets/Contents.json
ScreenTranslator/ScaffoldSnapshot.md
ScreenTranslator/ScreenTranslatorApp.swift
ScreenTranslator/SupportingFiles
ScreenTranslator/SupportingFiles/Info.plist
ScreenTranslator/SupportingFiles/ScreenTranslator.entitlements
ScreenTranslator/Tests
ScreenTranslator/Tests/Integration
ScreenTranslator/Tests/Integration/ScreenTranslatorIntegrationPlaceholderTests.swift
ScreenTranslator/Tests/Unit
ScreenTranslator/Tests/Unit/ScreenTranslatorScaffoldTests.swift
```

## ScreenTranslator/App/AppContainer.swift

```swift
import Foundation

@MainActor
final class AppContainer {
    let screenshotInputBuilder: ScreenshotInputBuilder
    let imageOrientationResolver: ImageOrientationResolver
    let screenshotNormalizer: ScreenshotNormalizer

    let ocrRequestFactory: OCRRequestFactory
    let ocrService: any OCRServiceProtocol

    let boundingBoxGrouper: BoundingBoxGrouper
    let textBlockComposer: TextBlockComposer
    let textGroupingService: any TextGroupingServiceProtocol

    let translationLanguageManager: TranslationLanguageManager
    let translationBatchBuilder: TranslationBatchBuilder
    let translationService: any TranslationServiceProtocol

    let overlayLayoutEngine: OverlayLayoutEngine
    let overlayTextFitter: OverlayTextFitter
    let overlayImageComposer: OverlayImageComposer
    let overlayRenderer: any OverlayRendererProtocol

    let historyStore: any HistoryStoreProtocol
    let temporaryImageStore: TemporaryImageStore
    let settingsStore: any SettingsStoreProtocol

    let processingOrchestrator: ProcessingOrchestrator

    init() {
        let screenshotInputBuilder = ScreenshotInputBuilder()
        let imageOrientationResolver = ImageOrientationResolver()
        let screenshotNormalizer = ScreenshotNormalizer(
            orientationResolver: imageOrientationResolver
        )

        let ocrRequestFactory = OCRRequestFactory()
        let ocrService = PlaceholderOCRService(requestFactory: ocrRequestFactory)

        let boundingBoxGrouper = BoundingBoxGrouper()
        let textBlockComposer = TextBlockComposer()
        let textGroupingService = PlaceholderTextGroupingService(
            grouper: boundingBoxGrouper,
            composer: textBlockComposer
        )

        let translationLanguageManager = TranslationLanguageManager()
        let translationBatchBuilder = TranslationBatchBuilder()
        let translationService = PlaceholderTranslationService(
            languageManager: translationLanguageManager,
            batchBuilder: translationBatchBuilder
        )

        let overlayLayoutEngine = OverlayLayoutEngine()
        let overlayTextFitter = OverlayTextFitter()
        let overlayImageComposer = OverlayImageComposer()
        let overlayRenderer = PlaceholderOverlayRenderer(
            layoutEngine: overlayLayoutEngine,
            textFitter: overlayTextFitter,
            imageComposer: overlayImageComposer
        )

        let historyStore = HistoryStore()
        let temporaryImageStore = TemporaryImageStore()
        let settingsStore = SettingsStore()

        let processingOrchestrator = ProcessingOrchestrator(
            screenshotNormalizer: screenshotNormalizer,
            ocrService: ocrService,
            textGroupingService: textGroupingService,
            translationService: translationService,
            overlayRenderer: overlayRenderer
        )

        self.screenshotInputBuilder = screenshotInputBuilder
        self.imageOrientationResolver = imageOrientationResolver
        self.screenshotNormalizer = screenshotNormalizer

        self.ocrRequestFactory = ocrRequestFactory
        self.ocrService = ocrService

        self.boundingBoxGrouper = boundingBoxGrouper
        self.textBlockComposer = textBlockComposer
        self.textGroupingService = textGroupingService

        self.translationLanguageManager = translationLanguageManager
        self.translationBatchBuilder = translationBatchBuilder
        self.translationService = translationService

        self.overlayLayoutEngine = overlayLayoutEngine
        self.overlayTextFitter = overlayTextFitter
        self.overlayImageComposer = overlayImageComposer
        self.overlayRenderer = overlayRenderer

        self.historyStore = historyStore
        self.temporaryImageStore = temporaryImageStore
        self.settingsStore = settingsStore

        self.processingOrchestrator = processingOrchestrator
    }

    func makeProcessingViewModel() -> ProcessingViewModel {
        ProcessingViewModel(orchestrator: processingOrchestrator)
    }

    func makeResultOverlayViewModel(
        result: OverlayRenderResult = .placeholder()
    ) -> ResultOverlayViewModel {
        ResultOverlayViewModel(result: result)
    }

    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(
            settingsStore: settingsStore,
            languageManager: translationLanguageManager
        )
    }

    func makeErrorViewModel(error: AppError?) -> ErrorViewModel {
        ErrorViewModel(
            error: error ?? .featureNotReady(
                "The error flow is scaffolded, but not wired to runtime failures yet."
            )
        )
    }
}

```

## ScreenTranslator/App/AppCoordinator.swift

```swift
import Foundation

@MainActor
final class AppCoordinator: ObservableObject {
    @Published private(set) var route: AppRoute
    @Published private(set) var activeError: AppError?
    @Published private(set) var activeJob: ProcessingJob?
    @Published private(set) var latestResult: OverlayRenderResult

    init(
        route: AppRoute = .processing,
        activeError: AppError? = nil,
        activeJob: ProcessingJob? = nil,
        latestResult: OverlayRenderResult = .placeholder()
    ) {
        self.route = route
        self.activeError = activeError
        self.activeJob = activeJob
        self.latestResult = latestResult
    }

    func showProcessing(job: ProcessingJob? = nil) {
        activeJob = job
        activeError = nil
        route = .processing
    }

    func showResult(_ result: OverlayRenderResult? = nil) {
        if let result {
            latestResult = result
        }

        activeError = nil
        route = .result
    }

    func showError(_ error: AppError) {
        activeError = error
        route = .error
    }

    func showSettings() {
        route = .settings
    }

    func showDebug() {
        route = .debug
    }

    func returnToProcessing() {
        route = .processing
    }
}

```

## ScreenTranslator/App/AppEnvironment.swift

```swift
import Foundation

@MainActor
final class AppEnvironment: ObservableObject {
    let container: AppContainer
    let coordinator: AppCoordinator
    let processingViewModel: ProcessingViewModel
    let settingsViewModel: SettingsViewModel

    init(container: AppContainer) {
        let processingViewModel = container.makeProcessingViewModel()
        let settingsViewModel = container.makeSettingsViewModel()
        let placeholderResult = OverlayRenderResult.placeholder(
            style: settingsViewModel.settings.overlayStyle
        )

        self.container = container
        self.processingViewModel = processingViewModel
        self.settingsViewModel = settingsViewModel
        self.coordinator = AppCoordinator(latestResult: placeholderResult)
    }

    static func bootstrap() -> AppEnvironment {
        AppEnvironment(container: AppContainer())
    }
}

```

## ScreenTranslator/App/AppRoute.swift

```swift
import Foundation

enum AppRoute: String, CaseIterable, Sendable {
    case idle
    case processing
    case result
    case error
    case settings
    case debug
}

```

## ScreenTranslator/Core/Models/AppError.swift

```swift
import Foundation

enum AppError: Error, LocalizedError, Equatable, Sendable {
    case ocrFailure
    case translationUnavailable
    case unsupportedImage
    case renderingFailure
    case missingLanguagePack
    case intentInputFailure
    case noTextDetected
    case featureNotReady(String)

    var errorDescription: String? {
        switch self {
        case .ocrFailure:
            return "Text recognition is not available in the scaffold yet."
        case .translationUnavailable:
            return "On-device translation is not available in the scaffold yet."
        case .unsupportedImage:
            return "The screenshot input is not supported yet."
        case .renderingFailure:
            return "Overlay rendering is not available in the scaffold yet."
        case .missingLanguagePack:
            return "Offline language preparation has not been implemented yet."
        case .intentInputFailure:
            return "Screenshot handoff from App Intents will be added in the next phase."
        case .noTextDetected:
            return "No text was detected in the current placeholder result."
        case .featureNotReady(let message):
            return message
        }
    }
}

```

## ScreenTranslator/Core/Models/AppSettings.swift

```swift
import Foundation

struct AppSettings: Equatable, Sendable {
    var overlayStyle: OverlayRenderStyle
    var preferredDisplayModeRawValue: String
    var historyEnabled: Bool
    var debugOptionsEnabled: Bool

    static let defaultValue = AppSettings(
        overlayStyle: .defaultValue,
        preferredDisplayModeRawValue: "overlay",
        historyEnabled: true,
        debugOptionsEnabled: true
    )
}

```

## ScreenTranslator/Core/Models/OCRTextObservation.swift

```swift
import CoreGraphics
import Foundation

struct OCRTextObservation: Identifiable, Equatable, Sendable {
    let id: UUID
    let originalText: String
    let boundingBox: CGRect
    let confidence: Double
    let lineIndex: Int
    let blockIndex: Int?

    init(
        id: UUID = UUID(),
        originalText: String,
        boundingBox: CGRect,
        confidence: Double,
        lineIndex: Int,
        blockIndex: Int? = nil
    ) {
        self.id = id
        self.originalText = originalText
        self.boundingBox = boundingBox
        self.confidence = confidence
        self.lineIndex = lineIndex
        self.blockIndex = blockIndex
    }

    static let placeholder = OCRTextObservation(
        originalText: "示例文本",
        boundingBox: CGRect(x: 24, y: 40, width: 240, height: 56),
        confidence: 0.95,
        lineIndex: 0
    )
}

```

## ScreenTranslator/Core/Models/OverlayRenderResult.swift

```swift
import Foundation

struct OverlayRenderResult: Equatable, Sendable {
    struct RenderMetadata: Equatable, Sendable {
        let generatedAt: Date
        let note: String

        static let placeholder = RenderMetadata(
            generatedAt: .now,
            note: "Placeholder overlay content generated by the initial scaffold."
        )
    }

    let sourceInput: ScreenshotInput
    let translatedBlocks: [TranslationBlock]
    let renderStyle: OverlayRenderStyle
    let renderMetadata: RenderMetadata
    let precomposedImageData: Data?

    static func placeholder(
        input: ScreenshotInput = .placeholder,
        style: OverlayRenderStyle = .defaultValue
    ) -> OverlayRenderResult {
        OverlayRenderResult(
            sourceInput: input,
            translatedBlocks: [
                TranslationBlock.placeholder,
                TranslationBlock(
                    sourceText: "立即购买",
                    translatedText: "Купить сейчас",
                    sourceBoundingBox: .init(x: 24, y: 120, width: 220, height: 50),
                    targetFrame: .init(x: 24, y: 120, width: 220, height: 70),
                    renderingStyle: style
                )
            ],
            renderStyle: style,
            renderMetadata: .placeholder,
            precomposedImageData: nil
        )
    }
}

```

## ScreenTranslator/Core/Models/OverlayRenderStyle.swift

```swift
import Foundation

struct OverlayRenderStyle: Equatable, Sendable {
    enum TextColorStyle: String, CaseIterable, Sendable {
        case automatic
        case light
        case dark
    }

    var minimumFontSize: Double
    var maximumFontSize: Double
    var padding: Double
    var backgroundOpacity: Double
    var cornerRadius: Double
    var textColorStyle: TextColorStyle

    static let defaultValue = OverlayRenderStyle(
        minimumFontSize: 12,
        maximumFontSize: 22,
        padding: 8,
        backgroundOpacity: 0.78,
        cornerRadius: 10,
        textColorStyle: .automatic
    )
}

```

## ScreenTranslator/Core/Models/ProcessingJob.swift

```swift
import Foundation

struct ProcessingJob: Identifiable, Equatable, Sendable {
    let id: UUID
    let input: ScreenshotInput
    let createdAt: Date

    init(
        id: UUID = UUID(),
        input: ScreenshotInput,
        createdAt: Date = .now
    ) {
        self.id = id
        self.input = input
        self.createdAt = createdAt
    }

    static let placeholder = ProcessingJob(input: .placeholder)
}

```

## ScreenTranslator/Core/Models/ProcessingState.swift

```swift
import Foundation

enum ProcessingState: String, CaseIterable, Sendable {
    case idle
    case receivedInput
    case preparingImage
    case performingOCR
    case groupingText
    case translatingBlocks
    case renderingOverlay
    case completed
    case failed

    var displayTitle: String {
        switch self {
        case .idle:
            return "Waiting for Screenshot"
        case .receivedInput:
            return "Screenshot Received"
        case .preparingImage:
            return "Preparing Image"
        case .performingOCR:
            return "Recognizing Text"
        case .groupingText:
            return "Grouping Text Blocks"
        case .translatingBlocks:
            return "Translating Blocks"
        case .renderingOverlay:
            return "Rendering Overlay"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        }
    }
}

```

## ScreenTranslator/Core/Models/ScreenshotInput.swift

```swift
import CoreGraphics
import Foundation

struct ScreenshotInput: Identifiable, Equatable, Sendable {
    enum Orientation: String, CaseIterable, Sendable {
        case up
        case down
        case left
        case right
    }

    struct SourceMetadata: Equatable, Sendable {
        let sourceName: String
        let automationName: String?

        static let scaffold = SourceMetadata(
            sourceName: "Scaffold",
            automationName: "Prompt 1 Placeholder"
        )
    }

    let id: UUID
    let imageData: Data
    let size: CGSize
    let orientation: Orientation
    let timestamp: Date
    let sourceMetadata: SourceMetadata

    init(
        id: UUID = UUID(),
        imageData: Data,
        size: CGSize,
        orientation: Orientation,
        timestamp: Date = .now,
        sourceMetadata: SourceMetadata
    ) {
        self.id = id
        self.imageData = imageData
        self.size = size
        self.orientation = orientation
        self.timestamp = timestamp
        self.sourceMetadata = sourceMetadata
    }

    static let placeholder = ScreenshotInput(
        imageData: Data(),
        size: CGSize(width: 1179, height: 2556),
        orientation: .up,
        sourceMetadata: .scaffold
    )
}

```

## ScreenTranslator/Core/Models/TextBlock.swift

```swift
import CoreGraphics
import Foundation

struct TextBlock: Identifiable, Equatable, Sendable {
    let id: UUID
    let sourceText: String
    let observations: [OCRTextObservation]
    let combinedBoundingBox: CGRect

    init(
        id: UUID = UUID(),
        sourceText: String,
        observations: [OCRTextObservation],
        combinedBoundingBox: CGRect
    ) {
        self.id = id
        self.sourceText = sourceText
        self.observations = observations
        self.combinedBoundingBox = combinedBoundingBox
    }

    static let placeholder = TextBlock(
        sourceText: "示例文本",
        observations: [.placeholder],
        combinedBoundingBox: OCRTextObservation.placeholder.boundingBox
    )
}

```

## ScreenTranslator/Core/Models/TranslationBlock.swift

```swift
import CoreGraphics
import Foundation

struct TranslationBlock: Identifiable, Equatable, Sendable {
    let id: UUID
    let sourceText: String
    let translatedText: String
    let sourceBoundingBox: CGRect
    let targetFrame: CGRect
    let renderingStyle: OverlayRenderStyle

    init(
        id: UUID = UUID(),
        sourceText: String,
        translatedText: String,
        sourceBoundingBox: CGRect,
        targetFrame: CGRect,
        renderingStyle: OverlayRenderStyle
    ) {
        self.id = id
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.sourceBoundingBox = sourceBoundingBox
        self.targetFrame = targetFrame
        self.renderingStyle = renderingStyle
    }

    static let placeholder = TranslationBlock(
        sourceText: "示例文本",
        translatedText: "Пример перевода",
        sourceBoundingBox: CGRect(x: 24, y: 40, width: 240, height: 56),
        targetFrame: CGRect(x: 24, y: 40, width: 240, height: 72),
        renderingStyle: .defaultValue
    )
}

```

## ScreenTranslator/Core/Protocols/HistoryStoreProtocol.swift

```swift
import Foundation

protocol HistoryStoreProtocol {
    func loadHistory() -> [OverlayRenderResult]
    func save(_ result: OverlayRenderResult)
    func clear()
}

```

## ScreenTranslator/Core/Protocols/OCRServiceProtocol.swift

```swift
import Foundation

protocol OCRServiceProtocol {
    func recognizeText(in input: ScreenshotInput) async throws -> [OCRTextObservation]
}

```

## ScreenTranslator/Core/Protocols/OverlayRendererProtocol.swift

```swift
import Foundation

protocol OverlayRendererProtocol {
    func renderOverlay(
        for input: ScreenshotInput,
        translatedBlocks: [TranslationBlock],
        style: OverlayRenderStyle
    ) async throws -> OverlayRenderResult
}

```

## ScreenTranslator/Core/Protocols/SettingsStoreProtocol.swift

```swift
import Foundation

protocol SettingsStoreProtocol {
    func loadSettings() -> AppSettings
    func saveSettings(_ settings: AppSettings)
}

```

## ScreenTranslator/Core/Protocols/TextGroupingServiceProtocol.swift

```swift
import Foundation

protocol TextGroupingServiceProtocol {
    func makeBlocks(from observations: [OCRTextObservation]) -> [TextBlock]
}

```

## ScreenTranslator/Core/Protocols/TranslationServiceProtocol.swift

```swift
import Foundation

protocol TranslationServiceProtocol {
    func translate(blocks: [TextBlock]) async throws -> [TranslationBlock]
}

```

## ScreenTranslator/Core/Services/Grouping/BoundingBoxGrouper.swift

```swift
import Foundation

struct BoundingBoxGrouper {
    func group(_ observations: [OCRTextObservation]) -> [[OCRTextObservation]] {
        guard observations.isEmpty == false else {
            return []
        }

        return observations.map { [$0] }
    }
}

```

## ScreenTranslator/Core/Services/Grouping/TextBlockComposer.swift

```swift
import Foundation

struct TextBlockComposer {
    func compose(groups: [[OCRTextObservation]]) -> [TextBlock] {
        groups.compactMap { group in
            guard let first = group.first else {
                return nil
            }

            let sourceText = group
                .map(\.originalText)
                .joined(separator: " ")

            return TextBlock(
                sourceText: sourceText,
                observations: group,
                combinedBoundingBox: first.boundingBox
            )
        }
    }
}

```

## ScreenTranslator/Core/Services/Grouping/TextGroupingService.swift

```swift
import Foundation

struct PlaceholderTextGroupingService: TextGroupingServiceProtocol {
    let grouper: BoundingBoxGrouper
    let composer: TextBlockComposer

    func makeBlocks(from observations: [OCRTextObservation]) -> [TextBlock] {
        let groups = grouper.group(observations)
        return composer.compose(groups: groups)
    }
}

```

## ScreenTranslator/Core/Services/Input/ImageOrientationResolver.swift

```swift
import Foundation

struct ImageOrientationResolver {
    func resolve(for input: ScreenshotInput) -> ScreenshotInput.Orientation {
        input.orientation
    }
}

```

## ScreenTranslator/Core/Services/Input/ScreenshotInputBuilder.swift

```swift
import CoreGraphics
import Foundation

struct ScreenshotInputBuilder {
    func build(
        imageData: Data,
        size: CGSize,
        orientation: ScreenshotInput.Orientation = .up,
        sourceMetadata: ScreenshotInput.SourceMetadata = .scaffold
    ) -> ScreenshotInput {
        ScreenshotInput(
            imageData: imageData,
            size: size,
            orientation: orientation,
            sourceMetadata: sourceMetadata
        )
    }
}

```

## ScreenTranslator/Core/Services/Input/ScreenshotNormalizer.swift

```swift
import Foundation

struct ScreenshotNormalizer {
    private let orientationResolver: ImageOrientationResolver

    init(orientationResolver: ImageOrientationResolver) {
        self.orientationResolver = orientationResolver
    }

    func normalize(_ input: ScreenshotInput) -> ScreenshotInput {
        ScreenshotInput(
            id: input.id,
            imageData: input.imageData,
            size: input.size,
            orientation: orientationResolver.resolve(for: input),
            timestamp: input.timestamp,
            sourceMetadata: input.sourceMetadata
        )
    }
}

```

## ScreenTranslator/Core/Services/OCR/OCRRequestFactory.swift

```swift
import Foundation

struct OCRRequestFactory {
    struct Configuration: Equatable, Sendable {
        let recognitionLevelDescription: String
        let languageHints: [String]
        let usesLanguageCorrection: Bool
    }

    func makePlaceholderConfiguration() -> Configuration {
        Configuration(
            recognitionLevelDescription: "accurate",
            languageHints: ["zh-Hans", "zh-Hant"],
            usesLanguageCorrection: false
        )
    }
}

```

## ScreenTranslator/Core/Services/OCR/OCRService.swift

```swift
import Foundation

struct PlaceholderOCRService: OCRServiceProtocol {
    let requestFactory: OCRRequestFactory

    func recognizeText(in input: ScreenshotInput) async throws -> [OCRTextObservation] {
        _ = requestFactory.makePlaceholderConfiguration()
        _ = input
        return []
    }
}

```

## ScreenTranslator/Core/Services/OCR/VisionOCRService.swift

```swift
import Foundation

struct VisionOCRService {
    let requestFactory: OCRRequestFactory

    init(requestFactory: OCRRequestFactory) {
        self.requestFactory = requestFactory
    }
}

```

## ScreenTranslator/Core/Services/Rendering/OverlayImageComposer.swift

```swift
import Foundation

struct OverlayImageComposer {
    func composePlaceholderImageData() -> Data? {
        nil
    }
}

```

## ScreenTranslator/Core/Services/Rendering/OverlayLayoutEngine.swift

```swift
import CoreGraphics
import Foundation

struct OverlayLayoutEngine {
    func proposedFrame(
        for block: TranslationBlock,
        in canvasSize: CGSize
    ) -> CGRect {
        guard canvasSize != .zero else {
            return block.targetFrame
        }

        return block.targetFrame
    }
}

```

## ScreenTranslator/Core/Services/Rendering/OverlayRenderer.swift

```swift
import Foundation

struct PlaceholderOverlayRenderer: OverlayRendererProtocol {
    let layoutEngine: OverlayLayoutEngine
    let textFitter: OverlayTextFitter
    let imageComposer: OverlayImageComposer

    func renderOverlay(
        for input: ScreenshotInput,
        translatedBlocks: [TranslationBlock],
        style: OverlayRenderStyle
    ) async throws -> OverlayRenderResult {
        _ = translatedBlocks.map { layoutEngine.proposedFrame(for: $0, in: input.size) }
        _ = translatedBlocks.map { textFitter.fit(text: $0.translatedText, style: style) }
        _ = imageComposer.composePlaceholderImageData()

        throw AppError.featureNotReady(
            "Overlay rendering will be implemented in Prompt 8."
        )
    }
}

```

## ScreenTranslator/Core/Services/Rendering/OverlayTextFitter.swift

```swift
import Foundation

struct OverlayTextFitter {
    struct FittedText: Equatable, Sendable {
        let text: String
        let fontSize: Double
        let lineLimit: Int?
    }

    func fit(
        text: String,
        style: OverlayRenderStyle
    ) -> FittedText {
        FittedText(
            text: text,
            fontSize: style.maximumFontSize,
            lineLimit: nil
        )
    }
}

```

## ScreenTranslator/Core/Services/Storage/HistoryStore.swift

```swift
import Foundation

final class HistoryStore: HistoryStoreProtocol {
    private var history: [OverlayRenderResult] = []

    func loadHistory() -> [OverlayRenderResult] {
        history
    }

    func save(_ result: OverlayRenderResult) {
        history.insert(result, at: 0)
    }

    func clear() {
        history.removeAll()
    }
}

```

## ScreenTranslator/Core/Services/Storage/SettingsStore.swift

```swift
import Foundation

final class SettingsStore: SettingsStoreProtocol {
    private var currentSettings = AppSettings.defaultValue

    func loadSettings() -> AppSettings {
        currentSettings
    }

    func saveSettings(_ settings: AppSettings) {
        currentSettings = settings
    }
}

```

## ScreenTranslator/Core/Services/Storage/TemporaryImageStore.swift

```swift
import Foundation

@MainActor
final class TemporaryImageStore {
    private(set) var latestInput: ScreenshotInput?

    func store(_ input: ScreenshotInput) {
        latestInput = input
    }

    func consumeLatestInput() -> ScreenshotInput? {
        let input = latestInput
        latestInput = nil
        return input
    }
}

```

## ScreenTranslator/Core/Services/Translation/OnDeviceTranslationService.swift

```swift
import Foundation

struct OnDeviceTranslationService {
    let languageManager: TranslationLanguageManager
    let batchBuilder: TranslationBatchBuilder
}

```

## ScreenTranslator/Core/Services/Translation/TranslationBatchBuilder.swift

```swift
import Foundation

struct TranslationBatchBuilder {
    func buildBatch(from blocks: [TextBlock]) -> [String] {
        blocks.map(\.sourceText)
    }
}

```

## ScreenTranslator/Core/Services/Translation/TranslationLanguageManager.swift

```swift
import Foundation

final class TranslationLanguageManager {
    enum ReadinessState: String, CaseIterable, Sendable {
        case unknown
        case needsPreparation
        case ready
    }

    func currentReadiness() -> ReadinessState {
        .needsPreparation
    }

    func preparationSummary() -> String {
        "Offline Chinese to Russian language preparation will be implemented in Prompt 11."
    }

    func prepareOfflineLanguageData() async throws {
        throw AppError.featureNotReady(
            "Offline language preparation is intentionally deferred."
        )
    }
}

```

## ScreenTranslator/Core/Services/Translation/TranslationService.swift

```swift
import Foundation

struct PlaceholderTranslationService: TranslationServiceProtocol {
    let languageManager: TranslationLanguageManager
    let batchBuilder: TranslationBatchBuilder

    func translate(blocks: [TextBlock]) async throws -> [TranslationBlock] {
        _ = batchBuilder.buildBatch(from: blocks)
        _ = languageManager.currentReadiness()

        throw AppError.featureNotReady(
            "On-device translation will be implemented in Prompt 6."
        )
    }
}

```

## ScreenTranslator/Features/Debug/DebugOverlayInspectorView.swift

```swift
import SwiftUI

struct DebugOverlayInspectorView: View {
    let result: OverlayRenderResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overlay Inspector")
                .font(.headline)

            ForEach(result.translatedBlocks) { block in
                VStack(alignment: .leading, spacing: 4) {
                    Text(block.translatedText)
                        .font(.subheadline.weight(.semibold))

                    Text("Source: \(block.sourceText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Target Frame: \(frameDescription(for: block.targetFrame))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.secondary.opacity(0.3))
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func frameDescription(for rect: CGRect) -> String {
        let x = Int(rect.origin.x)
        let y = Int(rect.origin.y)
        let width = Int(rect.size.width)
        let height = Int(rect.size.height)
        return "x:\(x) y:\(y) w:\(width) h:\(height)"
    }
}

```

## ScreenTranslator/Features/Debug/DebugView.swift

```swift
import SwiftUI

struct DebugView: View {
    let result: OverlayRenderResult
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Debug Scaffold")
                            .font(.title3.weight(.semibold))

                        Text("OCR, grouping, translation, and rendering inspection will be implemented in later prompts. This screen exists now so the module boundary and routing are in place.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    DebugOverlayInspectorView(result: result)
                }
                .padding(20)
            }
            .navigationTitle("Debug")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        coordinator.returnToProcessing()
                    }
                }
            }
        }
    }
}

```

## ScreenTranslator/Features/Errors/ErrorView.swift

```swift
import SwiftUI

struct ErrorView: View {
    @ObservedObject var viewModel: ErrorViewModel
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()

                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 44))
                    .foregroundStyle(.orange)

                VStack(spacing: 8) {
                    Text(viewModel.title)
                        .font(.title3.weight(.semibold))

                    Text(viewModel.message)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                }

                Button(viewModel.recoveryActionTitle) {
                    coordinator.returnToProcessing()
                }
                .buttonStyle(.borderedProminent)

                Spacer()
            }
            .padding(24)
            .navigationTitle("Error")
        }
    }
}

```

## ScreenTranslator/Features/Errors/ErrorViewModel.swift

```swift
import Foundation

@MainActor
final class ErrorViewModel: ObservableObject {
    let error: AppError
    let title: String
    let message: String
    let recoveryActionTitle: String

    init(error: AppError) {
        self.error = error
        self.title = "Something Needs Wiring"
        self.message = error.errorDescription ?? "Unknown placeholder error."
        self.recoveryActionTitle = "Back to Processing"
    }
}

```

## ScreenTranslator/Features/Processing/ProcessingOrchestrator.swift

```swift
import Foundation

final class ProcessingOrchestrator {
    private let screenshotNormalizer: ScreenshotNormalizer
    private let ocrService: any OCRServiceProtocol
    private let textGroupingService: any TextGroupingServiceProtocol
    private let translationService: any TranslationServiceProtocol
    private let overlayRenderer: any OverlayRendererProtocol

    init(
        screenshotNormalizer: ScreenshotNormalizer,
        ocrService: any OCRServiceProtocol,
        textGroupingService: any TextGroupingServiceProtocol,
        translationService: any TranslationServiceProtocol,
        overlayRenderer: any OverlayRendererProtocol
    ) {
        self.screenshotNormalizer = screenshotNormalizer
        self.ocrService = ocrService
        self.textGroupingService = textGroupingService
        self.translationService = translationService
        self.overlayRenderer = overlayRenderer
    }

    func process(_ job: ProcessingJob) async throws -> OverlayRenderResult {
        _ = screenshotNormalizer.normalize(job.input)
        _ = ocrService
        _ = textGroupingService
        _ = translationService
        _ = overlayRenderer

        throw AppError.featureNotReady(
            "The end-to-end processing pipeline will be implemented in Prompt 7."
        )
    }
}

```

## ScreenTranslator/Features/Processing/ProcessingView.swift

```swift
import SwiftUI

struct ProcessingView: View {
    @ObservedObject var viewModel: ProcessingViewModel
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                ProgressView()
                    .scaleEffect(1.25)

                VStack(spacing: 8) {
                    Text(viewModel.state.displayTitle)
                        .font(.title3.weight(.semibold))

                    Text(viewModel.statusMessage)
                        .font(.body)

                    Text(viewModel.detailMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                }

                VStack(spacing: 12) {
                    Button("Preview Placeholder Result") {
                        coordinator.showResult()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Preview Placeholder Error") {
                        coordinator.showError(
                            .featureNotReady(
                                "This placeholder error screen exists so the scaffold is easy to inspect."
                            )
                        )
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
            }
            .padding(24)
            .navigationTitle("ScreenTranslator")
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    Button("Debug") {
                        coordinator.showDebug()
                    }

                    Button("Settings") {
                        coordinator.showSettings()
                    }
                }
            }
        }
    }
}

```

## ScreenTranslator/Features/Processing/ProcessingViewModel.swift

```swift
import Foundation

@MainActor
final class ProcessingViewModel: ObservableObject {
    @Published private(set) var state: ProcessingState
    @Published private(set) var statusMessage: String
    @Published private(set) var detailMessage: String

    private let orchestrator: ProcessingOrchestrator

    init(orchestrator: ProcessingOrchestrator) {
        self.orchestrator = orchestrator
        self.state = .idle
        self.statusMessage = "Waiting for screenshot input."
        self.detailMessage = "Prompt 2 will connect App Intent screenshot handoff into this screen."
    }

    func resetToPlaceholderState() {
        _ = orchestrator
        state = .idle
        statusMessage = "Waiting for screenshot input."
        detailMessage = "This is a compile-safe scaffold with no OCR or translation logic yet."
    }
}

```

## ScreenTranslator/Features/ResultOverlay/OverlayBlockView.swift

```swift
import SwiftUI

struct OverlayBlockView: View {
    let block: TranslationBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(block.translatedText)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)

            Text(block.sourceText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(block.renderingStyle.padding)
        .background(
            RoundedRectangle(cornerRadius: block.renderingStyle.cornerRadius)
                .fill(Color.black.opacity(block.renderingStyle.backgroundOpacity))
        )
        .foregroundStyle(.white)
    }
}

```

## ScreenTranslator/Features/ResultOverlay/OverlayCanvasView.swift

```swift
import SwiftUI

struct OverlayCanvasView: View {
    let result: OverlayRenderResult
    let mode: ResultMode

    var body: some View {
        Group {
            switch mode {
            case .overlay:
                placeholderOverlayBody
            case .original:
                placeholderOriginalBody
            case .text:
                textModeBody
            case .mixed:
                mixedModeBody
            }
        }
    }

    private var placeholderOverlayBody: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.14, green: 0.15, blue: 0.18),
                            Color(red: 0.25, green: 0.28, blue: 0.32)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 12) {
                Text("Screenshot Preview Placeholder")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.85))

                ForEach(result.translatedBlocks) { block in
                    OverlayBlockView(block: block)
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 440)
    }

    private var placeholderOriginalBody: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(Color.secondary.opacity(0.18))
            .overlay {
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)

                    Text("Original screenshot preview will appear here.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 440)
    }

    private var textModeBody: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(result.translatedBlocks) { block in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(block.translatedText)
                            .font(.headline)

                        Text(block.sourceText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.secondary.opacity(0.12))
                    )
                }
            }
        }
    }

    private var mixedModeBody: some View {
        VStack(spacing: 16) {
            placeholderOriginalBody
            textModeBody
        }
    }
}

```

## ScreenTranslator/Features/ResultOverlay/ResultMode.swift

```swift
import Foundation

enum ResultMode: String, CaseIterable, Identifiable, Sendable {
    case overlay
    case original
    case text
    case mixed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overlay:
            return "Overlay"
        case .original:
            return "Original"
        case .text:
            return "Text"
        case .mixed:
            return "Mixed"
        }
    }
}

```

## ScreenTranslator/Features/ResultOverlay/ResultOverlayView.swift

```swift
import SwiftUI

struct ResultOverlayView: View {
    @ObservedObject var viewModel: ResultOverlayViewModel
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Picker("Mode", selection: $viewModel.displayMode) {
                    ForEach(ResultMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                OverlayCanvasView(
                    result: viewModel.result,
                    mode: viewModel.displayMode
                )

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Source Size: \(viewModel.sourceSizeDescription)")
                        Text("\(viewModel.translatedBlocks.count) placeholder block(s)")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                    Spacer()
                }

                Button("Done") {
                    coordinator.returnToProcessing()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(20)
            .navigationTitle("Overlay Result")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Settings") {
                        coordinator.showSettings()
                    }
                }
            }
        }
    }
}

```

## ScreenTranslator/Features/ResultOverlay/ResultOverlayViewModel.swift

```swift
import Foundation

@MainActor
final class ResultOverlayViewModel: ObservableObject {
    @Published var displayMode: ResultMode
    @Published private(set) var result: OverlayRenderResult

    init(
        result: OverlayRenderResult,
        displayMode: ResultMode = .overlay
    ) {
        self.result = result
        self.displayMode = displayMode
    }

    var translatedBlocks: [TranslationBlock] {
        result.translatedBlocks
    }

    var sourceSizeDescription: String {
        let width = Int(result.sourceInput.size.width)
        let height = Int(result.sourceInput.size.height)
        return "\(width)x\(height)"
    }

    var isPlaceholderContent: Bool {
        result.renderMetadata.note.contains("Placeholder")
    }
}

```

## ScreenTranslator/Features/Settings/LanguagePreparationView.swift

```swift
import SwiftUI

struct LanguagePreparationView: View {
    let readiness: TranslationLanguageManager.ReadinessState
    let summary: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Offline Language Preparation")
                .font(.headline)

            Text("Status: \(readiness.rawValue)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(summary)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.secondary.opacity(0.12))
        )
    }
}

```

## ScreenTranslator/Features/Settings/SettingsView.swift

```swift
import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        NavigationStack {
            Form {
                Section("Display") {
                    Picker(
                        "Preferred Mode",
                        selection: preferredDisplayModeBinding
                    ) {
                        ForEach(ResultMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Background Opacity")
                        Slider(
                            value: backgroundOpacityBinding,
                            in: 0.2...1.0
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Maximum Font Size")
                        Slider(
                            value: maximumFontSizeBinding,
                            in: 14...28
                        )
                    }
                }

                Section("Behavior") {
                    Toggle("Enable History", isOn: historyEnabledBinding)
                    Toggle("Show Debug Options", isOn: debugOptionsBinding)
                }

                Section("Offline Readiness") {
                    LanguagePreparationView(
                        readiness: viewModel.languageReadiness,
                        summary: viewModel.languageSummary
                    )
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        coordinator.returnToProcessing()
                    }
                }
            }
        }
    }

    private var preferredDisplayModeBinding: Binding<ResultMode> {
        Binding(
            get: {
                ResultMode(rawValue: viewModel.settings.preferredDisplayModeRawValue) ?? .overlay
            },
            set: { viewModel.updatePreferredDisplayMode($0) }
        )
    }

    private var backgroundOpacityBinding: Binding<Double> {
        Binding(
            get: { viewModel.settings.overlayStyle.backgroundOpacity },
            set: { viewModel.updateBackgroundOpacity($0) }
        )
    }

    private var maximumFontSizeBinding: Binding<Double> {
        Binding(
            get: { viewModel.settings.overlayStyle.maximumFontSize },
            set: { viewModel.updateMaximumFontSize($0) }
        )
    }

    private var historyEnabledBinding: Binding<Bool> {
        Binding(
            get: { viewModel.settings.historyEnabled },
            set: { viewModel.updateHistoryEnabled($0) }
        )
    }

    private var debugOptionsBinding: Binding<Bool> {
        Binding(
            get: { viewModel.settings.debugOptionsEnabled },
            set: { viewModel.updateDebugOptionsEnabled($0) }
        )
    }
}

```

## ScreenTranslator/Features/Settings/SettingsViewModel.swift

```swift
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var settings: AppSettings
    @Published private(set) var languageReadiness: TranslationLanguageManager.ReadinessState
    @Published private(set) var languageSummary: String

    private let settingsStore: any SettingsStoreProtocol
    private let languageManager: TranslationLanguageManager

    init(
        settingsStore: any SettingsStoreProtocol,
        languageManager: TranslationLanguageManager
    ) {
        self.settingsStore = settingsStore
        self.languageManager = languageManager
        self.settings = settingsStore.loadSettings()
        self.languageReadiness = languageManager.currentReadiness()
        self.languageSummary = languageManager.preparationSummary()
    }

    func updateBackgroundOpacity(_ value: Double) {
        settings.overlayStyle.backgroundOpacity = value
        persist()
    }

    func updateMaximumFontSize(_ value: Double) {
        settings.overlayStyle.maximumFontSize = value
        persist()
    }

    func updateHistoryEnabled(_ enabled: Bool) {
        settings.historyEnabled = enabled
        persist()
    }

    func updateDebugOptionsEnabled(_ enabled: Bool) {
        settings.debugOptionsEnabled = enabled
        persist()
    }

    func updatePreferredDisplayMode(_ mode: ResultMode) {
        settings.preferredDisplayModeRawValue = mode.rawValue
        persist()
    }

    private func persist() {
        settingsStore.saveSettings(settings)
    }
}

```

## ScreenTranslator/Intents/AppShortcutsProvider.swift

```swift
import AppIntents

struct ScreenTranslatorShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TranslateScreenshotIntent(),
            phrases: [
                "Translate screenshot with \(.applicationName)",
                "Start \(.applicationName) translation"
            ],
            shortTitle: "Translate Screenshot",
            systemImageName: "text.viewfinder"
        )
    }
}

```

## ScreenTranslator/Intents/IntentInputDecoder.swift

```swift
import CoreGraphics
import Foundation

struct IntentInputDecoder {
    func decodePlaceholderInput(imageData: Data) -> ScreenshotInput {
        ScreenshotInput(
            imageData: imageData,
            size: CGSize(width: 0, height: 0),
            orientation: .up,
            sourceMetadata: .init(
                sourceName: "AppIntent",
                automationName: "Placeholder"
            )
        )
    }
}

```

## ScreenTranslator/Intents/IntentResultRouter.swift

```swift
import Foundation

struct IntentResultRouter {
    func routeForIncomingScreenshot() -> AppRoute {
        .processing
    }
}

```

## ScreenTranslator/Intents/TranslateScreenshotIntent.swift

```swift
import AppIntents

struct TranslateScreenshotIntent: AppIntent {
    static var title: LocalizedStringResource = "Translate Screenshot"
    static var description = IntentDescription(
        "Placeholder App Intent for future screenshot handoff into ScreenTranslator."
    )
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        .result(
            dialog: IntentDialog(
                "Screenshot handoff will be implemented in the next prompt."
            )
        )
    }
}

```

## ScreenTranslator/Resources/Assets.xcassets/AccentColor.colorset/Contents.json

```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.698",
          "green" : "0.431",
          "red" : "0.145"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}

```

## ScreenTranslator/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json

```json
{
  "images" : [
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}

```

## ScreenTranslator/Resources/Assets.xcassets/Contents.json

```json
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}

```

## ScreenTranslator/Resources/Preview Content/Preview Assets.xcassets/Contents.json

```json
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}

```

## ScreenTranslator/ScreenTranslatorApp.swift

```swift
import SwiftUI

@main
struct ScreenTranslatorApp: App {
    @StateObject private var environment = AppEnvironment.bootstrap()

    var body: some Scene {
        WindowGroup {
            ScreenTranslatorRootView()
                .environmentObject(environment)
                .environmentObject(environment.coordinator)
        }
    }
}

private struct ScreenTranslatorRootView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        switch coordinator.route {
        case .idle, .processing:
            ProcessingView(viewModel: environment.processingViewModel)
        case .result:
            ResultOverlayView(
                viewModel: environment.container.makeResultOverlayViewModel(
                    result: coordinator.latestResult
                )
            )
        case .error:
            ErrorView(
                viewModel: environment.container.makeErrorViewModel(
                    error: coordinator.activeError
                )
            )
        case .settings:
            SettingsView(viewModel: environment.settingsViewModel)
        case .debug:
            DebugView(result: coordinator.latestResult)
        }
    }
}

```

## ScreenTranslator/SupportingFiles/Info.plist

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleDisplayName</key>
    <string>ScreenTranslator</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>ScreenTranslator</string>
    <key>CFBundlePackageType</key>
    <string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>UIApplicationSceneManifest</key>
    <dict>
        <key>UIApplicationSupportsMultipleScenes</key>
        <false/>
    </dict>
</dict>
</plist>

```

## ScreenTranslator/SupportingFiles/ScreenTranslator.entitlements

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
</dict>
</plist>

```

## ScreenTranslator/Tests/Integration/ScreenTranslatorIntegrationPlaceholderTests.swift

```swift
import Foundation

struct ScreenTranslatorIntegrationPlaceholderTestsPlaceholder {
    let note = "Real integration tests will be added in Prompt 13."
}

```

## ScreenTranslator/Tests/Unit/ScreenTranslatorScaffoldTests.swift

```swift
import Foundation

struct ScreenTranslatorScaffoldTestsPlaceholder {
    let note = "Real unit tests will be added in Prompt 13."
}

```

