import SwiftUI

struct DebugView: View {
    @Environment(\.colorScheme) private var colorScheme

    @StateObject private var viewModel: DebugViewModel
    @EnvironmentObject private var coordinator: AppCoordinator

    init(viewModel: DebugViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            backgroundView

            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        headerView

                        DebugOverlayInspectorView(
                            selectedStage: $viewModel.selectedStage,
                            stages: viewModel.inspectionStages,
                            comparisonSummary: viewModel.comparisonSummary,
                            statusMessage: viewModel.selectedStageStatusMessage,
                            backdropDescription: viewModel.previewBackdropDescription,
                            previewImageData: viewModel.previewImageData,
                            previewCanvasSize: viewModel.previewCanvasSizeForSelectedStage,
                            inspectionBoxes: viewModel.selectedStageBoxes
                        )

                        DebugOCRInspectorView(
                            inputSummary: viewModel.inputSummary,
                            comparisonSummary: viewModel.comparisonSummary,
                            observations: viewModel.ocrObservations,
                            groupedBlocks: viewModel.groupedBlocks,
                            translationBlocks: viewModel.translationBlocks,
                            isLoading: viewModel.isLoadingOCR,
                            statusMessage: viewModel.ocrStatusMessage,
                            groupingStatusMessage: viewModel.groupingStatusMessage,
                            translationStatusMessage: viewModel.translationStatusMessage,
                            overlayBlocks: viewModel.overlayBlocksForInspection,
                            overlayStatusMessage: viewModel.overlayInspectionStatusMessage
                        )
                    }
                    .padding(18)
                }
                .scrollIndicators(.hidden)
                .task {
                    await viewModel.loadOCRPreviewIfNeeded()
                }
                .navigationTitle("Debug")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            coordinator.returnToProcessing()
                        }
                    }
                }
                .toolbarBackground(.hidden, for: .navigationBar)
            }
            .background(Color.clear)
        }
    }

    private var backgroundView: some View {
        LinearGradient(
            colors: backgroundGradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("OCR And Overlay Diagnostics")
                .font(.title3.weight(.semibold))
                .foregroundStyle(primaryTextColor)

            Text("Use the visual inspector to see exactly where OCR, grouping, translation, and final overlay placement diverge. The structured sections below mirror the same pipeline in a scan-friendly form.")
                .font(.footnote)
                .foregroundStyle(secondaryTextColor)
        }
    }

    private var backgroundGradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.05, green: 0.06, blue: 0.08),
                Color(red: 0.07, green: 0.08, blue: 0.11),
                Color(red: 0.10, green: 0.09, blue: 0.08)
            ]
        }

        return [
            Color(red: 0.95, green: 0.97, blue: 0.99),
            Color(red: 0.93, green: 0.95, blue: 0.98),
            Color(red: 0.97, green: 0.95, blue: 0.94)
        ]
    }

    private var primaryTextColor: Color {
        colorScheme == .dark
            ? .white
            : Color.primary
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark
            ? .white.opacity(0.66)
            : Color.secondary
    }
}
