import SwiftUI

struct PhotoPlanConfirmSheet: View {
    let image: UIImage
    let onUse: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Capsule()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(width: 40, height: 5)
                    .padding(.top, 8)

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(radius: 6, y: 2)
                    .padding(.horizontal, 16)

                Text("We will analyze the photo with AI to infer event details and prep tasks.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                // Centered primary button
                HStack {
                    Spacer()
                    Button {
                        onUse()
                    } label: {
                        Label("Generate smart plan from this photo", systemImage: "sparkles")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .navigationTitle("Event from Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Top-left cancel as an "x" icon
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .imageScale(.medium)
                            .padding(6)
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

