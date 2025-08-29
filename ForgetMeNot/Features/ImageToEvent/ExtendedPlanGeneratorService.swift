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
        Return ONLY strict JSON with fields:
        {
          "title": string,
          "date": ISO8601 datetime with timezone,
          "reminder_date": ISO8601 datetime with timezone,
          "tasks": [
            { "title": string, "reminder_at": ISO8601 datetime with timezone or null }
          ]
        }

        Rules:
        - Use timezone=\(tz) and now=\(nowISO).
        - First infer the event "date". Then resolve any task-level reminder phrases relative to that event date when needed,
          for example "night before", "2 hours before", etc.
        - If a task has a clear cue like "remind me", "by Tuesday 5pm", "tomorrow morning", "night before", set reminder_at.
        - If no clear cue, set reminder_at = null.
        - Clamp reminder_at to [now, event date]. If outside, set to null.
        - Heuristics when no clock time is given:
          "morning" → 09:00, "noon" → 12:00, "afternoon" → 14:00,
          "evening" → 19:00, "night" → 21:00, "night before" → event_date-1 at 20:00,
          "by <weekday>" → 17:00 that weekday unless a time is specified,
          "<X> hours before" → event_date minus X hours.
        - Output only JSON. No prose. No markdown.
        """


        let userPrompt = """
        From this photo, infer a suitable event title, an event date, a reminder date before the event, and a short checklist of prep tasks with appropriate task reminder dates.
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

