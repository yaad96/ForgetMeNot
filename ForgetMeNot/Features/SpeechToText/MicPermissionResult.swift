//
//  MicPermissionResult.swift
//  ForgetMeNot
//
//  Created by Mainul Hossain on 8/19/25.
//


import AVFAudio
import Foundation

enum MicPermissionResult { case granted, denied }

struct MicPermissionService {
    func request() async -> MicPermissionResult {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        return await withCheckedContinuation { cont in
            session.requestRecordPermission { ok in
                cont.resume(returning: ok ? .granted : .denied)
            }
        }
    }
}
