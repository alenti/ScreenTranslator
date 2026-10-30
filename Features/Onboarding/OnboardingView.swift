import SwiftUI

/// First-run guide. The step is persisted, so an interruption (e.g. a Shortcut opening the app) resumes here.
struct OnboardingView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var settings: SettingsViewModel
    @State private var importing = false

    private let lastStep = 5

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                page
                    .padding(.horizontal, 24)
                    .padding(.top, 56)
                    .padding(.bottom, 24)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                    .id(step)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            }
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: 12) {
                PrimaryButton(title: primaryTitle) { advance() }
                    .disabled(settings.modelState.isBusy && step == 2)
                    .accessibilityIdentifier("onboarding.continue")
                if step > 0 && step < lastStep {
                    Button("Back") { withAnimation { settings.onboardingStep = step - 1 } }
                        .controlSize(.large)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            .frame(maxWidth: 560)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear { settings.refreshModelState() }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.data]) { result in
            Task {
                await settings.importModel(from: result, engine: environment.engine) {
                    await environment.processingViewModel.suspendLocalProcessing()
                }
            }
        }
    }

    private var step: Int { min(max(settings.onboardingStep, 0), lastStep) }

    private var primaryTitle: String {
        switch step {
        case 0: String(localized: "Get Started")
        case 2 where !settings.modelState.isReady: String(localized: "Set Up Later")
        case 4: String(localized: "Done")
        case lastStep: String(localized: "Start Translating")
        default: String(localized: "Continue")
        }
    }

    private func advance() {
        if step == lastStep {
            settings.onboardingCompleted = true
        } else {
            withAnimation { settings.onboardingStep = step + 1 }
        }
    }

    @ViewBuilder private var page: some View {
        switch step {
        case 0:
            VStack(spacing: 32) {
                FeatureHeader(symbol: "translate", title: String(localized: "Welcome to Screen Translator"),
                              message: String(localized: "Translate Chinese screenshots into English or Russian in seconds."))
                VStack(alignment: .leading, spacing: 20) {
                    WelcomeRow(symbol: "button.programmable", title: String(localized: "One Press"),
                               text: String(localized: "Translate whatever is on screen with the Action Button."))
                    WelcomeRow(symbol: "rectangle.on.rectangle", title: String(localized: "In Place"),
                               text: String(localized: "Translations are drawn right over the original text."))
                    WelcomeRow(symbol: "lock.shield", title: String(localized: "Private"),
                               text: String(localized: "Everything runs on this iPhone. Nothing is uploaded."))
                }
            }
        case 1:
            VStack(spacing: 28) {
                FeatureHeader(symbol: "globe", title: String(localized: "Choose a Language"),
                              message: String(localized: "Chinese text will be translated into this language. You can change it any time."))
                OptionGroup {
                    ForEach(TargetLanguage.allCases, id: \.self) { language in
                        Button {
                            settings.localTarget = language
                        } label: {
                            HStack {
                                Text(language.localizedTitle).font(.body)
                                Spacer()
                                if settings.localTarget == language {
                                    Image(systemName: "checkmark").font(.body.weight(.semibold)).foregroundStyle(.tint)
                                }
                            }
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(settings.localTarget == language ? .isSelected : [])
                        if language != TargetLanguage.allCases.last { Divider() }
                    }
                }
            }
        case 2:
            modelPage
        case 3:
            VStack(spacing: 28) {
                FeatureHeader(symbol: "rectangle.portrait.on.rectangle.portrait", title: String(localized: "How Should Results Open?"),
                              message: String(localized: "Pick what happens after you translate with the Action Button."))
                OptionGroup {
                    ForEach(ResultPresentation.allCases) { option in
                        PresentationOptionRow(option: option, selected: settings.resultPresentation == option) {
                            settings.resultPresentation = option
                        }
                        .padding(.vertical, 4)
                        if option != ResultPresentation.allCases.last { Divider() }
                    }
                }
            }
        case 4:
            VStack(alignment: .leading, spacing: 28) {
                FeatureHeader(symbol: "button.programmable", title: String(localized: "Set Up the Action Button"),
                              message: String(localized: "Create a shortcut once — then translate any screen with a single press."))
                OptionGroup {
                    ShortcutSetupSteps(presentation: settings.resultPresentation)
                        .padding(.vertical, 6)
                }
                Button {
                    ShortcutsApp.openNewShortcut()
                } label: {
                    Label("Open Shortcuts", systemImage: "arrow.up.forward.app").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
                Text("Already have a ScreenTranslator shortcut? It keeps working — you can skip this step.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        default:
            FeatureHeader(symbol: "checkmark.circle", title: String(localized: "You’re All Set"),
                          message: settings.modelState.isReady
                            ? String(localized: "Press the Action Button on any Chinese screen, or translate an image from Photos.")
                            : String(localized: "Set up the translator in Settings, then press the Action Button on any Chinese screen."),
                          tint: .green)
        }
    }

    @ViewBuilder private var modelPage: some View {
        switch settings.modelState {
        case .ready:
            FeatureHeader(symbol: "checkmark.seal", title: String(localized: "AI Model Ready"),
                          message: String(localized: "The translation model is installed on this iPhone."), tint: .green)
        case .checking, .installing:
            VStack(spacing: 20) {
                FeatureHeader(symbol: "cpu", title: String(localized: "Preparing the AI Model"),
                              message: String(localized: "Checking the model file. This can take a minute — keep the app open."))
                ProgressView()
            }
        default:
            VStack(spacing: 24) {
                FeatureHeader(symbol: "cpu", title: String(localized: "Install the AI Model"),
                              message: String(localized: "Translation needs a \(settings.modelSizeText) model that runs on this iPhone. Import the model file from Files."))
                if case .failed(let error) = settings.modelState {
                    Text(error.errorDescription ?? "").font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
                } else if settings.modelState == .insufficientStorage {
                    Text("Free up at least \(settings.modelSizeText) of storage, then try again.")
                        .font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
                }
                Button {
                    importing = true
                } label: {
                    Label("Import Model File…", systemImage: "square.and.arrow.down").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
            }
        }
    }
}

private struct WelcomeRow: View {
    let symbol: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 36)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Inset-grouped container matching Settings rows, for onboarding choices.
private struct OptionGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) { content }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}
