import SwiftUI
import UIKit

struct ProcessingView: View {
    @ObservedObject var viewModel: ProcessingViewModel
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                if let progressValue = viewModel.state.progressValue {
                    ProgressView(value: progressValue)
                        .frame(maxWidth: 220)
                        .scaleEffect(x: 1, y: 1.2)
                } else {
                    ProgressView()
                        .scaleEffect(1.25)
                }

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

                if let latestInputSummary = viewModel.latestInputSummary {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Latest Screenshot Handoff")
                            .font(.headline)

                        Text(latestInputSummary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: 320, alignment: .leading)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.secondary.opacity(0.12))
                    )
                }

                if viewModel.state.isTerminal {
                    Text("Use Debug to inspect OCR, grouping, and translation output for the latest screenshot.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
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

struct FloatingPreviewFlowView: View {
    @Environment(\.colorScheme) private var colorScheme

    @ObservedObject var viewModel: ProcessingViewModel
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    floatingHeaderCard
                    previewCard
                    statusCard

                    if let latestInputSummary = viewModel.latestInputSummary {
                        handoffCard(summary: latestInputSummary)
                    }

                    if viewModel.state == .completed, viewModel.latestResult != nil {
                        actionButton(
                            title: "Open Full Viewer",
                            systemImage: "arrow.up.right.square"
                        ) {
                            guard let result = viewModel.latestResult else {
                                return
                            }

                            coordinator.showResult(result)
                        }
                    } else if viewModel.state == .failed {
                        actionButton(
                            title: "Try Again",
                            systemImage: "arrow.clockwise"
                        ) {
                            viewModel.retryCurrentJob()
                        }
                    }
                }
                .padding(18)
                .padding(.bottom, 24)
            }
            .background(backgroundView.ignoresSafeArea())
            .navigationTitle("Floating Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Settings") {
                        coordinator.showSettings()
                    }

                    Button("Debug") {
                        coordinator.showDebug()
                    }
                }
            }
        }
    }

    private var floatingHeaderCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Lightweight preview path")
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)

            Text("The floating shortcut now runs OCR, grouping, translation, and rendering inside ScreenTranslator, then keeps the result in this lighter preview surface instead of the fullscreen viewer.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(cardStroke)
        )
    }

    private var previewCard: some View {
        OverlayPreviewSurface(
            title: previewTitle,
            hint: previewHint
        ) {
            if let image = previewImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.10))
                    .overlay {
                        Image(systemName: previewPlaceholderSymbol)
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.72))
                    }
            }
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Text(viewModel.state.displayTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)

                if let progressValue = viewModel.state.progressValue {
                    Text("\(Int((progressValue * 100).rounded()))%")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(statusBadgeTextColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(statusBadgeFill)
                        )
                }
            }

            if let progressValue = viewModel.state.progressValue {
                ProgressView(value: progressValue)
                    .tint(statusProgressTint)
            }

            Text(viewModel.statusMessage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Text(statusDetailText)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(cardStroke)
        )
    }

    private func handoffCard(summary: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Screenshot")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            Text(summary)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.04))
        )
    }

    private func actionButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.headline)

                Text(title)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(.white)
            .background(
                Capsule()
                    .fill(primaryActionFill)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var previewTitle: String {
        switch viewModel.state {
        case .completed:
            return "Translated Preview Ready"
        case .failed:
            return "Preview Needs Attention"
        default:
            return "Processing Screenshot"
        }
    }

    private var previewHint: String {
        switch viewModel.state {
        case .completed:
            if let translatedBlockCount = viewModel.latestResult?.translatedBlocks.count {
                return "\(translatedBlockCount) translated block\(translatedBlockCount == 1 ? "" : "s") ready in the lightweight preview."
            }

            return "The translated screenshot is ready in the lightweight preview."
        case .failed:
            return "The app-owned processing path reported a failure before the preview finished."
        default:
            return "Processing runs inside ScreenTranslator so Translation.framework stays on the stable app-owned path."
        }
    }

    private var statusDetailText: String {
        if viewModel.state == .failed {
            return viewModel.activeError?.recoverySuggestion
                ?? viewModel.activeError?.errorDescription
                ?? viewModel.detailMessage
        }

        return viewModel.detailMessage
    }

    private var previewImage: UIImage? {
        if let renderedData = viewModel.latestResult?.precomposedImageData,
           let image = UIImage(data: renderedData) {
            return image
        }

        guard let sourceData = viewModel.activeJob?.input.imageData else {
            return nil
        }

        return UIImage(data: sourceData)
    }

    private var previewPlaceholderSymbol: String {
        switch viewModel.state {
        case .completed:
            return "checkmark.viewfinder"
        case .failed:
            return viewModel.activeError?.symbolName ?? "exclamationmark.triangle"
        default:
            return "text.viewfinder"
        }
    }

    private var backgroundView: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    Color(red: 0.05, green: 0.06, blue: 0.08),
                    Color(red: 0.08, green: 0.10, blue: 0.14)
                ]
                : [
                    Color(red: 0.94, green: 0.96, blue: 0.99),
                    Color(red: 0.88, green: 0.92, blue: 0.98)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var cardFill: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.06)
            : Color.white
    }

    private var cardStroke: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.08)
    }

    private var statusBadgeFill: Color {
        switch viewModel.state {
        case .completed:
            return Color.green.opacity(colorScheme == .dark ? 0.22 : 0.16)
        case .failed:
            return Color.red.opacity(colorScheme == .dark ? 0.22 : 0.16)
        default:
            return Color.blue.opacity(colorScheme == .dark ? 0.22 : 0.14)
        }
    }

    private var statusBadgeTextColor: Color {
        switch viewModel.state {
        case .completed:
            return colorScheme == .dark ? Color.green.opacity(0.95) : Color.green
        case .failed:
            return colorScheme == .dark ? Color.red.opacity(0.95) : Color.red
        default:
            return colorScheme == .dark
                ? Color(red: 0.82, green: 0.91, blue: 1.0)
                : Color(red: 0.05, green: 0.31, blue: 0.61)
        }
    }

    private var statusProgressTint: Color {
        switch viewModel.state {
        case .completed:
            return .green
        case .failed:
            return .red
        default:
            return colorScheme == .dark
                ? Color(red: 0.66, green: 0.81, blue: 0.96)
                : Color(red: 0.15, green: 0.45, blue: 0.90)
        }
    }

    private var primaryActionFill: Color {
        colorScheme == .dark
            ? Color(red: 0.19, green: 0.48, blue: 0.93)
            : Color(red: 0.11, green: 0.42, blue: 0.89)
    }
}
