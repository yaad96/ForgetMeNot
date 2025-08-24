//
//  ConfirmTranscriptSheet.swift
//  ForgetMeNot
//
//  Created by Mainul Hossain on 8/19/25.
//

import SwiftUI

struct ConfirmTranscriptSheet: View {
    @Binding var text: String
    let onUse: () -> Void
    let onCancel: () -> Void
    @FocusState private var focus: Bool

    var primaryLabel: String = "Generate Smart Event Plan"
    var primarySymbol: String = "sparkles"

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $text)
                        .focused($focus) // keyboard shows only when user taps
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled(false)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                        )
                        .frame(minHeight: 240)

                    if text.isEmpty {
                        Text("Edit transcript here...")
                            .foregroundColor(.secondary)
                            .padding(.top, 16)
                            .padding(.leading, 16)
                            .allowsHitTesting(false)
                    }
                }

                HStack {
                    Button("Cancel") { onCancel() }
                        .foregroundColor(.secondary)

                    Spacer()

                    Button(action: {
                        // Hide the keyboard before using
                        focus = false
                        onUse()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: primarySymbol)
                            Text(primaryLabel)
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.vertical, 7)
                        .padding(.horizontal, 16)
                        .background(Capsule().fill(Color.blue.opacity(0.13)))
                    }
                    .foregroundColor(.blue)
                    .buttonStyle(.plain)
                }
                .padding(.top, 8)
            }
            .padding()
            .navigationTitle("Confirm Transcript")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focus = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

