//
//  WalkthroughView.swift
//  PlanPilot
//
//  Created by Mainul Hossain on 8/23/25.
//

import SwiftUI

struct WalkthroughView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    HeroCard(
                        title: Bundle.main.displayName,
                        subtitle: "Your AI-Powered Life Organizer",
                        detail: "Effortlessly turn photos, voice notes, and calendar events into smart, actionable plans with tasks and reminders."
                    )
                     
                    FeatureSection(
                        icon: "photo.circle.fill",
                        title: "Photo to Plan",
                        bullets: [
                            "Snap a photo of a flyer, poster, or screenshot.",
                            "Our AI instantly extracts key details like dates, times, and locations.",
                            "A complete plan with suggested tasks is created for you in seconds."
                        ],
                        tip: "Our powerful AI does the heavy lifting, turning visual clutter into organized clarity."
                    )

                    FeatureSection(
                        icon: "mic.fill",
                        title: "Talk to Plan",
                        bullets: [
                            "Tap record and describe your plan out loud—mention dates, budgets, and to-dos.",
                            "Pause and resume recording as new ideas come to mind.",
                            "Review the transcript, then let our AI generate your smart plan."
                        ],
                        tip: "For best results, add constraints like 'find a hotel under $150 near downtown.'"
                    )

                    FeatureSection(
                        icon: "calendar",
                        title: "Smart from Calendar",
                        bullets: [
                            "Grant calendar access to unlock a new level of organization.",
                            "Select an event and let our AI enrich it with relevant, suggested tasks.",
                            "Turn a simple meeting entry into a fully prepared agenda automatically."
                        ],
                        tip: "Supercharge your existing schedule without any manual entry."
                    )

                    FeatureSection(
                        icon: "checkmark.circle",
                        title: "Intelligent Tasks",
                        bullets: [
                            "Tasks are auto-generated from your plans, or you can add them manually.",
                            "Attach photos to tasks so you remember exactly what to buy or pack.",
                            "Feeling lazy? Just talk about the task and we will generate it for you.",
                            "Set due dates and powerful reminders for everything on your list.",
                            "Mark tasks as complete and watch your plan's progress."
                        ],
                        tip: "Completing all tasks marks the entire plan as a success!"
                    )

                    FeatureSection(
                        icon: "photo.on.rectangle.angled",
                        title: "Attachments & Subject Lift",
                        bullets: [
                            "Attach booking confirmations, tickets, or receipts directly to tasks.",
                            "Use 'Subject Lift' to isolate a key item from a photo for quick reference.",
                            "Keep all your important documents right where you need them."
                        ],
                        tip: "A lifted subject makes a perfect, high-visibility thumbnail for your task."
                    )
                    
                    FeatureSection(
                        icon: "bell.badge",
                        title: "Powerful Notifications",
                        bullets: [
                            "Enable notifications to stay on track with timely alerts.",
                            "Every task and event can have custom time-based reminders.",
                            "For critical items, make reminders 'incessant' until the task is done.",
                            "Tell the AI your preference: 'Remind me tomorrow at 5 PM' or 'Remind me every 10 minutes.'"
                        ]
                    )

                    FeatureSection(
                        icon: "lock.shield",
                        title: "Privacy and Control",
                        bullets: [
                            "Your chosen photo, voice and calendar text are sent to our AI service to generate your plans.",
                            "Only the photo you choose will be sent to the AI, we do not store your photos or audio recordings.",
                            "You have full control to edit transcripts before any data is processed.",
                            "All your plans, tasks, and attachments are stored securely on your device."
                        ]
                    )

                    FooterCTA()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground)) // Use a grouped background for better card contrast
            .navigationTitle("Feature Walkthrough")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Building blocks

private struct HeroCard: View {
    let title: String
    let subtitle: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 28, weight: .bold))
            Text(subtitle)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(detail)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.secondary.opacity(0.15)))
    }
}

private struct FeatureSection: View {
    let icon: String
    let title: String
    let bullets: [String]
    var tip: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { // Increased spacing for readability
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .bold)) // Larger, bolder icon
                    .foregroundStyle(Color.accentColor) // Use a brand accent color
                    .frame(width: 32, height: 32)
                Text(title)
                    .font(.title3.weight(.semibold)) // More prominent title for better hierarchy
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(bullets, id: \.self) { line in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill") // Custom, branded bullet icon
                            .font(.subheadline)
                            .foregroundStyle(.green)
                            .padding(.top, 2)
                        Text(line)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if let tip = tip {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill") // Filled icon for more emphasis
                        .imageScale(.medium)
                        .foregroundStyle(.orange)
                    Text(tip)
                        .font(.caption) // Smaller, distinct font for tips
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.1)) // Themed background for the tip
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(16) // Increased padding inside the card
        .background(Color(.secondarySystemGroupedBackground)) // Card background color
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2) // Subtle shadow for depth
    }
}


private struct FooterCTA: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ready for Takeoff?")
                .font(.system(size: 16, weight: .semibold))
            Text("Try a one-minute flight plan: Speak a goal, let the AI generate tasks, attach a photo, and set a reminder. You're flying!")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.secondary.opacity(0.15)))
    }
}


