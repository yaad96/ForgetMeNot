import Foundation
import SwiftData
import UIKit

@Model
class SubjectImage: Identifiable {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var data: Data

    init(data: Data, timestamp: Date = .now, id: UUID = .init()) {
        self.id = id
        self.data = data
        self.timestamp = timestamp
    }

    /// Helper to load thumbnail
    var thumbnail: UIImage? {
        guard let img = UIImage(data: data) else { return nil }
        let maxSide: CGFloat = 60
        let scale = min(maxSide / max(img.size.width, img.size.height), 1)
        let newSize = CGSize(width: img.size.width * scale, height: img.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { ctx in
            UIColor.systemBackground.setFill()
            ctx.fill(CGRect(origin: .zero, size: newSize))
            img.draw(in: CGRect(origin: .zero, size: newSize))
        }

    }

}

