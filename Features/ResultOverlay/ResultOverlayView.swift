import SwiftUI
import UIKit

struct ResultOverlayView: View {
    @ObservedObject var viewModel: ResultOverlayViewModel
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("viewerHintShown") private var hintShown = false

    @State private var chromeHidden = false
    @State private var showingHint = false
    @State private var viewerResetToken = 0
    @State private var selectedBlock: ProcessedBlock?
    @State private var showingAllText = false
    @State private var toast: ResultToast?
    @State private var toastTask: Task<Void, Never>?
    @State private var imageSaveCoordinator: ResultImageSaveCoordinator?

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            ZoomablePreviewImage(
                image: viewModel.displayMode == .original ? viewModel.result.originalImage : viewModel.result.renderedImage,
                canvasSize: viewModel.sourceCanvasSize,
                resetToken: viewerResetToken,
                chromeHidden: chromeHidden,
                hotspots: viewModel.hotspots(in: viewModel.displayMode),
                highlightedHotspotID: selectedBlock?.hotspotID,
                onSingleTap: toggleChrome,
                onHotspotTap: { hotspot in
                    if let block = viewModel.blocks.first(where: { $0.hotspotID == hotspot.id }) { presentBlockDetail(block) }
                }
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                if !chromeHidden {
                    topBar.transition(.opacity)
                }
                Spacer(minLength: 0)
                if let toast {
                    ResultToastView(toast: toast)
                        .padding(.bottom, 12)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                if !chromeHidden {
                    bottomBar.transition(.opacity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .statusBarHidden(chromeHidden)
        .persistentSystemOverlays(chromeHidden ? .hidden : .automatic)
        .task {
            guard !hintShown, !viewModel.blocks.isEmpty else { return }
            showingHint = true
            try? await Task.sleep(for: .seconds(4))
            withAnimation { showingHint = false }
            hintShown = true
        }
        .onDisappear { toastTask?.cancel() }
        .sheet(item: $selectedBlock) { block in
            ResultBlockDetailSheet(
                targetTitle: viewModel.result.targetLanguage.localizedTitle,
                translation: viewModel.translationText(for: block),
                original: viewModel.originalText(for: block),
                note: viewModel.note(for: block),
                onCopy: { text, message in copyText(text, toast: message) }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingAllText) {
            ResultTranscriptSheet(viewModel: viewModel) { text, message in copyText(text, toast: message) }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button(action: environment.closeTranslation) {
                ChromeIcon(systemName: "xmark")
            }
            .accessibilityLabel(Text("Close"))
            .accessibilityIdentifier("viewer.close")

            Spacer(minLength: 0)

            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    ShareLink(item: Image(uiImage: viewModel.result.renderedImage),
                              preview: SharePreview(Text("Translated Screenshot"), image: Image(uiImage: viewModel.result.renderedImage))) {
                        ChromeIcon(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel(Text("Share"))

                    Menu {
                        Button("Save to Photos", systemImage: "square.and.arrow.down") { saveRenderedResult() }
                        Section {
                            Button("Copy Translation", systemImage: "doc.on.doc") {
                                copyText(viewModel.translationText, toast: String(localized: "Translation Copied"))
                            }
                            Button("Copy Original", systemImage: "doc.on.doc") {
                                copyText(viewModel.originalText, toast: String(localized: "Original Copied"))
                            }
                            Button("Show All Text", systemImage: "text.alignleft") { showingAllText = true }
                        }
                        Section {
                            Button("Reset Zoom", systemImage: "arrow.down.right.and.arrow.up.left") { viewerResetToken += 1 }
                            if coordinator.activeJob != nil {
                                Button("Translate Again", systemImage: "arrow.clockwise") { environment.retryLastJob() }
                            }
                        }
                    } label: {
                        ChromeIcon(systemName: "ellipsis")
                    }
                    .accessibilityLabel(Text("More"))
                }
            }
        }
        .padding(.top, 4)
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            if viewModel.translationFailureCount > 0 {
                Button { showingAllText = true } label: {
                    PartialNotice(count: viewModel.translationFailureCount)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .glassEffect(.regular.interactive(), in: .capsule)
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("Shows all recognized text"))
            } else if showingHint {
                Text("Tap any text for details")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .glassEffect(in: .capsule)
                    .transition(.opacity)
            }

            Picker("View", selection: $viewModel.displayMode.animation(reduceMotion ? nil : .default)) {
                ForEach(ResultMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 300)
            .padding(6)
            .glassEffect(in: .capsule)
        }
    }

    private func toggleChrome() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { chromeHidden.toggle() }
    }

    private func presentBlockDetail(_ block: ProcessedBlock) {
        selectedBlock = block
        chromeHidden = false
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func saveRenderedResult() {
        let saver = ResultImageSaveCoordinator { error in
            if error != nil {
                showToast(String(localized: "Couldn’t Save. Allow Photos access in Settings."), symbol: "exclamationmark.circle")
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            } else {
                showToast(String(localized: "Saved to Photos"), symbol: "checkmark.circle.fill")
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            imageSaveCoordinator = nil
        }
        imageSaveCoordinator = saver
        UIImageWriteToSavedPhotosAlbum(viewModel.result.renderedImage, saver,
                                       #selector(ResultImageSaveCoordinator.image(_:didFinishSavingWithError:contextInfo:)), nil)
    }

    private func copyText(_ text: String, toast message: String) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            showToast(String(localized: "Nothing to Copy"), symbol: "exclamationmark.circle")
            return
        }
        UIPasteboard.general.string = text
        showToast(message, symbol: "doc.on.doc.fill")
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func showToast(_ message: String, symbol: String) {
        toastTask?.cancel()
        withAnimation { toast = ResultToast(message: message, systemImage: symbol) }
        AccessibilityNotification.Announcement(message).post()
        toastTask = Task {
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            withAnimation { toast = nil }
        }
    }
}

private struct ChromeIcon: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: 44, height: 44)
            .glassEffect(.regular.interactive(), in: .circle)
    }
}

private struct ResultToast: Equatable {
    let message: String
    let systemImage: String
}

private struct ResultToastView: View {
    let toast: ResultToast

    var body: some View {
        Label(toast.message, systemImage: toast.systemImage)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(in: .capsule)
    }
}

private final class ResultImageSaveCoordinator: NSObject {
    private let completion: (Error?) -> Void

    init(completion: @escaping (Error?) -> Void) {
        self.completion = completion
    }

    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeMutableRawPointer?) {
        completion(error)
    }
}

private struct ResultBlockDetailSheet: View {
    let targetTitle: String
    let translation: String
    let original: String
    let note: String?
    let onCopy: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let note {
                    Section {
                        Label(note, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                if !translation.isEmpty {
                    Section(targetTitle) {
                        Text(translation).font(.body).textSelection(.enabled)
                    }
                }
                Section("Chinese") {
                    Text(original).font(.body).textSelection(.enabled)
                }
            }
            .navigationTitle("Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        if !translation.isEmpty {
                            Button("Copy Translation") { onCopy(translation, String(localized: "Translation Copied")) }
                        }
                        Button("Copy Original") { onCopy(original, String(localized: "Original Copied")) }
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
            }
        }
    }
}

private struct ResultTranscriptSheet: View {
    @ObservedObject var viewModel: ResultOverlayViewModel
    let onCopy: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if viewModel.translationFailureCount > 0 {
                    Section {
                        Label {
                            Text("Some text couldn’t be translated reliably. It stays in Chinese on the image and is marked below.")
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        }
                        .font(.subheadline)
                        if coordinatorHasJob {
                            Button("Translate Again", systemImage: "arrow.clockwise") { dismiss(); retry() }
                        }
                    }
                }
                Section {
                    ForEach(viewModel.blocks) { block in
                        VStack(alignment: .leading, spacing: 6) {
                            if block.failure?.stage == .translation {
                                Label("Not translated", systemImage: "exclamationmark.triangle.fill")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.orange)
                            } else {
                                Text(viewModel.translationText(for: block))
                            }
                            Text(viewModel.originalText(for: block))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .textSelection(.enabled)
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("All Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("Copy Translation") { onCopy(viewModel.translationText, String(localized: "Translation Copied")) }
                        Button("Copy Original") { onCopy(viewModel.originalText, String(localized: "Original Copied")) }
                        Button("Copy Both") { onCopy(viewModel.combinedText, String(localized: "Text Copied")) }
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
            }
        }
    }

    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var environment: AppEnvironment
    private var coordinatorHasJob: Bool { coordinator.activeJob != nil }
    private func retry() { environment.retryLastJob() }
}
