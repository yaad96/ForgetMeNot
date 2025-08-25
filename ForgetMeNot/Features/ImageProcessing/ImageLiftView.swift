import SwiftUI

struct ImageLiftView: View {
    let uiImage: UIImage
    let onSubjectCopied: (UIImage) -> Void
    @State private var observer: NSObjectProtocol?

    private let buttonHeight: CGFloat = 72

    var body: some View {
        ZStack {
            VisualEffectBlur(blurStyle: .systemUltraThinMaterialDark)
                .ignoresSafeArea()
            GeometryReader { geo in
                VStack(spacing: 0) {
                    // Larger, more readable instruction
                    Text("🖐️ Long-press to extract subject\n📸 or Tap below to use full image")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white.opacity(0.91))
                        .multilineTextAlignment(.center)
                        .padding(.top, 32)
                        .padding(.horizontal, 18)
                        .lineLimit(2)
                        .minimumScaleFactor(0.92)

                    Spacer(minLength: 0)

                    // Image with rounded corners and shadow
                    ZStack {
                        ImageLift(uiImage: uiImage)
                            .aspectRatio(contentMode: .fit)
                            .frame(
                                maxWidth: max(0, geo.size.width * 0.97),
                                maxHeight: max(0, geo.size.height - buttonHeight - 95)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .shadow(color: .black.opacity(0.14), radius: 15, y: 6)
                    }

                    Spacer(minLength: 0)

                    // Button
                    Button {
                        onSubjectCopied(uiImage)
                    } label: {
                        Label("Use Full Image", systemImage: "photo.on.rectangle")
                            .font(.system(size: 19, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                LinearGradient(
                                    colors: [Color.accentColor, Color.blue.opacity(0.92)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(15)
                            .shadow(color: Color.blue.opacity(0.17), radius: 11, y: 3)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 18)
                    .frame(height: buttonHeight)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            observer = NotificationCenter.default.addObserver(
                forName: UIPasteboard.changedNotification,
                object: nil,
                queue: .main
            ) { _ in
                if let copied = UIPasteboard.general.image {
                    onSubjectCopied(copied)
                }
            }
        }
        .onDisappear {
            if let observer = observer {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
}

// Helper for background blur
struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) { }
}

