import SwiftUI

struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme

    @ObservedObject var viewModel: SettingsViewModel
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var isShowingShortcutsSetup = false

    var body: some View {
        ZStack {
            backgroundView

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerView
                    shortcutsCard
                    displayCard
                    offlineCard
                }
                .padding(18)
                .padding(.bottom, 110)
            }
        }
        .safeAreaInset(edge: .bottom) {
            doneBar
        }
        .task {
            await viewModel.refreshLanguageStatus()
        }
        .sheet(isPresented: $isShowingShortcutsSetup) {
            ShortcutsSetupView()
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
        VStack(alignment: .leading, spacing: 6) {
            Text("Settings")
                .font(.title2.weight(.bold))
                .foregroundStyle(primaryTextColor)

            Text("Keep the translator fast and readable. These settings affect the rendered overlay and offline translation readiness.")
                .font(.footnote)
                .foregroundStyle(secondaryTextColor)
        }
    }

    private var displayCard: some View {
        settingsCard(title: "Overlay Style") {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Preferred Result Mode")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(primaryTextColor)

                    Picker("Preferred Result Mode", selection: preferredDisplayModeBinding) {
                        ForEach(ResultMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                sliderRow(
                    title: "Overlay Background",
                    valueLabel: viewModel.backgroundOpacityLabel,
                    binding: backgroundOpacityBinding,
                    range: 0.55...0.96
                )

                sliderRow(
                    title: "Maximum Font Size",
                    valueLabel: viewModel.maximumFontSizeLabel,
                    binding: maximumFontSizeBinding,
                    range: 14...28
                )

                sliderRow(
                    title: "Corner Radius",
                    valueLabel: viewModel.cornerRadiusLabel,
                    binding: cornerRadiusBinding,
                    range: 8...22
                )

                Button {
                    viewModel.resetOverlayStyle()
                } label: {
                    Text("Reset Overlay Style")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .foregroundStyle(primaryTextColor)
                        .background(
                            Capsule()
                                .fill(secondaryButtonFill)
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(secondaryButtonStroke)
                        )
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var shortcutsCard: some View {
        settingsCard(title: "Shortcuts Setup") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Install two ready-made screenshot flows in Shortcuts, with the main fullscreen translator kept as the default path.")
                    .font(.subheadline)
                    .foregroundStyle(secondaryTextColor)

                HStack(spacing: 10) {
                    shortcutFlowPill(
                        title: "Main",
                        subtitle: "Take Screenshot -> Open in App Translator",
                        isPrimary: true
                    )

                    shortcutFlowPill(
                        title: "Floating",
                        subtitle: "Take Screenshot -> Floating Screen Translator",
                        isPrimary: false
                    )
                }

                Button {
                    isShowingShortcutsSetup = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.down.on.square")
                            .font(.headline)

                        Text("Set Up Screenshot Shortcuts")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .foregroundStyle(primaryButtonTextColor)
                    .background(
                        Capsule()
                            .fill(primaryButtonFill)
                    )
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var offlineCard: some View {
        settingsCard(title: "Offline Preparation") {
            VStack(alignment: .leading, spacing: 14) {
                LanguagePreparationView(
                    readiness: viewModel.languageReadiness,
                    summary: viewModel.languageSummary,
                    isPreparing: viewModel.isPreparingLanguageData
                )

                Button {
                    viewModel.startPreparingOfflineLanguageData()
                } label: {
                    HStack(spacing: 10) {
                        if viewModel.isPreparingLanguageData {
                            ProgressView()
                                .tint(primaryButtonTextColor)
                        }

                        Text(viewModel.prepareButtonTitle)
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .foregroundStyle(
                        viewModel.prepareButtonDisabled
                            ? disabledButtonTextColor
                            : primaryButtonTextColor
                    )
                    .background(
                        Capsule()
                            .fill(
                                viewModel.prepareButtonDisabled
                                    ? disabledButtonFill
                                    : primaryButtonFill
                            )
                    )
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.prepareButtonDisabled)
            }
        }
    }

    private func settingsCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)
                .foregroundStyle(primaryTextColor)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .strokeBorder(cardStroke)
        )
    }

    private func sliderRow(
        title: String,
        valueLabel: String,
        binding: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(primaryTextColor)

                Spacer()

                Text(valueLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tertiaryTextColor)
            }

            Slider(value: binding, in: range)
                .tint(sliderTintColor)
        }
    }

    private func shortcutFlowPill(
        title: String,
        subtitle: String,
        isPrimary: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(primaryTextColor)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(secondaryTextColor)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    isPrimary
                        ? primaryButtonFill.opacity(colorScheme == .dark ? 0.18 : 0.08)
                        : secondaryButtonFill
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    isPrimary
                        ? primaryButtonFill.opacity(colorScheme == .dark ? 0.34 : 0.18)
                        : secondaryButtonStroke
                )
        )
    }

    private var doneBar: some View {
        VStack(spacing: 10) {
            Button {
                coordinator.returnToProcessing()
            } label: {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundStyle(primaryButtonTextColor)
                    .background(
                        Capsule()
                            .fill(primaryButtonFill)
                    )
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .shadow(color: shadowColor, radius: 16, y: 8)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
        )
    }

    private var preferredDisplayModeBinding: Binding<ResultMode> {
        Binding(
            get: { viewModel.preferredDisplayMode },
            set: { viewModel.updatePreferredDisplayMode($0) }
        )
    }

    private var backgroundOpacityBinding: Binding<Double> {
        Binding(
            get: { viewModel.settings.overlayStyle.backgroundOpacity },
            set: { viewModel.updateBackgroundOpacity($0) }
        )
    }

    private var maximumFontSizeBinding: Binding<Double> {
        Binding(
            get: { viewModel.settings.overlayStyle.maximumFontSize },
            set: { viewModel.updateMaximumFontSize($0) }
        )
    }

    private var cornerRadiusBinding: Binding<Double> {
        Binding(
            get: { viewModel.settings.overlayStyle.cornerRadius },
            set: { viewModel.updateCornerRadius($0) }
        )
    }

    private var backgroundGradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.06, green: 0.07, blue: 0.09),
                Color(red: 0.08, green: 0.09, blue: 0.12),
                Color(red: 0.11, green: 0.09, blue: 0.08)
            ]
        }

        return [
            Color(red: 0.95, green: 0.97, blue: 0.99),
            Color(red: 0.93, green: 0.95, blue: 0.98),
            Color(red: 0.98, green: 0.96, blue: 0.94)
        ]
    }

    private var primaryTextColor: Color {
        colorScheme == .dark
            ? .white
            : Color(red: 0.13, green: 0.15, blue: 0.19)
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark
            ? .white.opacity(0.68)
            : Color.black.opacity(0.64)
    }

    private var tertiaryTextColor: Color {
        colorScheme == .dark
            ? .white.opacity(0.64)
            : Color.black.opacity(0.52)
    }

    private var sliderTintColor: Color {
        colorScheme == .dark
            ? .white
            : Color(red: 0.17, green: 0.44, blue: 0.94)
    }

    private var cardFill: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.06)
            : Color.white.opacity(0.76)
    }

    private var cardStroke: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.08)
    }

    private var secondaryButtonFill: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.06)
    }

    private var secondaryButtonStroke: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.08)
    }

    private var primaryButtonFill: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.96)
            : Color.black.opacity(0.88)
    }

    private var primaryButtonTextColor: Color {
        colorScheme == .dark
            ? Color(red: 0.08, green: 0.09, blue: 0.11)
            : .white
    }

    private var disabledButtonFill: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.12)
            : Color.black.opacity(0.10)
    }

    private var disabledButtonTextColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.55)
            : Color.black.opacity(0.46)
    }

    private var shadowColor: Color {
        colorScheme == .dark
            ? .black.opacity(0.24)
            : .black.opacity(0.12)
    }
}
