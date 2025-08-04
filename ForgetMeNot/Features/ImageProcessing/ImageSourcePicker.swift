import SwiftUI
import UIKit

struct ImageSourcePicker: View {
    var onSourcePicked: (UIImagePickerController.SourceType) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Attach an Image")
                .font(.headline)
            Button("Take Photo") {
                onSourcePicked(.camera)
                dismiss()
            }
            .buttonStyle(.borderedProminent)

            Button("Choose From Gallery") {
                onSourcePicked(.photoLibrary)
                dismiss()
            }
            .buttonStyle(.bordered)

            Button("Cancel", role: .cancel) {
                dismiss()
            }
        }
        .padding(40)
    }
}

