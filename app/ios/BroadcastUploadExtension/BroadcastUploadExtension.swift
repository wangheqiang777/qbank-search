import ReplayKit
import Vision
import CoreMedia
import UIKit

/// 广播上传扩展：系统把屏幕视频帧实时喂到这里（独立进程，录屏期间一直活着）。
/// 只做 OCR + 写共享区，不做匹配——匹配在主 App 的 PiP 悬浮窗里做。
class SampleHandler: RPBroadcastSampleHandler {

    private let appGroupID = "group.com.qbank.search"
    private var textRequest: VNRecognizeTextRequest!
    private var lastOcrTime: TimeInterval = 0

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLanguages = ["zh-Hans", "en-US"]
        textRequest.usesLanguageCorrection = true
        textRequest.minimumTextHeight = 0.02
    }

    override func broadcastFinished() {
        textRequest = nil
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleType: RPSampleBufferType) {
        // 只看视频帧
        guard sampleType == .video else { return }

        // 节流：至少间隔 1 秒，避免每帧都跑 OCR 烧电
        let now = Date().timeIntervalSince1970
        guard now - lastOcrTime >= 1.0 else { return }
        lastOcrTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        guard let request = self.textRequest else { return }
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return
        }

        guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
        var text = ""
        for obs in observations {
            if let cand = obs.topCandidates(1).first {
                text += cand.string + "\n"
            }
        }
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return }
        writeOcr(text)
    }

    private func writeOcr(_ text: String) {
        guard let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("ocr_latest.txt") else { return }
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }
}
