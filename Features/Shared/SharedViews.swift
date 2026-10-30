import SwiftUI

extension TargetLanguage {
    var localizedTitle: String {
        switch self {
        case .english: String(localized: "English")
        case .russian: String(localized: "Russian")
        }
    }
}

extension ProcessedScreenshot {
    /// Blocks whose model output was rejected; their original pixels are kept and must be disclosed.
    var translationFailureCount: Int { warnings.filter { $0.stage == .translation }.count }
}

/// Model readiness as a symbol + text. Shared by Home, Settings and onboarding so states read the same everywhere.
struct ModelStatusLabel: View {
    let state: ModelState

    var body: some View {
        HStack(spacing: 6) {
            if state.isBusy {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: symbol).foregroundStyle(color)
            }
            Text(state.title).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch state {
        case .ready: "checkmark.circle.fill"
        case .notInstalled, .damaged: "exclamationmark.circle.fill"
        default: "xmark.octagon.fill"
        }
    }

    private var color: Color {
        switch state {
        case .ready: .green
        case .notInstalled, .damaged: .orange
        default: .red
        }
    }
}

/// "Translator: Working / Not Working". When it doesn't work, offers the one fix: importing the model file.
struct TranslatorStatusSection: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var settings: SettingsViewModel
    @State private var importing = false

    private var needsFix: Bool { !settings.modelState.isReady && !settings.modelState.isBusy }

    var body: some View {
        Section {
            LabeledContent {
                ModelStatusLabel(state: settings.modelState)
            } label: {
                Label("Translator", systemImage: "character.book.closed")
            }
            if needsFix {
                Button {
                    importing = true
                } label: {
                    Label("Import Model File…", systemImage: "square.and.arrow.down")
                }
            }
        } footer: {
            if needsFix { Text(reason) }
        }
        .onAppear { settings.refreshModelState() }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.data]) { result in
            Task {
                await settings.importModel(from: result, engine: environment.engine) {
                    await environment.processingViewModel.suspendLocalProcessing()
                }
            }
        }
    }

    private var reason: String {
        switch settings.modelState {
        case .insufficientStorage: String(localized: "Free up at least \(settings.modelSizeText) of storage, then try again.")
        case .failed(let error): error.errorDescription ?? ""
        default: String(localized: "Choose “\(activeModelName).gguf” in Files. The file is checked before it is installed.")
        }
    }
}

/// Exact steps for the chosen Shortcut. iOS doesn't let apps edit a user's Shortcut, so these are instructions.
struct ShortcutSetupSteps: View {
    let presentation: ResultPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(index + 1, format: .number)
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(.tint))
                        .accessibilityHidden(true)
                    Text(step.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let example = step.example {
                    // Localized screenshots (Assets: en/ru) of what the user should end up with.
                    Image(example.image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.separator))
                        .frame(maxWidth: 300)
                        .padding(.leading, 36)
                        .accessibilityLabel(Text(example.label))
                }
            }
        }
    }

    private typealias Step = (text: LocalizedStringKey, example: (image: String, label: LocalizedStringResource)?)

    private var steps: [Step] {
        let actionButton: Step = ("In iPhone **Settings › Action Button**, choose **Shortcut** and select your new shortcut.",
                                  ("SetupActionButton", "Example: the Action Button set to the new shortcut"))
        switch presentation {
        case .quickPreview:
            return [("Open **Shortcuts** and tap **+** to create a shortcut.", nil),
                    ("Add the **Take Screenshot** action.", nil),
                    ("Add **Translate Screenshot for Quick Look**. Search for “ChinaTap” to find it.", nil),
                    ("Add the **Quick Look** action.", ("SetupShortcutQuickPreview", "Example: the finished shortcut")),
                    actionButton]
        case .openInApp:
            return [("Open **Shortcuts** and tap **+** to create a shortcut.", nil),
                    ("Add the **Take Screenshot** action.", nil),
                    ("Add **Translate Screenshot in App**. Search for “ChinaTap” to find it.",
                     ("SetupShortcutOpenInApp", "Example: the finished shortcut")),
                    actionButton]
        }
    }
}

/// Large symbol + title + text, used for onboarding pages and empty/error states.
struct FeatureHeader: View {
    let symbol: String
    let title: String
    let message: String
    var tint: Color = .accentColor

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 88, height: 88)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .accessibilityHidden(true)
            Text(title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Full-width primary action, the one prominent button on a screen.
struct PrimaryButton: View {
    let title: String
    var symbol: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let symbol { Label(title, systemImage: symbol) } else { Text(title) }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
    }
}

enum ShortcutsApp {
    /// Opens the Shortcuts editor on a new shortcut. Falls back to the app if this URL ever stops working.
    @MainActor static func openNewShortcut() {
        guard let url = URL(string: "shortcuts://create-shortcut") else { return }
        UIApplication.shared.open(url) { opened in
            if !opened, let app = URL(string: "shortcuts://") { UIApplication.shared.open(app) }
        }
    }
}
