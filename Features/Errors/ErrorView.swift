import SwiftUI

struct ErrorView: View {
    @ObservedObject var viewModel: ErrorViewModel
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var environment: AppEnvironment

    @State private var isRunningRecoveryAction = false
    @State private var recoveryStatusMessage: String?

    var body: some View {
        ZStack {
            backgroundView

            VStack(spacing: 20) {
                Spacer(minLength: 24)

                errorCard

                Spacer(minLength: 12)
            }
            .padding(20)
        }
    }

    private var backgroundView: some View {
        LinearGradient(
            colors: [
                Color(red: 0.06, green: 0.07, blue: 0.09),
                Color(red: 0.10, green: 0.08, blue: 0.07),
                Color(red: 0.08, green: 0.09, blue: 0.12)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var errorCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: viewModel.symbolName)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(
                        Circle()
                            .fill(Color.red.opacity(0.28))
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)

                    Text(viewModel.message)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.86))
                }
            }

            if let failureReason = viewModel.failureReason {
                detailSection(
                    title: "What Happened",
                    text: failureReason
                )
            }

            if let recoverySuggestion = viewModel.recoverySuggestion {
                detailSection(
                    title: "Suggested Recovery",
                    text: recoverySuggestion
                )
            }

            if let recoveryStatusMessage {
                Text(recoveryStatusMessage)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
            }

            if isRunningRecoveryAction {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(.white)

                    Text("Running recovery action...")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.78))
                }
            }

            actionButtons
        }
        .frame(maxWidth: 520, alignment: .leading)
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 30)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .strokeBorder(Color.white.opacity(0.08))
        )
        .shadow(color: .black.opacity(0.28), radius: 24, y: 14)
    }

    private func detailSection(
        title: String,
        text: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))

            Text(text)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.82))
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if let primaryRecoveryOption = viewModel.primaryRecoveryOption {
                Button {
                    Task {
                        await perform(primaryRecoveryOption.action)
                    }
                } label: {
                    Text(primaryRecoveryOption.title)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .foregroundStyle(Color(red: 0.07, green: 0.08, blue: 0.10))
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.96))
                        )
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isRunningRecoveryAction)
            }

            ForEach(viewModel.secondaryRecoveryOptions) { option in
                Button {
                    Task {
                        await perform(option.action)
                    }
                } label: {
                    Text(option.title)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(.white)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.08))
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.08))
                        )
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isRunningRecoveryAction)
            }
        }
    }

    private func perform(
        _ action: ErrorRecoveryAction
    ) async {
        recoveryStatusMessage = nil

        switch action {
        case .retryCurrentJob:
            guard coordinator.activeJob != nil else {
                coordinator.returnToProcessing()
                return
            }

            coordinator.showProcessing(job: coordinator.activeJob)
            environment.processingViewModel.retryCurrentJob()

        case .backToProcessing:
            coordinator.returnToProcessing()

        case .openSettings:
            coordinator.showSettings()

        case .openDebug:
            coordinator.showDebug()

        case .prepareOfflineLanguageData:
            isRunningRecoveryAction = true
            defer {
                isRunningRecoveryAction = false
            }

            await environment.settingsViewModel.prepareOfflineLanguageData()

            switch environment.settingsViewModel.languageReadiness {
            case .ready:
                recoveryStatusMessage = "Offline language data is ready."

                if coordinator.activeJob != nil {
                    coordinator.showProcessing(job: coordinator.activeJob)
                    environment.processingViewModel.retryCurrentJob()
                } else {
                    coordinator.showSettings()
                }
            case .unsupported:
                recoveryStatusMessage = environment.settingsViewModel.languageSummary
            case .unknown, .needsPreparation:
                recoveryStatusMessage = environment.settingsViewModel.languageSummary
            }
        }
    }
}
