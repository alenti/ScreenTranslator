import SwiftUI

struct OverlayPreviewSurface<Content: View>: View {
    let title: String
    let hint: String
    let showsReset: Bool
    let onReset: (() -> Void)?
    private let content: Content

    init(
        title: String,
        hint: String,
        showsReset: Bool = false,
        onReset: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.hint = hint
        self.showsReset = showsReset
        self.onReset = onReset
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)

                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                if showsReset, let onReset {
                    Button("Fit") {
                        onReset()
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.10))
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.10))
                    )
                    .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 490)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(Color.white.opacity(0.08))
        )
        .shadow(color: .black.opacity(0.26), radius: 28, y: 14)
    }
}
