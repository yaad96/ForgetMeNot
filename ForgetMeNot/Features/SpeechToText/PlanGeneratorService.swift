//
//  PlanGeneratorService.swift
//  ForgetMeNot
//
//  Created by Mainul Hossain on 8/19/25.
//


import Foundation

struct PlanGeneratorService {
    let apiKey: String
    var model = "gpt-4o-mini"

    func generate(from transcript: String) async throws -> PlanFromTranscript {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        let tz = TimeZone.current.identifier
        let nowISO = ISO8601DateFormatter().string(from: Date())

        let systemPrompt = """
        You extract a travel plan from user text.
        Return ONLY strict JSON with fields: "title", "date", "reminder_date", "tasks".
        - "date" and "reminder_date" must be ISO8601 with timezone offset.
        - "tasks" is an array of short strings.
        Use timezone=\(tz) and now=\(nowISO) for relative times.
        """

        let userPrompt = """
        Transcript:
        \"\"\"\(transcript)\"\"\"\n
        Output only JSON. No prose. No markdown.
        """

        let payload: [String: Any] = [
            "model": model,
            "response_format": ["type": "json_object"],
            "temperature": 0.2,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ]
        ]

        var req = URLRequest(url: url)
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
