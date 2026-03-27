import Foundation

struct AppServices {
    struct RoutingServices {
        let intentResultRouter: IntentResultRouter
    }

    struct InputServices {
        let screenshotInputBuilder: ScreenshotInputBuilder
        let imageOrientationResolver: ImageOrientationResolver
        let screenshotNormalizer: ScreenshotNormalizer
    }

    struct OCRServices {
        let requestFactory: OCRRequestFactory
        let service: any OCRServiceProtocol
    }

    struct GroupingServices {
        let boundingBoxGrouper: BoundingBoxGrouper
        let textBlockComposer: TextBlockComposer
        let service: any TextGroupingServiceProtocol
    }

    struct TranslationServices {
        let languageManager: TranslationLanguageManager
        let batchBuilder: TranslationBatchBuilder
        let service: any TranslationServiceProtocol
        let sessionBroker: TranslationSessionBroker
    }

    struct RenderingServices {
        let layoutEngine: OverlayLayoutEngine
        let textFitter: OverlayTextFitter
        let imageComposer: OverlayImageComposer
        let renderer: any OverlayRendererProtocol
    }

    struct StorageServices {
        let historyStore: any HistoryStoreProtocol
        let temporaryImageStore: TemporaryImageStore
        let settingsStore: any SettingsStoreProtocol
    }

    let routing: RoutingServices
    let input: InputServices
    let ocr: OCRServices
    let grouping: GroupingServices
    let translation: TranslationServices
    let rendering: RenderingServices
    let storage: StorageServices
    let processingOrchestrator: ProcessingOrchestrator

    @MainActor
    static func live() -> AppServices {
        let routing = RoutingServices(
            intentResultRouter: IntentResultRouter()
        )

        let imageOrientationResolver = ImageOrientationResolver()
        let input = InputServices(
            screenshotInputBuilder: ScreenshotInputBuilder(),
            imageOrientationResolver: imageOrientationResolver,
            screenshotNormalizer: ScreenshotNormalizer(
                orientationResolver: imageOrientationResolver
            )
        )

        let requestFactory = OCRRequestFactory()
        let ocr = OCRServices(
            requestFactory: requestFactory,
            service: VisionOCRService(requestFactory: requestFactory)
        )

        let boundingBoxGrouper = BoundingBoxGrouper()
        let textBlockComposer = TextBlockComposer()
        let grouping = GroupingServices(
            boundingBoxGrouper: boundingBoxGrouper,
            textBlockComposer: textBlockComposer,
            service: TextGroupingService(
                grouper: boundingBoxGrouper,
                composer: textBlockComposer
            )
        )

        let translationSessionBroker = TranslationSessionBroker()
        let translationLanguageManager = TranslationLanguageManager(
            sessionBroker: translationSessionBroker
        )
        let translationBatchBuilder = TranslationBatchBuilder()
        let translation = TranslationServices(
            languageManager: translationLanguageManager,
            batchBuilder: translationBatchBuilder,
            service: OnDeviceTranslationService(
                languageManager: translationLanguageManager,
                batchBuilder: translationBatchBuilder,
                sessionBroker: translationSessionBroker
            ),
            sessionBroker: translationSessionBroker
        )

        let overlayLayoutEngine = OverlayLayoutEngine()
        let overlayTextFitter = OverlayTextFitter()
        let overlayImageComposer = OverlayImageComposer()
        let rendering = RenderingServices(
            layoutEngine: overlayLayoutEngine,
            textFitter: overlayTextFitter,
            imageComposer: overlayImageComposer,
            renderer: OverlayRenderer(
                layoutEngine: overlayLayoutEngine,
                textFitter: overlayTextFitter,
                imageComposer: overlayImageComposer
            )
        )

        let storage = StorageServices(
            historyStore: HistoryStore(),
            temporaryImageStore: TemporaryImageStore(),
            settingsStore: SettingsStore()
        )

        let processingOrchestrator = ProcessingOrchestrator(
            screenshotNormalizer: input.screenshotNormalizer,
            ocrService: ocr.service,
            textGroupingService: grouping.service,
            translationService: translation.service,
            overlayRenderer: rendering.renderer,
            settingsStore: storage.settingsStore
        )

        return AppServices(
            routing: routing,
            input: input,
            ocr: ocr,
            grouping: grouping,
            translation: translation,
            rendering: rendering,
            storage: storage,
            processingOrchestrator: processingOrchestrator
        )
    }
}
