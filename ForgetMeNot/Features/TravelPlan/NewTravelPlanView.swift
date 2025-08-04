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

    @State private var planName: String = ""
    @State private var travelDate: Date = .now.addingTimeInterval(86400)
    @State private var reminderDate: Date = .now.addingTimeInterval(43200)

    @State private var tasks: [TravelTask] = [
        TravelTask(title: "Collect keys"),
        TravelTask(title: "Pack passport")
    ]

    @State private var showImageSourcePicker = false
    @State private var imageToLift: UIImage?
    @State private var editingTaskIndex: Int?
    @State private var showImageLift = false
    @State private var showSubjectPreview: SubjectImage?
    @State private var imagePickerSourceType: UIImagePickerController.SourceType?
    @State private var showFMNImagePicker = false
    @State private var showNameError = false

    var onDone: (TravelPlan?) -> Void

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 18) {
                    TextField("Plan Name", text: $planName)
                        .font(.title2)
                        .textFieldStyle(.roundedBorder)
                    Text("Travel Date & Time")
                        .font(.headline)
                    DatePicker("", selection: $travelDate, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .padding(.bottom, 8)
                    Text("When should we remind you?")
                        .font(.headline)
                    DatePicker("", selection: $reminderDate, in: ...travelDate, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .padding(.bottom, 16)
                    Text("Tasks").font(.headline)
                    ForEach(tasks.indices, id: \.self) { idx in
                        HStack {
                            TextField("Task...", text: Binding(
                                get: { tasks[idx].title },
                                set: { tasks[idx].title = $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                            if let id = tasks[idx].subjectImageID,
                               let subj = subjects.first(where: { $0.id == id }),
                               let thumb = subj.thumbnail {
                                Button {
                                    showSubjectPreview = subj
                                } label: {
                                    Image(uiImage: thumb)
                                        .resizable()
                                        .frame(width: 38, height: 38)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                            Button {
                                editingTaskIndex = idx
                                showImageSourcePicker = true
                            } label: {
                                Image(systemName: "photo.badge.plus")
                            }
                            .buttonStyle(.plain)
                            if tasks.count > 1 {
                                Button {
                                    tasks.remove(at: idx)
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Button {
                        tasks.append(TravelTask(title: ""))
                    } label: {
                        Label("Add Task", systemImage: "plus")
                            .padding(.vertical, 4)
                    }
                    .padding(.top, 8)
                }
                .padding()
            }
            .navigationTitle("New Travel Plan")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { savePlan() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { cancel() }
                }
            }
            .alert("Plan name is required.", isPresented: $showNameError) {
                Button("OK", role: .cancel) {}
            }
        }
        .sheet(isPresented: $showImageSourcePicker) {
            ImageSourcePicker { sourceType in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    imagePickerSourceType = sourceType
                    showFMNImagePicker = true
                }
            }
        }
        .sheet(isPresented: $showFMNImagePicker) {
            if let source = imagePickerSourceType {
                FMNImagePicker(sourceType: source) { img in
                    if let img = img {
                        imageToLift = img
                        showImageLift = true
                    }
                    showFMNImagePicker = false
                }
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

