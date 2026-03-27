import SwiftUI

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
