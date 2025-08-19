//
//  PlanFromTranscript.swift
//  ForgetMeNot
//
//  Created by Mainul Hossain on 8/19/25.
//


import Foundation

public struct PlanFromTranscript: Codable {
    public let title: String
    public let date: String
    public let reminder_date: String
    public let tasks: [String]
}
