import SwiftUI

struct WalkthroughView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    HeroCard(
                        title: "Never4Get",
                        subtitle: "Speak. Plan. Act.",
                        detail: "Turn a short voice note into a smart travel plan with tasks, reminders, and attachments."
                    )

                    FeatureSection(
                        icon: "mic.fill",
                        title: "Talk to Plan",
                        bullets: [
                            "Tap Record. Speak naturally about dates, places, budget, and must do items.",
                            "Pause and resume as needed. Stop when you are done.",
                            "Edit the transcript then tap Generate Smart Travel Plan."
                        ],
                        tip: "Say constraints in the prompt, example, hotel under 120 dollars near Midtown."
                    )

                    FeatureSection(
                        icon: "calendar",
                        title: "Smart from Calendar",
                        bullets: [
                            "Grant Calendar access in Settings.",
                            "Pick an event and tap Make Smart Plan.",
                            "Tasks and time blocks match the event window."
                        ],
                        tip: "Check time zones when travel crosses regions."
                    )

                    FeatureSection(
                        icon: "checkmark.circle",
                        title: "Tasks",
                        bullets: [
                            "Auto created from speech and plans, or add manually.",
                            "Set due date, reminders, and notes.",
                            "Mark done, reorder, or convert blocks to tasks."
                        ],
                        tip: "Use filters Today, Overdue, Completed to focus."
                    )

                    FeatureSection(
                        icon: "photo.on.rectangle.angled",
                        title: "Attachments and Subject Lift",
                        bullets: [
                            "Attach photos to any task.",
                            "Lift Subject to isolate tickets or items for quick visual reference.",
                            "Keep booking proof next to the task."
                        ],
                        tip: "Use the lifted subject as the task thumbnail."
                    )

                    FeatureSection(
                        icon: "wand.and.stars",
                        title: "Smart Plan Editor",
                        bullets: [
                            "Drag to reorder blocks.",
                            "Edit duration and notes inline.",
                            "Regenerate suggestions for a section without losing locked items."
                        ]
                    )

                    FeatureSection(
                        icon: "character.book.closed.fill",
                        title: "Language and Multilingual input",
                        bullets: [
                            "Auto detect is on by default for mixed Bangla and English.",
                            "Set a primary language in Settings if detection is wrong.",
                            "Fix names and numbers in the transcript before generating."
                        ],
                        tip: "Say dates and times clearly, example, October twelve at five pm."
                    )

                    FeatureSection(
                        icon: "bell.badge",
                        title: "Notifications",
                        bullets: [
                            "Allow notifications in iOS Settings.",
                            "Each task can have a reminder by time or location when available.",
                            "Snooze ten minutes, one hour, or tomorrow."
                        ]
                    )

                    FeatureSection(
                        icon: "lock.shield",
                        title: "Privacy and data control",
                        bullets: [
                            "Voice and calendar text are sent to the AI service to create smart plans and tasks.",
                            "Delete transcripts and plans at any time.",
                            "Export a plan via the share menu."
                        ]
                    )

                    FeatureSection(
                        icon: "questionmark.circle",
                        title: "Troubleshooting",
                        bullets: [
                            "Wrong language, set a primary language in Settings.",
                            "Generic plan, add constraints like budget and neighborhoods.",
                            "Missing photos, check Photos permission for the app.",
                            "Silent reminders, check iOS notification settings and Focus."
                        ]
                    )

                    FooterCTA()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .padding(.top, 8)
            }
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
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.secondary.opacity(0.15)))
    }
}

private struct FeatureSection: View {
    let icon: String
    let title: String
    let bullets: [String]
    var tip: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 28, height: 28)
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(bullets, id: \.self) { line in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.system(size: 16, weight: .bold))
                            .padding(.top, 1)
                        Text(line)
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if let tip = tip {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb")
                        .imageScale(.medium)
                    Text(tip)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Divider().opacity(0.2)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct FooterCTA: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("One minute demo")
                .font(.system(size: 16, weight: .semibold))
            Text("Record a short prompt, generate a plan, attach a ticket, and set a reminder. You are done.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.secondary.opacity(0.15)))
    }
}
