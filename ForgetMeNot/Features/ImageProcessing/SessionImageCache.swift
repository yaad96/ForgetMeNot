//
//  SessionImageCache.swift
//  ForgetMeNot
//
//  Created by Mainul Hossain on 8/4/25.
//


import UIKit

class SessionImageCache {
    static let shared = SessionImageCache()
    private init() {}

    private var cache: [UUID: UIImage] = [:]

    func image(for id: UUID) -> UIImage? {
        cache[id]
    }

    func set(_ image: UIImage, for id: UUID) {
        cache[id] = image
    }

    func clear() {
        cache = [:]
    }
}
