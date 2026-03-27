import Foundation

@MainActor
final class AppContainer {
    let services: AppServices

    init() {
        self.services = .live()
    }

    init(services: AppServices) {
        self.services = services
    }

    var intentResultRouter: IntentResultRouter {
        services.routing.intentResultRouter
    }

    var screenshotInputBuilder: ScreenshotInputBuilder {
        services.input.screenshotInputBuilder
    }

    var imageOrientationResolver: ImageOrientationResolver {
        services.input.imageOrientationResolver
    }

    var screenshotNormalizer: ScreenshotNormalizer {
        services.input.screenshotNormalizer
    }

    var ocrRequestFactory: OCRRequestFactory {
        services.ocr.requestFactory
    }

    var ocrService: any OCRServiceProtocol {
        services.ocr.service
    }

    var boundingBoxGrouper: BoundingBoxGrouper {
        services.grouping.boundingBoxGrouper
    }

    var textBlockComposer: TextBlockComposer {
        services.grouping.textBlockComposer
    }

    var textGroupingService: any TextGroupingServiceProtocol {
        services.grouping.service
    }

    var translationLanguageManager: TranslationLanguageManager {
        services.translation.languageManager
    }

    var translationBatchBuilder: TranslationBatchBuilder {
        services.translation.batchBuilder
    }

    var translationService: any TranslationServiceProtocol {
        services.translation.service
    }

    var translationSessionBroker: TranslationSessionBroker {
        services.translation.sessionBroker
    }

    var overlayLayoutEngine: OverlayLayoutEngine {
        services.rendering.layoutEngine
    }

    var overlayTextFitter: OverlayTextFitter {
        services.rendering.textFitter
    }

    var overlayImageComposer: OverlayImageComposer {
        services.rendering.imageComposer
    }

    var overlayRenderer: any OverlayRendererProtocol {
        services.rendering.renderer
    }

    var historyStore: any HistoryStoreProtocol {
        services.storage.historyStore
    }

    var temporaryImageStore: TemporaryImageStore {
        services.storage.temporaryImageStore
    }

    var settingsStore: any SettingsStoreProtocol {
        services.storage.settingsStore
    }

    var processingOrchestrator: ProcessingOrchestrator {
        services.processingOrchestrator
    }

    func makeProcessingViewModel() -> ProcessingViewModel {
        ProcessingViewModel(orchestrator: processingOrchestrator)
    }

    func makeResultOverlayViewModel(
        result: OverlayRenderResult = .placeholder()
    ) -> ResultOverlayViewModel {
        return ResultOverlayViewModel(
            result: result,
            displayMode: .overlay
        )
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

    func makeDebugViewModel(
        result: OverlayRenderResult,
        activeJob: ProcessingJob?
    ) -> DebugViewModel {
        DebugViewModel(
            result: result,
            activeJob: activeJob,
            pipelineInspector: DebugPipelineInspector(
                screenshotNormalizer: screenshotNormalizer,
                ocrService: ocrService,
                textGroupingService: textGroupingService,
                translationService: translationService
            )
        )
    }
}
