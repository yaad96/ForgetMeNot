//
//  VoiceRecorderSheet.swift
//  ForgetMeNot
//
//  Created by Mainul Hossain on 8/19/25.
//


// MARK: - Voice Recorder Sheet
import SwiftUI
import SwiftData
import AVFoundation

struct VoiceRecorderSheet: View {
    let onFinish: (URL) -> Void
    let onCancel: () -> Void

    @StateObject private var recorder = VoiceRecorder()
    
    var voiceFeatureTitle:String = "Create Event and Tasks from Voice"
    
    var body: some View {
        VStack(spacing: 20) {
            Capsule().fill(Color.secondary.opacity(0.2)).frame(width: 40, height: 5).padding(.top, 8)

            Text(voiceFeatureTitle).font(.title3.weight(.semibold))
            Text(recorder.formattedElapsed)
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)

            WaveformView(levels: recorder.levels)
                .frame(height: 80)
                .padding(.horizontal, 16)

            Button(action: {
                switch recorder.state {
                case .recording:
                    recorder.pause()
                case .paused, .idle:
                    try? recorder.start()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(recorder.isRecording ? Color.red.opacity(0.18) : Color.gray.opacity(0.12))
                        .frame(width: 120, height: 120)
                        .scaleEffect(recorder.isRecording ? 1.06 : 1.0)
                        .animation(recorder.isRecording ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default, value: recorder.isRecording)

                    Image(systemName:
                        recorder.isRecording ? "pause.fill" :    // show pause while recording
                        (recorder.isPaused ? "play.fill" : "mic.fill") // play to resume, mic for first start
                    )
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(recorder.isRecording ? .red : .accentColor)
                }
            }
            .buttonStyle(.plain)


            HStack {
                Button("Cancel") {
                    recorder.cancelAndDelete()
                    onCancel()
                }.foregroundColor(.secondary)
                Spacer()
                Button("Use Recording") {
                    if let url = recorder.fileURL {
                        recorder.stop()
                        onFinish(url)
                    }
                }
                .disabled(!recorder.hasAudio)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .onDisappear { recorder.stop() }
        .presentationDetents([.medium, .large])
    }
}




// MARK: - Waveform + Recorder

struct WaveformView: View {
    let levels: [CGFloat] // 0...1
    var body: some View {
        GeometryReader { geo in
            let count = max(levels.count, 1)
            let barWidth = max(2.0, geo.size.width / CGFloat(max(count, 40)) * 0.7)
            let spacing = max(1.0, barWidth * 0.4)
            HStack(alignment: .center, spacing: spacing) {
                ForEach(levels.indices, id: \.self) { i in
                    let h = max(4, levels[i] * geo.size.height)
                    Capsule().fill(Color.accentColor.opacity(0.85))
                        .frame(width: barWidth, height: h)
                        .animation(.linear(duration: 0.1), value: levels)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
    }
}

@MainActor
final class VoiceRecorder: ObservableObject {
    //@Published var isRecording = false
    @Published var levels: [CGFloat] = []
    @Published var elapsed: TimeInterval = 0

    private let engine = AVAudioEngine()
    private var file: AVAudioFile?
    private(set) var fileURL: URL?
    private var framesWritten: AVAudioFramePosition = 0
    private var startDate: Date?
    private var timer: Timer?

    private let targetFormat = AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1)!
    private let bufferSize: AVAudioFrameCount = 2048
    private let maxBars = 60
    
    enum RecordingState { case idle, recording, paused }

    @Published var state: RecordingState = .idle
    var isRecording: Bool { state == .recording }
    var isPaused: Bool { state == .paused }

    // Keep the HW format and elapsed across pauses
    private var inputFormat: AVAudioFormat?
    private var elapsedAccum: TimeInterval = 0

    var hasAudio: Bool { framesWritten > 0 }
    var formattedElapsed: String {
        let s = Int(elapsed)
        return String(format: "%02d:%02d", s/60, s%60)
    }


    func start() throws {
        // Resume if paused; create new file only if idle
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try session.setActive(true)

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        if inputFormat == nil { inputFormat = format }

        if state == .idle || file == nil || fileURL == nil {
            // fresh recording
            let tmp = FileManager.default.temporaryDirectory
            fileURL = tmp.appendingPathComponent(UUID().uuidString).appendingPathExtension("wav")
            file = try AVAudioFile(forWriting: fileURL!, settings: format.settings)
            framesWritten = 0
            elapsedAccum = 0
            levels.removeAll()
        }

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, _ in
            guard let self = self else { return }
            self.write(buffer: buffer)          // increments framesWritten
            self.captureLevel(buffer: buffer)
        }

        engine.prepare()
        try engine.start()

        startDate = Date()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self else { return }
            let base = self.elapsedAccum
            let nowPart = self.startDate.map { Date().timeIntervalSince($0) } ?? 0
            self.elapsed = base + nowPart
        }

        state = .recording
    }
    
    func pause() {
        guard state == .recording else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        if let start = startDate { elapsedAccum += Date().timeIntervalSince(start) }
        timer?.invalidate(); timer = nil
        startDate = nil
        state = .paused
    }




    func stop() {
        guard state != .idle else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        if let start = startDate { elapsedAccum += Date().timeIntervalSince(start) }
        timer?.invalidate(); timer = nil
        startDate = nil
        state = .idle
        try? AVAudioSession.sharedInstance().setActive(false)
    }


    func cancelAndDelete() {
        stop()
        if let url = fileURL { try? FileManager.default.removeItem(at: url) }
        file = nil; fileURL = nil
        framesWritten = 0
        levels.removeAll()
        elapsed = 0
        elapsedAccum = 0
        state = .idle
    }


    private func write(buffer: AVAudioPCMBuffer) {
        do { try file?.write(from: buffer); framesWritten += AVAudioFramePosition(buffer.frameLength) }
        catch { stop(); print("Audio write error:", error.localizedDescription) }
    }

    private func captureLevel(buffer: AVAudioPCMBuffer) {
        guard let ptr = buffer.floatChannelData?.pointee else { return }
        let n = Int(buffer.frameLength); if n == 0 { return }
        var sum: Float = 0; for i in 0..<n { let x = ptr[i]; sum += x*x }
        let rms = sqrt(sum / Float(max(n, 1)))
        let db = 20 * log10(rms + 1e-7)
        let norm = max(0, min(1, (db + 60) / 60))
        DispatchQueue.main.async {
            self.levels.append(CGFloat(norm))
            if self.levels.count > self.maxBars { self.levels.removeFirst(self.levels.count - self.maxBars) }
        }
    }
}
