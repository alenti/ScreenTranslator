import AppIntents
import SwiftUI

struct ShortcutsSetupView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    private let importLinks = ShortcutImportLinks.current

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerCard
                    availabilityCard

                    ShortcutFlowCard(
                        flow: .main,
                        importURL: importLinks.main
                    )

                    ShortcutFlowCard(
                        flow: .floating,
                        importURL: importLinks.floating
                    )
                }
                .padding(18)
                .padding(.bottom, 24)
            }
            .background(backgroundColor.ignoresSafeArea())
            .navigationTitle("Shortcuts Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Install two screenshot flows")
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)

            Text("The main flow keeps the existing fullscreen in-app translator as the default experience. The floating flow stays separate and opens a lighter preview-first path inside the app.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                flowSummaryRow(
                    title: "Main Screenshot Translator",
                    summary: "Take Screenshot -> Open in App Translator",
                    isPrimary: true
                )

                flowSummaryRow(
                    title: "Floating Screenshot Translator",
                    summary: "Take Screenshot -> Floating Screen Translator",
                    isPrimary: false
                )
            }
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

    private var availabilityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(importLinks.hasAnyImportLink ? "Ready-Made Import" : "Guided Setup")
                .font(.headline)
                .foregroundStyle(.primary)

            Text(importLinks.hasAnyImportLink
                 ? "This build includes shared shortcut links. Use the Add Shortcut button on each flow to install the complete 2-step command."
                 : "This build does not include shared shortcut links yet. You can still create both flows in Shortcuts with the exact 2-step structure shown below.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if importLinks.hasAnyImportLink == false {
                Text("Use the Apple-provided button below to jump into Shortcuts, then add `Take Screenshot` first and the matching ScreenTranslator action second.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                ShortcutsLink()
                    .shortcutsLinkStyle(shortcutsLinkStyle)
            }
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

    private func flowSummaryRow(
        title: String,
        summary: String,
        isPrimary: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isPrimary ? "star.circle.fill" : "rectangle.on.rectangle")
                .font(.headline)
                .foregroundStyle(isPrimary ? primaryAccentColor : secondaryAccentColor)
                .frame(width: 22, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    badge(text: isPrimary ? "Primary" : "Secondary", isPrimary: isPrimary)
                }

                Text(summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func badge(text: String, isPrimary: Bool) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(isPrimary ? primaryBadgeText : secondaryBadgeText)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(isPrimary ? primaryBadgeFill : secondaryBadgeFill)
            )
    }

    private var backgroundColor: Color {
        colorScheme == .dark
            ? Color(red: 0.05, green: 0.06, blue: 0.08)
            : Color(red: 0.95, green: 0.96, blue: 0.98)
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

    private var primaryAccentColor: Color {
        colorScheme == .dark
            ? Color(red: 0.98, green: 0.86, blue: 0.46)
            : Color(red: 0.91, green: 0.56, blue: 0.09)
    }

    private var secondaryAccentColor: Color {
        colorScheme == .dark
            ? Color(red: 0.66, green: 0.81, blue: 0.96)
            : Color(red: 0.15, green: 0.45, blue: 0.90)
    }

    private var primaryBadgeFill: Color {
        primaryAccentColor.opacity(colorScheme == .dark ? 0.22 : 0.12)
    }

    private var primaryBadgeText: Color {
        colorScheme == .dark
            ? Color(red: 1.00, green: 0.91, blue: 0.66)
            : Color(red: 0.45, green: 0.27, blue: 0.02)
    }

    private var secondaryBadgeFill: Color {
        secondaryAccentColor.opacity(colorScheme == .dark ? 0.22 : 0.12)
    }

    private var secondaryBadgeText: Color {
        colorScheme == .dark
            ? Color(red: 0.82, green: 0.91, blue: 1.00)
            : Color(red: 0.05, green: 0.31, blue: 0.61)
    }

    private var shortcutsLinkStyle: ShortcutsLinkStyle {
        colorScheme == .dark ? .darkOutline : .lightOutline
    }
}

private struct ShortcutFlowCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let flow: ShortcutFlow
    let importURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            VStack(alignment: .leading, spacing: 10) {
                Text("Ready flow")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                flowPreview
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("App action used")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                Text(flow.actionName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            if let importURL {
                importButton(url: importURL)
            } else {
                fallbackGuide
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(borderColor)
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: flow.symbolName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(flow.accentColor(for: colorScheme))
                    .frame(width: 30, alignment: .center)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(flow.title)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text(flow.priorityLabel)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(flow.badgeTextColor(for: colorScheme))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(flow.badgeFillColor(for: colorScheme))
                            )
                    }

                    Text(flow.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Text(flow.outcome)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var flowPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepRow(number: 1, text: "Take Screenshot")
            stepRow(number: 2, text: flow.actionName)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(flow.previewFillColor(for: colorScheme))
        )
    }

    private func stepRow(number: Int, text: String) -> some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(flow.stepNumberTextColor(for: colorScheme))
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(flow.stepNumberFillColor(for: colorScheme))
                )

            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
    }

    private func importButton(url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 10) {
                Image(systemName: "square.and.arrow.down")
                    .font(.headline)

                Text(flow.importTitle)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(flow.importTextColor(for: colorScheme))
            .background(
                Capsule()
                    .fill(flow.importFillColor(for: colorScheme))
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var fallbackGuide: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Set up in Shortcuts")
                .font(.headline)
                .foregroundStyle(.primary)

            Text(flow.fallbackSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                instructionRow(number: 1, text: "Create a new shortcut and add `Take Screenshot` as the first action.")
                instructionRow(number: 2, text: "Add `\(flow.actionName)` as the second action.")
                instructionRow(number: 3, text: flow.fallbackOutcome)
            }

            ShortcutsLink()
                .shortcutsLinkStyle(colorScheme == .dark ? .darkOutline : .lightOutline)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.04))
        )
    }

    private func instructionRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number).")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(flow.accentColor(for: colorScheme))
                .frame(width: 20, alignment: .leading)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }

    private var cardFill: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.05)
            : Color.white
    }

    private var borderColor: Color {
        flow.badgeFillColor(for: colorScheme)
    }
}

private enum ShortcutFlow {
    case main
    case floating

    var title: String {
        switch self {
        case .main:
            return "Main Screenshot Translator"
        case .floating:
            return "Floating Screenshot Translator"
        }
    }

    var summary: String {
        switch self {
        case .main:
            return "Primary screenshot flow that opens the current fullscreen translator inside the app."
        case .floating:
            return "Secondary screenshot flow that opens the lightweight preview path inside the app."
        }
    }

    var outcome: String {
        switch self {
        case .main:
            return "Preserves the existing OCR, grouping, translation, rendering, and fullscreen result viewer behavior."
        case .floating:
            return "Uses the same app-owned OCR, grouping, translation, and rendering pipeline, but lands in a lighter preview route instead of the fullscreen viewer."
        }
    }

    var fallbackSummary: String {
        switch self {
        case .main:
            return "Recommended default. This is the stable baseline flow users should rely on first."
        case .floating:
            return "Optional secondary flow for the floating preview experience."
        }
    }

    var fallbackOutcome: String {
        switch self {
        case .main:
            return "Name the shortcut `Main Screenshot Translator` so it is easy to recognize as the default fullscreen flow."
        case .floating:
            return "Name the shortcut `Floating Screenshot Translator` so it stays clearly separate from the fullscreen path."
        }
    }

    var actionName: String {
        switch self {
        case .main:
            return "Open in App Translator"
        case .floating:
            return "Floating Screen Translator"
        }
    }

    var importTitle: String {
        switch self {
        case .main:
            return "Add Main Shortcut"
        case .floating:
            return "Add Floating Shortcut"
        }
    }

    var priorityLabel: String {
        switch self {
        case .main:
            return "Primary"
        case .floating:
            return "Secondary"
        }
    }

    var symbolName: String {
        switch self {
        case .main:
            return "text.viewfinder"
        case .floating:
            return "rectangle.on.rectangle"
        }
    }

    func accentColor(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .main:
            return colorScheme == .dark
                ? Color(red: 0.98, green: 0.86, blue: 0.46)
                : Color(red: 0.91, green: 0.56, blue: 0.09)
        case .floating:
            return colorScheme == .dark
                ? Color(red: 0.66, green: 0.81, blue: 0.96)
                : Color(red: 0.15, green: 0.45, blue: 0.90)
        }
    }

    func badgeFillColor(for colorScheme: ColorScheme) -> Color {
        accentColor(for: colorScheme).opacity(colorScheme == .dark ? 0.18 : 0.12)
    }

    func badgeTextColor(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .main:
            return colorScheme == .dark
                ? Color(red: 1.00, green: 0.91, blue: 0.66)
                : Color(red: 0.45, green: 0.27, blue: 0.02)
        case .floating:
            return colorScheme == .dark
                ? Color(red: 0.82, green: 0.91, blue: 1.00)
                : Color(red: 0.05, green: 0.31, blue: 0.61)
        }
    }

    func previewFillColor(for colorScheme: ColorScheme) -> Color {
        accentColor(for: colorScheme).opacity(colorScheme == .dark ? 0.16 : 0.08)
    }

    func stepNumberFillColor(for colorScheme: ColorScheme) -> Color {
        accentColor(for: colorScheme).opacity(colorScheme == .dark ? 0.22 : 0.14)
    }

    func stepNumberTextColor(for colorScheme: ColorScheme) -> Color {
        badgeTextColor(for: colorScheme)
    }

    func importFillColor(for colorScheme: ColorScheme) -> Color {
        accentColor(for: colorScheme)
    }

    func importTextColor(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .main:
            return colorScheme == .dark
                ? Color(red: 0.20, green: 0.12, blue: 0.01)
                : .white
        case .floating:
            return .white
        }
    }
}

private struct ShortcutImportLinks {
    let main: URL?
    let floating: URL?

    var hasAnyImportLink: Bool {
        main != nil || floating != nil
    }

    static var current: ShortcutImportLinks {
        ShortcutImportLinks(
            main: url(for: "MainScreenshotTranslatorShortcutURL"),
            floating: url(for: "FloatingScreenshotTranslatorShortcutURL")
        )
    }

    private static func url(for key: String) -> URL? {
        guard let rawValue = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }

        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedValue.isEmpty == false else {
            return nil
        }

        return URL(string: trimmedValue)
    }
}
