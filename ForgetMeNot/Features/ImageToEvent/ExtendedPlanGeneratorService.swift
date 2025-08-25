// In PlanGeneratorService.swift

import UIKit

extension PlanGeneratorService {
    func generate(from image: UIImage) async throws -> PlanFromTranscript {
        // Resize and JPEG-encode to avoid huge payloads
        let maxDim: CGFloat = 1024
        let scale = min(1, maxDim / max(image.size.width, image.size.height))
        let size = CGSize(width: floor(image.size.width * scale), height: floor(image.size.height * scale))
        let renderer = UIGraphicsImageRenderer(size: size)
        let scaled = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        guard let jpeg = scaled.jpegData(compressionQuality: 0.75) else {
            throw NSError(domain: "PlanGen", code: 1, userInfo: [NSLocalizedDescriptionKey: "Image encode failed"])
        }
        let b64 = jpeg.base64EncodedString()

        let tz = TimeZone.current.identifier
        let nowISO = ISO8601DateFormatter().string(from: Date())

        let systemPrompt = """
        You extract a personal travel or event plan from a single photo.
        Return ONLY strict JSON with fields: "title", "date", "reminder_date", "tasks".
        - "date" and "reminder_date" must be ISO8601 with timezone offset.
        - "tasks" is an array of short strings.
        Use timezone=\(tz) and now=\(nowISO) when the image does not provide an explicit date.
        Infer intent and vibe from visible cues (posters, menus, tickets, invites, venues, attire).
        """

        let userPrompt = """
        From this photo, infer a suitable event title, an event date, a reminder date before the event, and a short checklist of prep tasks.
        Output only JSON. No prose. No markdown.
        """

        let payload: [String: Any] = [
            "model": model,
            "response_format": ["type": "json_object"],
            "temperature": 0.2,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user",
                 "content": [
                    ["type": "text", "text": userPrompt],
                    ["type": "image_url",
                     "image_url": ["url": "data:image/jpeg;base64,\(b64)"]
                    ]
                 ]
                ]
            ]
        ]

        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        req.httpMethod = "POST"
        req.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "OpenAI", code: (resp as? HTTPURLResponse)?.statusCode ?? -1,
                          userInfo: [NSLocalizedDescriptionKey: String(data: data, encoding: .utf8) ?? "Unknown"])
        }

        struct Envelope: Decodable {
            struct Choice: Decodable { struct Message: Decodable { let content: String }; let message: Message }
            let choices: [Choice]
        }
        let env = try JSONDecoder().decode(Envelope.self, from: data)
        let content = env.choices.first?.message.content ?? "{}"
        return try JSONDecoder().decode(PlanFromTranscript.self, from: Data(content.utf8))
    }
}

