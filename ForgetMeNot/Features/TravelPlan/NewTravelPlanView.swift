import SwiftUI
import SwiftData
import UIKit

extension UIImage {
    func resized(maxDim: CGFloat) -> UIImage {
        let width = size.width
        let height = size.height
        var newWidth: CGFloat
        var newHeight: CGFloat
        if width > height {
            newWidth = maxDim
            newHeight = height * (maxDim / width)
        } else {
            newHeight = maxDim
            newWidth = width * (maxDim / height)
        }
        let newSize = CGSize(width: newWidth, height: newHeight)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        draw(in: CGRect(origin: .zero, size: newSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage ?? self
    }
}


struct NewTravelPlanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query var subjects: [SubjectImage]
    
    @State private var showImageSourceDialog = false
    @State private var activeImagePickerSheet: ImagePickerSheet?

    @State private var planName: String = ""
    @State private var travelDate: Date = .now.addingTimeInterval(86400)
    @State private var reminderDate: Date = .now.addingTimeInterval(43200)

    @State private var tasks: [TravelTask] = [
        TravelTask(title: "Collect keys"),
        TravelTask(title: "Pack passport")
    ]

    //@State private var showImageSourcePicker = false
    @State private var imageToLift: UIImage?
    @State private var editingTaskIndex: Int?
    @State private var showImageLift = false
    @State private var showSubjectPreview: SubjectImage?
    //@State private var imagePickerSourceType: UIImagePickerController.SourceType?
    //@State private var showFMNImagePicker = false
    @State private var showNameError = false

    var onDone: (TravelPlan?) -> Void

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                
                VStack(spacing: 26) {
                    // PLAN DETAILS CARD
                    VStack(spacing: 20) {
                        TextField("Give your plan a name...", text: $planName)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 22)
                            .font(.system(size: 22, weight: .semibold))
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.03), radius: 2, y: 1)

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Travel Date & Time")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.secondary)
                            DatePicker("", selection: $travelDate, displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                                .datePickerStyle(.compact)
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Reminder")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.secondary)
                            DatePicker("", selection: $reminderDate, in: ...travelDate, displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                                .datePickerStyle(.compact)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(22)
                    .shadow(color: Color.black.opacity(0.08), radius: 16, y: 6)
                    .padding(.horizontal, 10)
                    .padding(.top, 8)

                    // TASKS CARD
                    VStack(spacing: 18) {
                        HStack {
                            Text("Tasks")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.primary)
                            Spacer()
                        }

                        ForEach(tasks.indices, id: \.self) { idx in
                            HStack(alignment: .center, spacing: 12) {
                                // SUBJECT IMAGE THUMBNAIL (modern style)
                                if let id = tasks[idx].subjectImageID,
                                   let subj = subjects.first(where: { $0.id == id }),
                                   let thumb = subj.thumbnail {
                                    Button {
                                        showSubjectPreview = subj
                                    } label: {
                                        Image(uiImage: thumb)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 48, height: 48)
                                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(Color.white.opacity(0.9), lineWidth: 2)
                                            )
                                            .shadow(color: Color.black.opacity(0.13), radius: 8, y: 3)
                                            .padding(.trailing, 2)
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    Button {
                                        editingTaskIndex = idx
                                        showImageSourceDialog = true
                                    } label: {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(Color(.systemGray5))
                                                .frame(width: 48, height: 48)
                                            Image(systemName: "photo.on.rectangle")
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 28, height: 28)
                                                .foregroundColor(.blue.opacity(0.82))
                                            Image(systemName: "plus.circle.fill")
                                                .resizable()
                                                .foregroundColor(.accentColor)
                                                .background(Color.white, in: Circle())
                                                .frame(width: 21, height: 21)
                                                .offset(x: 14, y: 14)
                                                .shadow(color: .black.opacity(0.13), radius: 2, x: 1, y: 1)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.trailing, 2)
                                }

                                // TASK FIELD
                                TextField("What to do?", text: Binding(
                                    get: { tasks[idx].title },
                                    set: { tasks[idx].title = $0 }
                                ))
                                .padding(.vertical, 12)
                                .padding(.horizontal, 12)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .font(.system(size: 17, weight: .regular))

                                // REMOVE TASK
                                if tasks.count > 1 {
                                    Button {
                                        tasks.remove(at: idx)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(.red)
                                            .font(.system(size: 22, weight: .semibold))
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.leading, 4)
                                }
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 4)
                            .background(.ultraThinMaterial)
                            .cornerRadius(18)
                            .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
                        }

                        // ADD TASK BUTTON (floating style)
                        Button {
                            withAnimation(.spring()) {
                                tasks.append(TravelTask(title: ""))
                            }
                        } label: {
                            Label("Add Task", systemImage: "plus.circle.fill")
                                .font(.system(size: 19, weight: .semibold))
                                .padding(.vertical, 11)
                                .padding(.horizontal, 18)
                                .background(Color.accentColor.opacity(0.92))
                                .foregroundColor(.white)
                                .cornerRadius(14)
                                .shadow(color: Color.accentColor.opacity(0.17), radius: 8, y: 2)
                        }
                        .padding(.top, 8)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(22)
                    .shadow(color: Color.black.opacity(0.07), radius: 14, y: 4)
                    .padding(.horizontal, 10)

                    Spacer(minLength: 20)
                }
                .padding(.bottom, 32)
            }
            .navigationTitle("New Travel Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { savePlan() }
                        .font(.system(size: 17, weight: .semibold))
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { cancel() }
                        .font(.system(size: 17, weight: .regular))
                }
            }
            .alert("Plan name is required.", isPresented: $showNameError) {
                Button("OK", role: .cancel) {}
            }
            .confirmationDialog("Attach an Image", isPresented: $showImageSourceDialog, titleVisibility: .visible) {
                Button("Take Photo") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        activeImagePickerSheet = .camera
                    }
                }
                Button("Choose From Gallery") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        activeImagePickerSheet = .photoLibrary
                    }
                }
                Button("Cancel", role: .cancel) { }
            }

        }
        .onChange(of: activeImagePickerSheet) {
            if activeImagePickerSheet == nil, imageToLift != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showImageLift = true
                }
            }
        }


        .sheet(item: $activeImagePickerSheet) { source in
            FMNImagePicker(sourceType: source == .camera ? .camera : .photoLibrary) { img in
                if let img = img {
                    imageToLift = img
                }
                activeImagePickerSheet = nil
            }
        }

        .sheet(isPresented: $showImageLift) {
            if let img = imageToLift, let idx = editingTaskIndex {
                ImageLiftView(uiImage: img) { subject in
                    handleLiftedImage(subject, forTaskAtIndex: idx)
                }
            }
        }
        .sheet(item: $showSubjectPreview) { subj in
            SubjectDetailView(subject: subj)
        }
    }

    private func savePlan() {
        let cleanTasks = tasks.filter { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !planName.trimmingCharacters(in: .whitespaces).isEmpty else {
            showNameError = true
            return
        }
        guard !cleanTasks.isEmpty else {
            onDone(nil)
            dismiss()
            return
        }
        let reminderOffset: TimeInterval = reminderDate.timeIntervalSince(travelDate)
        let plan = TravelPlan(name: planName, date: travelDate, tasks: cleanTasks, reminderOffset: reminderOffset)
        modelContext.insert(plan)
        NotificationHelper.scheduleTravelReminder(for: plan, offset: reminderOffset)
        onDone(plan)
        dismiss()
    }

    private func cancel() {
        onDone(nil)
        dismiss()
    }

    private func handleLiftedImage(_ subject: UIImage, forTaskAtIndex index: Int) {
        let resized = subject.resized(maxDim: 1024)
        guard let data = resized.pngData() else { return }
        let subjImg = SubjectImage(data: data)
        modelContext.insert(subjImg)
        tasks[index].subjectImageID = subjImg.id
        showImageLift = false
        imageToLift = nil
        editingTaskIndex = nil
    }
}

