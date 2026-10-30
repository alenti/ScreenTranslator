import PhotosUI
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var settings: SettingsViewModel
    @State private var pickerItem: PhotosPickerItem?
    @State private var loadingImage = false
    @State private var pickerError: AppError?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    header
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4))

                // A translator that doesn't work comes first; a working one is just a status at the bottom.
                if translatorNeedsFix { TranslatorStatusSection() }

                Section {
                    Picker(selection: $settings.localTarget) {
                        ForEach(TargetLanguage.allCases, id: \.self) { Text($0.localizedTitle).tag($0) }
                    } label: {
                        Label("Translate To", systemImage: "globe")
                    }
                } footer: {
                    Text("Chinese text is translated privately on this iPhone.")
                }

                if let result = coordinator.processedScreenshot {
                    Section("Last Translation") {
                        Button {
                            environment.openFullViewer()
                        } label: {
                            LastTranslationRow(result: result)
                        }
                        .tint(.primary)
                    }
                }

                Section {
                    NavigationLink {
                        ShortcutsSetupView()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Translate from Any App")
                                Text(settings.resultPresentation.title)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "button.programmable")
                        }
                    }
                } header: {
                    Text("Action Button")
                }

                if !translatorNeedsFix { TranslatorStatusSection() }
            }
            .navigationTitle("Screen Translator")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        coordinator.showingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .accessibilityIdentifier("home.settings")
                }
            }
        }
        .sheet(isPresented: $coordinator.showingSettings) {
            SettingsView()
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await loadPickedImage(item) }
        }
        .alert(pickerError?.title ?? "", isPresented: Binding(get: { pickerError != nil }, set: { if !$0 { pickerError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(pickerError?.errorDescription ?? "")
        }
    }

    private var translatorNeedsFix: Bool { !settings.modelState.isReady && !settings.modelState.isBusy }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Translate Chinese screenshots into \(settings.localTarget.localizedTitle) — right on your iPhone.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            PhotosPicker(selection: $pickerItem, matching: .images, preferredItemEncoding: .current) {
                Group {
                    if loadingImage {
                        ProgressView()
                    } else {
                        Label("Translate Image", systemImage: "photo.on.rectangle.angled")
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(loadingImage)
            .accessibilityIdentifier("home.translateImage")
        }
    }

    private func loadPickedImage(_ item: PhotosPickerItem) async {
        loadingImage = true
        defer { loadingImage = false; pickerItem = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { throw AppError.unsupportedImage }
            environment.translate(try ScreenshotInputBuilder().build(imageData: data, sourceMetadata: .photoLibrary))
        } catch {
            pickerError = (error as? AppError) ?? .unsupportedImage
        }
    }
}

private struct LastTranslationRow: View {
    let result: ProcessedScreenshot

    var body: some View {
        HStack(spacing: 14) {
            Image(uiImage: result.renderedImage)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.separator))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Chinese → \(result.targetLanguage.localizedTitle)")
                    .font(.body)
                if result.translationFailureCount > 0 {
                    Label("Partly translated", systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                } else {
                    Text("Open in viewer")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}
