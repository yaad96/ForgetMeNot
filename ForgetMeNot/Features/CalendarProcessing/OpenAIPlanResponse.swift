import Foundation

struct OpenAIPlanResponse: Decodable {
    let notification_date: String
    let tasks: [String]
}

func fetchPlanSuggestionOpenAI(
    eventTitle: String,
    eventDate: Date,
    eventDescription: String?,
    completion: @escaping (OpenAIPlanResponse?) -> Void
) {
    let apiKey = "sk-..." // Your OpenAI API key here
    let url = URL(string: "https://api.openai.com/v1/chat/completions")!
    let formatter = ISO8601DateFormatter()
    let dateString = formatter.string(from: eventDate)
    let userPrompt = """
    I have an event called "\(eventTitle)" on \(dateString). \(eventDescription ?? "")
    Please suggest a good notification date (in ISO8601 format) and a list of travel tasks to complete before the event. Return your answer as a JSON object like:
    { "notification_date": "...", "tasks": ["task1", "task2", ...] }
    """

    let payload: [String: Any] = [
        "model": "gpt-3.5-turbo", // or "gpt-4o"
        "messages": [
            ["role": "system", "content": "You are a helpful travel planning assistant."],
            ["role": "user", "content": userPrompt]
        ],
        "max_tokens": 400,
        "temperature": 0.5
    ]
    let data = try! JSONSerialization.data(withJSONObject: payload)

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = data

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        guard let data = data,
              let string = String(data: data, encoding: .utf8) else {
            print("API error: \(error?.localizedDescription ?? "Unknown error")")
            completion(nil)
            return
        }
        // Try to find the JSON in the model's response
        if let jsonStart = string.firstIndex(of: "{"),
           let jsonEnd = string.lastIndex(of: "}") {
            let jsonString = String(string[jsonStart...jsonEnd])
            if let jsonData = jsonString.data(using: .utf8) {
                do {
                    let decoded = try JSONDecoder().decode(OpenAIPlanResponse.self, from: jsonData)
                    completion(decoded)
                } catch {
                    print("JSON decode error: \(error)")
                    completion(nil)
                }
            } else {
                completion(nil)
            }
        } else {
            completion(nil)
        }
    }
    task.resume()
}
