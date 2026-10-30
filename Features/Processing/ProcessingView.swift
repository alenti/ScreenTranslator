import SwiftUI
import UIKit

/// Open in App route: progress → full viewer. Errors and cancellation are shown in place.
struct TranslationProgressView: View {
    @ObservedObject var viewModel: ProcessingViewModel
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        NavigationStack {
            ProgressPanel(viewModel: viewModel, identifierPrefix: "progress")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        if viewModel.state.isTerminal || viewModel.activeJob == nil {
                            Button("Close") { environment.closeTranslation() }
                                .accessibilityIdentifier("progress.close")
                        }
                    }
                }
        }
    }
}

/// Retained for already-installed "Floating Screen Translator" shortcuts: a light result screen
/// whose Open Full Viewer reuses the same completed result.
struct FloatingPreviewFlowView: View {
    @ObservedObject var viewModel: ProcessingViewModel
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.state == .completed, let result = coordinator.processedScreenshot {
                    VStack(spacing: 16) {
                        Image(uiImage: result.renderedImage)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.separator))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .accessibilityLabel(Text("Translated screenshot"))
                            .accessibilityIdentifier("floating.previewImage")
                        if result.translationFailureCount > 0 {
                            PartialNotice(count: result.translationFailureCount)
                        }
                        PrimaryButton(title: String(localized: "Open Full Viewer"), symbol: "arrow.up.left.and.arrow.down.right") {
                            environment.openFullViewer()
                        }
                        .accessibilityIdentifier("floating.openFullViewer")
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                } else {
                    ProgressPanel(viewModel: viewModel, identifierPrefix: "floating")
                }
            }
            .navigationTitle("Translation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { environment.closeTranslation() }
                        .accessibilityIdentifier("floating.dismiss")
                }
            }
        }
    }
}

struct PartialNotice: View {
    let count: Int

    var body: some View {
        Label {
            Text("\(count) text blocks shown in the original")
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}

/// Shared progress / cancelled / failed content with its actions.
private struct ProgressPanel: View {
    @ObservedObject var viewModel: ProcessingViewModel
    let identifierPrefix: String
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var settings: SettingsViewModel
    @State private var thumbnail: UIImage?

    private var error: AppError? { coordinator.activeError ?? viewModel.activeError }

    var body: some View {
        VStack(spacing: 24) {
            ScrollView {
                VStack(spacing: 28) {
                    if let error, viewModel.state == .failed || viewModel.activeJob == nil {
                        FeatureHeader(symbol: error.symbolName, title: error.title, message: error.errorDescription ?? "", tint: .orange)
                            .padding(.top, 40)
                    } else if viewModel.state == .cancelled {
                        FeatureHeader(symbol: "xmark.circle", title: String(localized: "Translation Cancelled"),
                                      message: String(localized: "You can try again at any time."), tint: .secondary)
                            .padding(.top, 40)
                    } else {
                        if let thumbnail {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.separator))
                                .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
                                .frame(maxHeight: 280)
                                .accessibilityHidden(true)
                        }
                        VStack(alignment: .leading, spacing: 18) {
                            Text("Chinese → \(targetTitle)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            StepRow(title: String(localized: "Reading screenshot"), detail: nil, status: status(of: .readingScreenshot))
                            StepRow(title: String(localized: "Translating"), detail: translatingDetail, status: status(of: .translating),
                                    progress: viewModel.totalCount > 0 && status(of: .translating) == .active
                                        ? Double(viewModel.translatedCount) / Double(viewModel.totalCount) : nil)
                            StepRow(title: String(localized: "Preparing preview"), detail: nil, status: status(of: .preparingPreview))
                        }
                        .frame(maxWidth: 360, alignment: .leading)
                        .accessibilityElement(children: .combine)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }
            .scrollBounceBehavior(.basedOnSize)

            actions
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
        }
        .task(id: viewModel.activeJob?.id) {
            let data = viewModel.activeJob?.input.imageData
            thumbnail = await Task.detached { data.flatMap(UIImage.init(data:))?.preparingThumbnail(of: CGSize(width: 400, height: 800)) }.value
        }
        .onChange(of: viewModel.state) { _, state in
            if let announcement = announcement(for: state) { AccessibilityNotification.Announcement(announcement).post() }
        }
    }

    @ViewBuilder private var actions: some View {
        VStack(spacing: 12) {
            if !viewModel.state.isTerminal && viewModel.activeJob != nil {
                Button(role: .cancel) {
                    viewModel.cancelCurrentJob()
                } label: {
                    Text("Cancel").font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
                .accessibilityIdentifier("\(identifierPrefix).cancel")
            } else {
                if let error, error.needsModelSetup {
                    PrimaryButton(title: String(localized: "Set Up AI Model")) { coordinator.openModelSettings() }
                } else if viewModel.activeJob != nil, viewModel.state == .cancelled || error?.canRetry == true {
                    PrimaryButton(title: String(localized: "Try Again"), symbol: "arrow.clockwise") { environment.retryLastJob() }
                        .accessibilityIdentifier("\(identifierPrefix).retry")
                }
            }
        }
    }

    private var targetTitle: String { settings.localTarget.localizedTitle }

    private var translatingDetail: String? {
        guard status(of: .translating) == .active else { return nil }
        if viewModel.isPreparingModel { return String(localized: "Getting the AI model ready…") }
        guard viewModel.totalCount > 0 else { return nil }
        return String(localized: "\(viewModel.translatedCount) of \(viewModel.totalCount) text blocks")
    }

    private func status(of step: ProcessingState) -> StepRow.Status {
        let order: [ProcessingState] = [.readingScreenshot, .translating, .preparingPreview, .completed]
        guard let current = order.firstIndex(of: viewModel.state), let index = order.firstIndex(of: step) else { return .pending }
        return index < current ? .done : index == current ? .active : .pending
    }

    private func announcement(for state: ProcessingState) -> String? {
        switch state {
        case .translating: String(localized: "Translating")
        case .preparingPreview: String(localized: "Preparing preview")
        case .cancelled: String(localized: "Translation Cancelled")
        case .failed: error?.title
        default: nil
        }
    }
}

private struct StepRow: View {
    enum Status { case pending, active, done }
    let title: String
    let detail: String?
    let status: Status
    var progress: Double?

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Group {
                switch status {
                case .done: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                case .active: ProgressView()
                case .pending: Image(systemName: "circle").foregroundStyle(.tertiary)
                }
            }
            .font(.title3)
            .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.body.weight(status == .active ? .semibold : .regular))
                    .foregroundStyle(status == .pending ? .secondary : .primary)
                if let detail {
                    Text(detail)
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                if let progress {
                    ProgressView(value: progress)
                        .animation(.default, value: progress)
                }
            }
        }
    }
}
