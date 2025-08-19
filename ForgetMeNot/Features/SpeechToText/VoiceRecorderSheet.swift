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

    var body: some View {
        VStack(spacing: 20) {
            Capsule().fill(Color.secondary.opacity(0.2)).frame(width: 40, height: 5).padding(.top, 8)

            Text("Create Plan from Voice").font(.title3.weight(.semibold))
            Text(recorder.formattedElapsed)
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)

            WaveformView(levels: recorder.levels)
                .frame(height: 80)
                .padding(.horizontal, 16)

            Button(action: {
                recorder.isRecording ? recorder.stop() : (try? recorder.start())
            }) {
                ZStack {
                    Circle()
                        .fill(recorder.isRecording ? Color.red.opacity(0.18) : Color.gray.opacity(0.12))
                        .frame(width: 120, height: 120)
                        .scaleEffect(recorder.isRecording ? 1.06 : 1.0)
                        .animation(recorder.isRecording ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default, value: recorder.isRecording)
                    Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
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
    @Published var isRecording = false
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

    var hasAudio: Bool { framesWritten > 0 }
    var formattedElapsed: String {
        let s = Int(elapsed); return String(format: "%02d:%02d", s/60, s%60)
    }

    func start() throws {
        guard !isRecording else { return }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try session.setActive(true)

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0) // <- use the HW format (48 kHz in your log)

        // Create WAV file that matches the input format
        let tmp = FileManager.default.temporaryDirectory
        fileURL = tmp.appendingPathComponent(UUID().uuidString).appendingPathExtension("wav")
        file = try AVAudioFile(forWriting: fileURL!, settings: inputFormat.settings)

        // IMPORTANT: install tap with the same format as the node (or pass nil)
        input.removeTap(onBus: 0)
        // fix
        input.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            self.write(buffer: buffer)          // <-- increments framesWritten
            self.captureLevel(buffer: buffer)
        }


        engine.prepare()
        try engine.start()

        framesWritten = 0
        startDate = Date()
        elapsed = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self, let start = self.startDate else { return }
            self.elapsed = Date().timeIntervalSince(start)
        }
        isRecording = true
    }


    func stop() {
        guard isRecording else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        timer?.invalidate(); timer = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    func cancelAndDelete() {
        stop()
        if let url = fileURL { try? FileManager.default.removeItem(at: url) }
        file = nil; fileURL = nil; framesWritten = 0; levels.removeAll(); elapsed = 0
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
