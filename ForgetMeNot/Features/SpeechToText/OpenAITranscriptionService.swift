//
//  OpenAITranscriptionService.swift
//  ForgetMeNot
//
//  Created by Mainul Hossain on 8/19/25.
//


import Foundation

struct OpenAITranscriptionService {
    let apiKey: String
    var model = "whisper-1" // swap if desired

    func transcribe(fileURL: URL) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let boundary = "Boundary-\(UUID().uuidString)"
        request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func append(_ s: String) { body.append(s.data(using: .utf8)!) }

        // model
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        append("\(model)\r\n")

        // file
        let filename = fileURL.lastPathComponent.isEmpty ? "audio.wav" : fileURL.lastPathComponent
        let mime = filename.lowercased().hasSuffix(".m4a") ? "audio/m4a" : "audio/wav"
        let fileData = try Data(contentsOf: fileURL)

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: \(mime)\r\n\r\n")
        body.append(fileData)
        append("\r\n")
        append("--\(boundary)--\r\n")
        request.httpBody = body

        let (data, resp) = try await URLSession.shared.data(for: request)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "OpenAI", code: (resp as? HTTPURLResponse)?.statusCode ?? -1,
                          userInfo: [NSLocalizedDescriptionKey: String(data: data, encoding: .utf8) ?? "Unknown"])
        }
        struct R: Decodable { let text: String }
        return try JSONDecoder().decode(R.self, from: data).text
    }
}
