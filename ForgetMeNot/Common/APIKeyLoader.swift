import Foundation

struct APIKeyLoader {
    static var openAIKey: String? {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let key = dict["OPENAI_API_KEY"] as? String else { return nil }
        return key
    }
}
