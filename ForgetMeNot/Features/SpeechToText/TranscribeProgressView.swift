//
//  TranscribeProgressView.swift
//  ForgetMeNot
//
//  Created by Mainul Hossain on 8/19/25.
//


import SwiftUI

struct TranscribeProgressView: View {
    var body: some View {
        VStack(spacing: 16) {
            Capsule().fill(Color.secondary.opacity(0.25)).frame(width: 40, height: 5).padding(.top, 8)
            Text("Transcribing with OpenAI").font(.headline)
            ProgressView().padding(.bottom, 12)
            Text("This may take a moment for longer recordings.")
                .font(.subheadline).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.bottom, 12)
        .presentationDetents([.fraction(0.3)])
    }
}
