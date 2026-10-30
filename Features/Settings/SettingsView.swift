import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Translate To", selection: $settings.localTarget) {
                        ForEach(TargetLanguage.allCases, id: \.self) { Text($0.localizedTitle).tag($0) }
                    }
                    Picker("Show Results", selection: $settings.resultPresentation) {
                        ForEach(ResultPresentation.allCases) { Text($0.title).tag($0) }
                    }
                } header: {
                    Text("Translation")
                } footer: {
                    Text("“Show Results” sets up your Action Button shortcut. After changing it, update the shortcut once — see Action Button Setup below.")
                }

                // iOS owns per-app language; changing it there relaunches the app in the new language.
                Section {
                    Button {
                        openURL(URL(string: UIApplication.openSettingsURLString)!)
                    } label: {
                        LabeledContent("App Language", value: appLanguage)
                    }
                    .tint(.primary)
                } footer: {
                    Text("Opens iOS Settings. Choose Language there to use the app in English or Russian.")
                }

                Section("Action Button") {
                    NavigationLink("Action Button Setup") { ShortcutsSetupView() }
                }

                TranslatorStatusSection()

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    NavigationLink("Privacy") { PrivacyView() }
                    NavigationLink("Acknowledgements") { AcknowledgementsView() }
                    Button("Show Welcome Guide") {
                        settings.onboardingStep = 0
                        settings.onboardingCompleted = false
                        dismiss()
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    /// The language the app is running in, named in that language ("English", "Русский").
    private var appLanguage: String {
        let code = Bundle.main.preferredLocalizations.first ?? "en"
        let locale = Locale(identifier: code)
        return locale.localizedString(forLanguageCode: code)?.capitalized(with: locale) ?? code
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "\(version) (\(build))"
    }
}

private struct PrivacyView: View {
    var body: some View {
        Form {
            Section {
                Label("Screenshots and recognized text are processed only on this iPhone.", systemImage: "iphone")
                Label("Nothing is uploaded. The app has no accounts, ads or analytics.", systemImage: "icloud.slash")
                Label("Translated images are saved to Photos only when you tap Save.", systemImage: "photo")
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AcknowledgementsView: View {
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: "llama.cpp / ggml").font(.headline)
                    Text(verbatim: "Copyright (c) 2023-2026 The ggml authors. MIT License.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: "JSON for Modern C++").font(.headline)
                    Text(verbatim: "Copyright (c) 2013-2025 Niels Lohmann. MIT License.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: "Hy-MT2-1.8B").font(.headline)
                    Text(verbatim: "Translation model by Tencent Hunyuan, distributed under its own model license.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Link(destination: URL(string: "https://huggingface.co/tencent/Hy-MT2-1.8B-GGUF")!) {
                        Text(verbatim: "huggingface.co/tencent/Hy-MT2-1.8B-GGUF").font(.footnote)
                    }
                }
            }
            Section {
                Text(verbatim: mitLicense)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            } header: {
                Text(verbatim: "MIT License")
            }
        }
        .navigationTitle("Acknowledgements")
        .navigationBarTitleDisplayMode(.inline)
    }

    private let mitLicense = """
    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    """
}
