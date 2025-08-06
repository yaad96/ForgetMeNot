import Foundation

struct APIKeyLoader {
    static var openAIKey: String {
        guard
            let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
            let key = dict["OPENAI_API_KEY"] as? String
        else {
            fatalError("OpenAI API key not found in Secrets.plist!")
        }
        return key
    }
}

