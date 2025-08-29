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
         You extract a single event plan from user text.
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
         - Use timezone=\(tz) and now=\(nowISO) for resolving relative phrases.
         - First infer the event "date". Then resolve any task-level reminder phrases relative to that event date when the phrase depends on it, for example "the night before" or "2 hours before the event".
         - If a task gets a specific cue like "remind me", "by Tuesday 5pm", "tomorrow morning", "night before", "two hours before flight", set "reminder_at" for that task.
         - If there is no clear cue for a task, set "reminder_at" = null.
         - Clamp reminder_at to [now, event date]. If it falls outside, set it to null.
         - Heuristics for vague times when no clock time is given:
             "morning" → 09:00, "noon" → 12:00, "afternoon" → 14:00,
             "evening" → 19:00, "night" → 21:00, "night before" → event_date-1 at 20:00.
             "by <weekday>" → 17:00 on that weekday unless time is specified.
             "<X> hours before" → event_date minus X hours.
         - Output only JSON. No prose, no markdown.
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
