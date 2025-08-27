import EventKit
import Foundation
import UIKit
import SwiftUI

extension Bundle {
    var displayName: String {
        // Prefer localized CFBundleDisplayName, then fall back sensibly
        localizedInfoDictionary?["CFBundleDisplayName"] as? String ??
        infoDictionary?["CFBundleDisplayName"] as? String ??
        localizedInfoDictionary?["CFBundleName"] as? String ??
        infoDictionary?["CFBundleName"] as? String ??
        "App"
    }
}



enum ImagePickerSheet: Identifiable {
    case camera, photoLibrary
    var id: Int { hashValue }
}




// Utility: Get device model identifier (e.g., "iPhone14,2" for iPhone 13 Pro)
func getDeviceModelIdentifier() -> String {
    var systemInfo = utsname()
    uname(&systemInfo)
    return withUnsafePointer(to: &systemInfo.machine) {
        $0.withMemoryRebound(to: CChar.self, capacity: 1) {
            String(validatingUTF8: $0) ?? "unknown"
        }
    }
}

// List of A15+, M1+, and newer device identifiers (extend as Apple releases more!)
let supportedDeviceIdentifiers: Set<String> = [
    // iPhone 13 series (A15)
    "iPhone14,5", // iPhone 13
    "iPhone14,2", // iPhone 13 Pro
    "iPhone14,3", // iPhone 13 Pro Max
    "iPhone14,4", // iPhone 13 mini
    // iPhone 14 series (A15/A16)
    "iPhone14,7", // iPhone 14
    "iPhone14,8", // iPhone 14 Plus
    "iPhone15,2", // iPhone 14 Pro
    "iPhone15,3", // iPhone 14 Pro Max
    // iPhone 15 series (A16/A17)
    "iPhone15,4", "iPhone15,5", // iPhone 15/15 Plus
    "iPhone16,1", "iPhone16,2", // iPhone 15 Pro/Pro Max
    // iPad Air 5th gen (M1)
    "iPad13,1", "iPad13,2",
    // iPad Pro 11" 3rd, 4th gen (M1/M2)
    "iPad13,4", "iPad13,5", "iPad13,6", "iPad13,7", // 11" 3rd gen (M1)
    "iPad14,3", "iPad14,4", // 11" 4th gen (M2)
    // iPad Pro 12.9" 5th, 6th gen (M1/M2)
    "iPad13,8", "iPad13,9", "iPad13,10", "iPad13,11", // 12.9" 5th gen (M1)
    "iPad14,5", "iPad14,6", // 12.9" 6th gen (M2)
    // Apple Silicon Macs (all M1/M2/M3 so far)
    // Just check for "Mac" in identifier for future-proofing.
]

func deviceSupportsLLM() -> Bool {
    let identifier = getDeviceModelIdentifier()
    // Macs with Apple Silicon
    if identifier.lowercased().contains("mac") {
        return true
    }
    return supportedDeviceIdentifiers.contains(identifier)
}

struct PlanSuggestion {
    var reminderDate: Date
    var tasks: [EventTask]
}

@ViewBuilder
func PlanTitleField(_ planName: Binding<String>) -> some View {
    TextField("Give your plan a name...", text: planName)
        .padding(.vertical, 11)
        .padding(.horizontal, 18)
        .font(.system(size: 18, weight: .medium))
        .background(
            Capsule().fill(Color(.systemGray6).opacity(0.96))
        )
        .overlay(
            Capsule().stroke(Color.gray.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.01), radius: 1, y: 1)
        .padding(.horizontal, 2)
}









