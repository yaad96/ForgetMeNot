//
//  SubjectDetailView.swift
//  ForgetMeNot
//
//  Created by Mainul Hossain on 8/4/25.
//


import SwiftUI
import SwiftData

struct SubjectDetailView: View {
    let subject: SubjectImage
    @Environment(\.dismiss) private var dismiss

    @State private var uiImage: UIImage?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            Color.black.opacity(0.9).ignoresSafeArea()
            if isLoading {
                ProgressView("Loading…")
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            } else if let img = uiImage {
                VStack {
                    Spacer()
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .padding()
                    Spacer()
                    Button("Close") { dismiss() }
                        .foregroundColor(.white)
                        .padding(.bottom, 40)
                }
            } else {
                Text("Failed to load image")
                    .foregroundColor(.white)
                    .onTapGesture { dismiss() }
            }
        }
        .onAppear {
            DispatchQueue.global(qos: .userInitiated).async {
                let loaded: UIImage? = {
                    if let cached = SessionImageCache.shared.image(for: subject.id) {
                        return cached
                    }
                    guard let decoded = UIImage(data: subject.data) else { return nil }
                    SessionImageCache.shared.set(decoded, for: subject.id)
                    return decoded
                }()
                DispatchQueue.main.async {
                    uiImage = loaded
                    isLoading = false
                }
            }
        }
    }
}
