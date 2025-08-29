//
//  PlanFromTranscript.swift
//  ForgetMeNot
//
//  Created by Mainul Hossain on 8/19/25.
//


// PlanFromTranscript.swift
import Foundation

public struct PlanFromTranscript: Codable {
    public struct Task: Codable {
        public let title: String
        public let reminder_at: String? // ISO8601 with timezone, or nil

        public init(title: String, reminder_at: String? = nil) {
            self.title = title
            self.reminder_at = reminder_at
        }
    }

    public let title: String
    public let date: String
    public let reminder_date: String
    public let tasks: [Task]

    enum CodingKeys: String, CodingKey {
        case title, date, reminder_date, tasks
    }

    // Backward compatible decoding: accept [Task] or [String]
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.title = try c.decode(String.self, forKey: .title)
        self.date = try c.decode(String.self, forKey: .date)
        self.reminder_date = try c.decode(String.self, forKey: .reminder_date)

        if let items = try? c.decode([Task].self, forKey: .tasks) {
            self.tasks = items
        } else if let strings = try? c.decode([String].self, forKey: .tasks) {
            self.tasks = strings.map { Task(title: $0, reminder_at: nil) }
        } else {
            self.tasks = []
        }
    }
}

