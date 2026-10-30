import SwiftUI

struct ShortcutsSetupView: View {
    @EnvironmentObject private var settings: SettingsViewModel

    var body: some View {
        List {
            Section {
                ForEach(ResultPresentation.allCases) { option in
                    PresentationOptionRow(option: option, selected: settings.resultPresentation == option) {
                        settings.resultPresentation = option
                    }
                }
            } header: {
                Text("Show Results")
            } footer: {
                Text("Quick Preview is recommended for everyday use.")
            }

            Section {
                ShortcutSetupSteps(presentation: settings.resultPresentation)
                    .padding(.vertical, 6)
                Button {
                    ShortcutsApp.openNewShortcut()
                } label: {
                    Label("Open Shortcuts", systemImage: "arrow.up.forward.app")
                }
                if let url = importURL {
                    Link(destination: url) { Label("Add Ready-Made Shortcut", systemImage: "plus.circle") }
                }
            } header: {
                Text("Set Up \(settings.resultPresentation.title)")
            } footer: {
                Text("Already have a shortcut? It keeps working. To switch modes, edit it in Shortcuts to match the steps above.")
            }
        }
        .navigationTitle("Action Button")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Optional iCloud links configured in Info.plist; hidden until they exist.
    private var importURL: URL? {
        let key = settings.resultPresentation == .quickPreview ? "QuickPreviewShortcutURL" : "MainScreenshotTranslatorShortcutURL"
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)), url.scheme == "https" else { return nil }
        return url
    }
}

/// Selectable card row with a checkmark, used in Settings and onboarding.
struct PresentationOptionRow: View {
    let option: ResultPresentation
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: option.symbolName)
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(option.title).font(.headline)
                        if option == .quickPreview {
                            Text("Recommended")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tint)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.tint.opacity(0.12), in: Capsule())
                        }
                    }
                    Text(option.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}
