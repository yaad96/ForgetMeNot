//
//  ImageLift.swift
//  MyFirstApp
//
//  Created by Mainul Hossain on 8/4/25.
//


import SwiftUI
import VisionKit

@MainActor
struct ImageLift: UIViewRepresentable {
    let uiImage: UIImage
    let imageView = LiftImageView()
    let analyzer = ImageAnalyzer()
    let interaction = ImageAnalysisInteraction()

    func makeUIView(context: Context) -> some UIView {
        imageView.image = uiImage
        imageView.contentMode = .scaleAspectFit
        imageView.addInteraction(interaction)
        return imageView
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {
        Task {
            if let image = imageView.image {
                let configuration = ImageAnalyzer.Configuration([.text, .visualLookUp, .machineReadableCode])
                let analysis = try? await analyzer.analyze(image, configuration: configuration)
                if let analysis = analysis {
                    interaction.analysis = analysis
                    interaction.preferredInteractionTypes = .automatic
                }
            }
        }
    }
}

class LiftImageView: UIImageView {
    override var intrinsicContentSize: CGSize {
        .zero
    }
}
