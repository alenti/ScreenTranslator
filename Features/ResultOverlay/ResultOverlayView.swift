import SwiftUI
import UIKit

struct ResultOverlayView: View {
    @Environment(\.colorScheme) private var colorScheme

    @ObservedObject var viewModel: ResultOverlayViewModel
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var environment: AppEnvironment

    @State private var chromeHidden = false
    @State private var viewerResetToken = 0
    @State private var selectedBlock: TranslationBlock?
    @State private var activityPayload: ResultActivityPayload?
    @State private var showingTranscriptSheet = false
    @State private var toast: ResultToast?
    @State private var toastTask: Task<Void, Never>?
    @State private var imageSaveCoordinator: ResultImageSaveCoordinator?

    var body: some View {
        GeometryReader { proxy in
            let topInset = max(proxy.safeAreaInsets.top, 0)
            let bottomInset = max(proxy.safeAreaInsets.bottom, 0)

            ZStack {
                screenBackgroundColor.ignoresSafeArea()

                OverlayCanvasView(
                    result: viewModel.result,
                    mode: viewModel.displayMode,
                    chromeHidden: chromeHidden,
                    selectedBlockID: selectedBlock?.id,
                    resetToken: viewerResetToken,
                    onViewerTap: toggleChrome,
                    onBlockTap: presentBlockDetail(_:)
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .top) {
                if chromeHidden == false {
                    topChrome(topInset: topInset)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        .zIndex(2)
                }
            }
            .overlay(alignment: .bottom) {
                if chromeHidden == false {
                    bottomChrome(bottomInset: bottomInset)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        .zIndex(2)
                }
            }
            .overlay(alignment: .bottom) {
                if let toast {
                    toastOverlay(
                        toast: toast,
                        bottomInset: bottomInset
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(3)
                }
            }
        }
        .statusBarHidden(chromeHidden)
        .persistentSystemOverlays(chromeHidden ? .hidden : .visible)
        .task {
            viewModel.ensureHeroMode()
        }
        .onDisappear {
            toastTask?.cancel()
        }
        .sheet(item: $selectedBlock) { block in
            ResultBlockDetailSheet(
                block: block,
                translationText: viewModel.translationText(for: block),
                originalText: viewModel.originalText(for: block),
                onCopyTranslation: {
                    copyText(
                        viewModel.translationText(for: block),
                        toast: "Russian copied"
                    )
                },
                onCopyOriginal: {
                    copyText(
                        viewModel.originalText(for: block),
                        toast: "Original copied"
                    )
                },
                onCopyBoth: {
                    copyText(
                        viewModel.combinedText(for: block),
                        toast: "Block copied"
                    )
                }
            )
            .presentationDetents([.height(340), .medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
        }
        .sheet(item: $activityPayload) { payload in
            ResultActivityView(items: payload.items)
        }
        .sheet(isPresented: $showingTranscriptSheet) {
            ResultTranscriptSheet(
                blocks: viewModel.translatedBlocks,
                renderNote: viewModel.renderNote,
                sourceSizeDescription: viewModel.sourceSizeDescription,
                onCopyTranslation: {
                    copyText(viewModel.translationText, toast: "Russian copied")
                },
                onCopyOriginal: {
                    copyText(viewModel.originalText, toast: "Original copied")
                },
                onCopyBoth: {
                    copyText(viewModel.combinedText, toast: "Transcript copied")
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.thinMaterial)
        }
    }

    private func topChrome(topInset: CGFloat) -> some View {
        topBar
            .padding(.horizontal, 18)
            .padding(.top, topInset + 8)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity)
            .animation(.spring(response: 0.34, dampingFraction: 0.88), value: chromeHidden)
    }

    private func bottomChrome(bottomInset: CGFloat) -> some View {
        VStack(spacing: 12) {
            if viewModel.translatedBlocks.isEmpty == false {
                hintPill(
                    text: "Tap a block for details"
                )
            }

            modeSwitcher
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, max(bottomInset, 12) + 8)
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: chromeHidden)
    }

    private func toastOverlay(
        toast: ResultToast,
        bottomInset: CGFloat
    ) -> some View {
        ResultToastView(toast: toast)
            .padding(.bottom, max(bottomInset, 12) + (chromeHidden ? 24 : 106))
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            glassIconButton(
                systemName: "chevron.left",
                accessibilityLabel: "Back",
                action: dismissResult
            )

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                glassIconButton(
                    systemName: "arrow.up.left.and.arrow.down.right",
                    accessibilityLabel: "Fit to screen",
                    action: resetViewerToFit
                )

                Menu {
                    Section("Copy") {
                        Button("Copy Russian", systemImage: "doc.on.doc") {
                            copyText(viewModel.translationText, toast: "Russian copied")
                        }

                        Button("Copy Original", systemImage: "doc.on.doc") {
                            copyText(viewModel.originalText, toast: "Original copied")
                        }

                        Button("Copy Both", systemImage: "doc.on.doc.fill") {
                            copyText(viewModel.combinedText, toast: "Copied")
                        }
                    }

                    Section("Actions") {
                        Button("Share Translated Screenshot", systemImage: "square.and.arrow.up") {
                            shareRenderedResult()
                        }

                        Button("Save Translated Screenshot", systemImage: "arrow.down.to.line") {
                            saveRenderedResult()
                        }

                        Button("Open Text List", systemImage: "doc.text") {
                            showingTranscriptSheet = true
                            impactFeedback(.soft)
                        }

                        Button("Reset to Fit", systemImage: "arrow.up.left.and.arrow.down.right") {
                            resetViewerToFit()
                        }
                    }

                    if canRerunTranslation {
                        Section("Workflow") {
                            Button("Re-run Translation", systemImage: "arrow.clockwise") {
                                rerunTranslation()
                            }
                        }
                    }
                } label: {
                    GlassChromeButton(
                        systemName: "ellipsis.circle",
                        style: .circle
                    )
                }
            }
        }
    }

    private var modeSwitcher: some View {
        HStack(spacing: 6) {
            ForEach(viewModel.primaryModes) { mode in
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                        viewModel.displayMode = mode
                        selectedBlock = nil
                    }
                    impactFeedback(.light)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: mode.systemImageName)
                            .font(.system(size: 13, weight: .semibold))

                        Text(mode.title)
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(
                        viewModel.displayMode == mode
                            ? activeModeTextColor
                            : inactiveModeTextColor
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(
                                viewModel.displayMode == mode
                                    ? activeModeFillColor
                                    : Color.clear
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
        )
        .overlay(
            Capsule()
                .strokeBorder(glassStrokeColor)
        )
        .shadow(color: glassShadowColor, radius: 18, y: 10)
    }

    private func hintPill(text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(inactiveModeTextColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                Capsule()
                    .strokeBorder(glassStrokeColor.opacity(0.72))
            )
            .shadow(color: glassShadowColor.opacity(0.88), radius: 12, y: 8)
    }

    private var canRerunTranslation: Bool {
        environment.processingViewModel.activeJob != nil || coordinator.activeJob != nil
    }

    private func dismissResult() {
        environment.processingViewModel.resetToPlaceholderState()
        coordinator.showProcessing(job: nil)
        impactFeedback(.medium)
    }

    private func resetViewerToFit() {
        viewerResetToken += 1
        impactFeedback(.soft)
    }

    private func toggleChrome() {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
            chromeHidden.toggle()
        }
    }

    private func presentBlockDetail(_ block: TranslationBlock) {
        selectedBlock = block
        chromeHidden = false
        impactFeedback(.light)
    }

    private func rerunTranslation() {
        let job = environment.processingViewModel.activeJob ?? coordinator.activeJob
        guard let job else {
            showToast("No screenshot to re-run", symbol: "exclamationmark.circle")
            warningFeedback()
            return
        }

        if environment.processingViewModel.activeJob != nil {
            environment.processingViewModel.retryCurrentJob()
        } else {
            environment.processingViewModel.handleIncomingScreenshot(job)
        }

        coordinator.showProcessing(job: job)
        impactFeedback(.medium)
    }

    private func shareRenderedResult() {
        guard let image = renderedUIImage ?? sourceUIImage else {
            showToast("Nothing to share", symbol: "exclamationmark.circle")
            warningFeedback()
            return
        }

        activityPayload = ResultActivityPayload(items: [image])
        impactFeedback(.soft)
    }

    private func saveRenderedResult() {
        guard let image = renderedUIImage ?? sourceUIImage else {
            showToast("Nothing to save", symbol: "exclamationmark.circle")
            warningFeedback()
            return
        }

        let coordinator = ResultImageSaveCoordinator { error in
            if let error {
                showToast(
                    error.localizedDescription,
                    symbol: "exclamationmark.circle"
                )
                warningFeedback()
            } else {
                showToast("Saved to Photos", symbol: "checkmark.circle.fill")
                successFeedback()
            }

            imageSaveCoordinator = nil
        }

        imageSaveCoordinator = coordinator
        UIImageWriteToSavedPhotosAlbum(
            image,
            coordinator,
            #selector(ResultImageSaveCoordinator.image(_:didFinishSavingWithError:contextInfo:)),
            nil
        )
    }

    private func copyText(
        _ text: String,
        toast: String
    ) {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedText.isEmpty == false else {
            showToast("Nothing to copy", symbol: "exclamationmark.circle")
            warningFeedback()
            return
        }

        UIPasteboard.general.string = normalizedText
        showToast(toast, symbol: "doc.on.doc.fill")
        successFeedback()
    }

    private func showToast(
        _ message: String,
        symbol: String
    ) {
        toastTask?.cancel()

        withAnimation(.spring(response: 0.30, dampingFraction: 0.90)) {
            toast = ResultToast(
                message: message,
                systemImage: symbol
            )
        }

        toastTask = Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)

            guard Task.isCancelled == false else {
                return
            }

            await MainActor.run {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.92)) {
                    toast = nil
                }
            }
        }
    }

    private var renderedUIImage: UIImage? {
        guard let data = viewModel.renderedPreviewData else {
            return nil
        }

        return UIImage(data: data)
    }

    private var sourceUIImage: UIImage? {
        guard let data = viewModel.sourcePreviewData else {
            return nil
        }

        return UIImage(data: data)
    }

    private var screenBackgroundColor: Color {
        colorScheme == .dark
            ? .black
            : Color(red: 0.95, green: 0.96, blue: 0.98)
    }

    private var activeModeFillColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.95)
            : Color.black.opacity(0.86)
    }

    private var activeModeTextColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.82)
            : .white
    }

    private var inactiveModeTextColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.92)
            : Color.primary.opacity(0.86)
    }

    private var glassStrokeColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.14)
            : Color.black.opacity(0.08)
    }

    private var glassShadowColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.18)
            : Color.black.opacity(0.10)
    }

    private func glassIconButton(
        systemName: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            GlassChromeButton(
                systemName: systemName,
                style: .circle
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private func impactFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    private func successFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    private func warningFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }
}

private struct GlassChromeButton: View {
    @Environment(\.colorScheme) private var colorScheme

    enum Style {
        case circle
        case capsule
    }

    let systemName: String
    let style: Style

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(iconColor)
            .frame(
                width: style == .circle ? 44 : nil,
                height: 44
            )
            .padding(.horizontal, style == .capsule ? 14 : 0)
            .background(
                Group {
                    switch style {
                    case .circle:
                        Circle()
                            .fill(.ultraThinMaterial)
                    case .capsule:
                        Capsule()
                            .fill(.ultraThinMaterial)
                    }
                }
            )
            .overlay(
                Group {
                    switch style {
                    case .circle:
                        Circle()
                            .strokeBorder(strokeColor)
                    case .capsule:
                        Capsule()
                            .strokeBorder(strokeColor)
                    }
                }
            )
            .shadow(color: shadowColor, radius: 16, y: 10)
    }

    private var iconColor: Color {
        colorScheme == .dark
            ? .white
            : Color.primary.opacity(0.92)
    }

    private var strokeColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.14)
            : Color.black.opacity(0.08)
    }

    private var shadowColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.18)
            : Color.black.opacity(0.10)
    }
}

private struct ResultToast: Equatable {
    let message: String
    let systemImage: String
}

private struct ResultToastView: View {
    @Environment(\.colorScheme) private var colorScheme

    let toast: ResultToast

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.systemImage)
                .font(.system(size: 14, weight: .bold))

            Text(toast.message)
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(colorScheme == .dark ? Color.white : Color.primary.opacity(0.92))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    colorScheme == .dark
                        ? Color.white.opacity(0.14)
                        : Color.black.opacity(0.08)
                )
        )
        .shadow(
            color: colorScheme == .dark
                ? Color.black.opacity(0.20)
                : Color.black.opacity(0.10),
            radius: 18,
            y: 10
        )
    }
}

private struct ResultActivityPayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

private struct ResultActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}
}

private final class ResultImageSaveCoordinator: NSObject {
    private let completion: (Error?) -> Void

    init(completion: @escaping (Error?) -> Void) {
        self.completion = completion
    }

    @objc
    func image(
        _ image: UIImage,
        didFinishSavingWithError error: Error?,
        contextInfo: UnsafeMutableRawPointer?
    ) {
        _ = image
        _ = contextInfo
        completion(error)
    }
}

private struct ResultBlockDetailSheet: View {
    @Environment(\.colorScheme) private var colorScheme

    let block: TranslationBlock
    let translationText: String
    let originalText: String
    let onCopyTranslation: () -> Void
    let onCopyOriginal: () -> Void
    let onCopyBoth: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Capsule()
                    .fill(handleColor)
                    .frame(width: 40, height: 5)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Block Detail")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(primaryTextColor)

                    Text(frameDescription(for: block.targetFrame))
                        .font(.caption)
                        .foregroundStyle(secondaryTextColor)
                }

                detailCard(
                    title: "Russian Translation",
                    text: translationText
                )

                detailCard(
                    title: "Original Text",
                    text: originalText
                )

                VStack(spacing: 10) {
                    sheetActionButton(
                        title: "Copy Russian",
                        systemImage: "doc.on.doc",
                        action: onCopyTranslation
                    )

                    sheetActionButton(
                        title: "Copy Original",
                        systemImage: "doc.on.doc",
                        action: onCopyOriginal
                    )

                    sheetActionButton(
                        title: "Copy Both",
                        systemImage: "doc.on.doc.fill",
                        action: onCopyBoth
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(Color.clear)
    }

    private func detailCard(
        title: String,
        text: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(secondaryTextColor)

            Text(text.isEmpty ? "Unavailable" : text)
                .font(.body.weight(.semibold))
                .foregroundStyle(primaryTextColor)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(cardStroke)
        )
    }

    private func sheetActionButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                Text(title)
                Spacer(minLength: 0)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(primaryTextColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(cardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(cardStroke)
            )
        }
        .buttonStyle(.plain)
    }

    private func frameDescription(for rect: CGRect) -> String {
        let x = Int(rect.origin.x.rounded())
        let y = Int(rect.origin.y.rounded())
        let width = Int(rect.size.width.rounded())
        let height = Int(rect.size.height.rounded())
        return "x:\(x) y:\(y) w:\(width) h:\(height)"
    }

    private var primaryTextColor: Color {
        colorScheme == .dark
            ? .white
            : Color.primary
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark
            ? .white.opacity(0.54)
            : Color.secondary
    }

    private var cardFill: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.06)
            : Color.black.opacity(0.05)
    }

    private var cardStroke: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.08)
    }

    private var handleColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.16)
            : Color.black.opacity(0.12)
    }
}

private struct ResultTranscriptSheet: View {
    let blocks: [TranslationBlock]
    let renderNote: String
    let sourceSizeDescription: String
    let onCopyTranslation: () -> Void
    let onCopyOriginal: () -> Void
    let onCopyBoth: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        transcriptBadge(text: "\(blocks.count) blocks")
                        transcriptBadge(text: sourceSizeDescription)
                    }

                    Text(renderNote)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    ForEach(blocks) { block in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(block.translatedText)
                                .font(.headline)
                                .foregroundStyle(.primary)

                            if block.sourceText.isEmpty == false {
                                Text(block.sourceText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.primary.opacity(0.05))
                        )
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 20)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Text List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Copy Russian", systemImage: "doc.on.doc") {
                            onCopyTranslation()
                        }

                        Button("Copy Original", systemImage: "doc.on.doc") {
                            onCopyOriginal()
                        }

                        Button("Copy Both", systemImage: "doc.on.doc.fill") {
                            onCopyBoth()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    private func transcriptBadge(text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(Color.primary.opacity(0.06))
            )
    }
}
