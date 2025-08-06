import Foundation

struct OpenAIResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

struct OpenAIPlanResponse: Decodable {
    let notification_date: String
    let tasks: [String]
}

func fetchPlanSuggestionOpenAI(
    eventTitle: String,
    eventDate: Date,
    eventDescription: String?,
    completion: @escaping (OpenAIPlanResponse?) -> Void // <--- Note type here!
) {
    let apiKey = APIKeyLoader.openAIKey
    let url = URL(string: "https://api.openai.com/v1/chat/completions")!
    let formatter = ISO8601DateFormatter()
    let dateString = formatter.string(from: eventDate)
    let userPrompt = """
    I have an event.

    Event Title: \(eventTitle)
    Date: \(dateString)
    Event Description: \(eventDescription ?? "")

    Importance of Notification Date:
    The notification date is critical. Assume the user will only start preparing for this event *after* they receive the notification. Choose a notification date that allows enough time for the user to complete all important preparation tasks, especially if the event requires significant planning or travel.

    Please suggest a good notification date (in ISO8601 format) and a list of travel tasks
    complete before the event. Return your answer as a JSON object exactly like below:
    
    {
      "notification_date": "...",
      "tasks": ["task1", "task2", ...]
    }
    """

    
    //print("User Prompt", userPrompt)

    let payload: [String: Any] = [
        "model": "gpt-3.5-turbo",
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
        guard let data = data else {
            print("API error: \(error?.localizedDescription ?? "Unknown error")")
            completion(nil)
            return
        }
        

        do {
            // Decode the OpenAI envelope
            let envelope = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            let content = envelope.choices.first?.message.content ?? ""
            //print("Extracted content block:\n\(content)")
            // Remove any markdown fences or whitespace
            let trimmed = content
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")

            //print("Final JSON string being parsed:\n\(trimmed)")

            // Now decode your actual plan JSON (as OpenAIPlanResponse!)
            if let jsonData = trimmed.data(using: .utf8) {
                let decoded = try JSONDecoder().decode(OpenAIPlanResponse.self, from: jsonData)
                //print("Parsed OpenAIPlanResponse:\n\(decoded)")
                completion(decoded)
            } else {
                //print("Could not convert plan content to Data")
                completion(nil)
            }
        } catch {
            print("Parsing error: \(error)")
            completion(nil)
        }
    }
    task.resume()
}

