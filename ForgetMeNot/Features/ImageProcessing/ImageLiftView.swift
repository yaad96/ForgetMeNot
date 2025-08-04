//
//  ImageLiftView.swift
//  MyFirstApp
//
//  Created by Mainul Hossain on 8/4/25.
//


import SwiftUI

struct ImageLiftView: View {
    let uiImage: UIImage
    let onSubjectCopied: (UIImage) -> Void
    @State private var observer: NSObjectProtocol?

    var body: some View {
        VStack {
            ImageLift(uiImage: uiImage)
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
