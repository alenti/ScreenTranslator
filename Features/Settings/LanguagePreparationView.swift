import SwiftUI

struct LanguagePreparationView: View {
    @Environment(\.colorScheme) private var colorScheme

    let readiness: TranslationLanguageManager.ReadinessState
    let summary: String
    let isPreparing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Group {
                    if isPreparing {
                        ProgressView()
                            .tint(statusColor)
                    } else {
                        Image(systemName: statusSymbolName)
                            .foregroundStyle(statusColor)
                    }
                }
                .frame(width: 20, height: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Offline Translation")
                        .font(.headline)
                        .foregroundStyle(primaryTextColor)

                    Text(statusTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusColor)
                }
            }

            Text(summary)
                .font(.footnote)
                .foregroundStyle(secondaryTextColor)

            if isPreparing {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(statusColor)

                    Text("Preparation is running on this device. Keep this screen open while the language data is installed.")
                        .font(.footnote)
                        .foregroundStyle(secondaryTextColor)
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(cardStroke)
        )
    }

    private var statusTitle: String {
        if isPreparing {
            return "Preparing on This Device"
        }

        switch readiness {
        case .unknown:
            return "Not Checked Yet"
        case .needsPreparation:
            return "Preparation Needed"
        case .ready:
            return "Ready for Offline Translation"
        case .unsupported:
            return "Unsupported on This Device"
        }
    }

    private var statusSymbolName: String {
        switch readiness {
        case .unknown:
            return "questionmark.circle"
        case .needsPreparation:
            return "arrow.down.circle"
        case .ready:
            return "checkmark.circle"
        case .unsupported:
            return "xmark.octagon"
        }
    }

    private var statusColor: Color {
        switch readiness {
        case .unknown:
            return secondaryTextColor
        case .needsPreparation:
            return Color(red: 1.0, green: 0.82, blue: 0.45)
        case .ready:
            return Color(red: 0.56, green: 0.88, blue: 0.63)
        case .unsupported:
            return Color(red: 1.0, green: 0.55, blue: 0.55)
        }
    }

    private var primaryTextColor: Color {
        colorScheme == .dark
            ? .white
            : Color(red: 0.13, green: 0.15, blue: 0.19)
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark
            ? .white.opacity(0.72)
            : Color.black.opacity(0.64)
    }

    private var cardFill: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.07)
            : Color.white.opacity(0.76)
    }

    private var cardStroke: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.08)
    }
}
