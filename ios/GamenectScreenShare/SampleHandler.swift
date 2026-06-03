//
//  SampleHandler.swift
//  GamenectScreenShare
//

import ReplayKit
import AgoraReplayKitExtension

import os.log

class SampleHandler: RPBroadcastSampleHandler, AgoraReplayKitExtDelegate {

    private let agoraExt = AgoraReplayKitExt.shareInstance()
    private let customLog = OSLog(subsystem: "com.example.gamenectNew.GamenectScreenShare", category: "ScreenShare")

    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        os_log("GamenectScreenShare: broadcastStarted called", log: customLog, type: .default)
        // App Group được cấu hình qua Info.plist key RTCAppGroupIdentifier
        agoraExt.start(self)
        os_log("GamenectScreenShare: agoraExt.start() executed", log: customLog, type: .default)
    }

    override func broadcastPaused() {
        os_log("GamenectScreenShare: broadcastPaused", log: customLog, type: .default)
        agoraExt.pause()
    }

    override func broadcastResumed() {
        os_log("GamenectScreenShare: broadcastResumed", log: customLog, type: .default)
        agoraExt.resume()
    }

    override func broadcastFinished() {
        os_log("GamenectScreenShare: broadcastFinished", log: customLog, type: .default)
        agoraExt.stop()
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        agoraExt.push(sampleBuffer, with: sampleBufferType)
    }

    // MARK: - AgoraReplayKitExtDelegate

    func broadcastFinished(_ ext: AgoraReplayKitExt, reason: AgoraReplayKitExtReason) {
        os_log("GamenectScreenShare: broadcastFinished delegate with reason: %d", log: customLog, type: .error, reason.rawValue)
        let error = NSError(
            domain: "com.example.gamenectNew.GamenectScreenShare",
            code: Int(reason.rawValue),
            userInfo: [NSLocalizedFailureReasonErrorKey: "Agora ReplayKit Extension stopped, reason: \(reason.rawValue)"]
        )
        finishBroadcastWithError(error)
    }
}
