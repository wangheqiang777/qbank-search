import AVFoundation
import AVKit
import ReplayKit
import UIKit
import Flutter

private let APP_GROUP_ID = "group.com.qbank.search"
private let EXT_BUNDLE_ID = "com.example.qbankSearch.broadcast"
private let CHANNEL_NAME = "qbank/scan"

/// 题库条目（Flutter 在开始扫描时序列化为 bank.json 写入 App Group）
private struct QBankItem: Codable {
    let q: String
    let a: String
    let opts: String
    let type: String
}

private struct AnswerResult {
    let score: Double
    let item: QBankItem?
}

/// 静音 WAV（0.2s / 8kHz / 8bit），用于后台保活：
/// 开启后台音频会话并循环播放，让主 App 在切到考试 App 后仍保持活跃，
/// 轮询定时器才能持续把扩展识别到的题目匹配成答案刷新到 PiP。
private let SILENT_WAV_BASE64 =
    "UklGRmQGAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YUAGAAAAAAAAAAAAAAAAAAAA" +
    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"

/// 录屏搜题桥接：连接 Flutter（开始/停止/题库）与 iOS 原生能力（广播选择器、PiP、轮询匹配）。
final class ScanBridge: NSObject, AVPictureInPictureControllerDelegate {

    static let shared = ScanBridge()

    private var channel: FlutterMethodChannel?
    private var pipController: AVPictureInPictureController?
    private var pipVC: AVPictureInPictureVideoCallViewController?
    private var answerView: PipAnswerView?

    private var timer: Timer?
    private var lastOcrHash: Int = 0
    private var bank: [QBankItem] = []

    private var audioPlayer: AVAudioPlayer?
    private var broadcastPicker: RPSystemBroadcastPickerView?

    // MARK: - Setup

    func setup(_ messenger: FlutterBinaryMessenger) {
        let ch = FlutterMethodChannel(name: CHANNEL_NAME, binaryMessenger: messenger)
        channel = ch
        ch.setMethodCallHandler { [weak self] call, result in
            self?.handle(call: call, result: result)
        }
    }

    private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "prepareBank":
            if let json = call.arguments as? String { writeBank(json) }
            result(nil)
        case "startScan":
            startScan()
            result(nil)
        case "stopScan":
            stopScan()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - App Group helpers

    private func appGroupURL() -> URL? {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: APP_GROUP_ID)
    }

    private func writeBank(_ json: String) {
        guard let url = appGroupURL()?.appendingPathComponent("bank.json") else { return }
        try? json.write(to: url, atomically: true, encoding: .utf8)
    }

    private func readOcr() -> String? {
        guard let url = appGroupURL()?.appendingPathComponent("ocr_latest.txt") else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    // MARK: - Start / Stop

    private func startScan() {
        loadBank()
        startKeepAliveAudio()
        setupPipIfAvailable()
        presentBroadcastPicker()
        startPolling()
        answerView?.showEmpty()
    }

    private func stopScan() {
        timer?.invalidate()
        timer = nil
        stopKeepAliveAudio()
        if #available(iOS 15.0, *), let pip = pipController, pip.isPictureInPictureActive {
            pip.stopPictureInPicture()
        }
        pipController = nil
        pipVC = nil
        broadcastPicker?.removeFromSuperview()
        broadcastPicker = nil
    }

    // MARK: - Bank loading + matching

    private func loadBank() {
        guard let url = appGroupURL()?.appendingPathComponent("bank.json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [QBankItem]].self, from: data) else {
            bank = []
            return
        }
        bank = decoded["questions"] ?? []
    }

    private func match(_ query: String) -> AnswerResult {
        let nq = Self.normalize(query)
        guard !nq.isEmpty, !bank.isEmpty else { return AnswerResult(score: 0, item: nil) }
        let nb = Self.bigrams(nq)
        var best = AnswerResult(score: 0, item: nil)
        for item in bank {
            let n = Self.normalize(item.q)
            guard !n.isEmpty else { continue }
            let s: Double
            if n.contains(nq) {
                s = 1.0
            } else if n.count >= 8 && nq.contains(n) {
                s = 0.99
            } else {
                s = Self.similarity(nb, Self.bigrams(n))
            }
            if s > best.score { best = AnswerResult(score: s, item: item) }
        }
        return best
    }

    // MARK: - Polling

    private func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    private func poll() {
        guard let text = readOcr(), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let h = text.hashValue
        if h == lastOcrHash { return }
        lastOcrHash = h
        let res = match(text)
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let view = self.answerView else { return }
            if let item = res.item {
                var highlight = Set<String>()
                for ch in item.a.uppercased() where ch >= "A" && ch <= "E" { highlight.insert(String(ch)) }
                let opts = Self.parseOptions(item.opts)
                view.configure(title: item.q, answer: item.a, options: opts, highlight: highlight)
            } else {
                view.configure(title: text.prefix(40).description, answer: "", options: [], highlight: [])
            }
        }
    }

    // MARK: - PiP (iOS 15+)

    @available(iOS 15.0, *)
    private func setupPipIfAvailable() {
        guard AVPictureInPictureController.isPictureInPictureSupported() else { return }
        let vc = AVPictureInPictureVideoCallViewController()
        vc.preferredContentSize = CGSize(width: 320, height: 220)
        let view = PipAnswerView(frame: CGRect(x: 0, y: 0, width: 320, height: 220))
        vc.view.addSubview(view)
        answerView = view
        let source = AVPictureInPictureController.ContentSource(
            activeVideoCallSourceView: vc.view,
            contentViewController: vc
        )
        let pip = AVPictureInPictureController(contentSource: source)
        pip.canStartPictureInPictureAutomaticallyFromInline = true
        pip.delegate = self
        pipController = pip
        pipVC = vc
        pip.startPictureInPicture()
    }

    // MARK: - Broadcast picker

    private func presentBroadcastPicker() {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        if #available(iOS 14.0, *) { picker.preferredExtension = EXT_BUNDLE_ID }
        // 找到内部 UIButton 并触发，弹出系统「开始直播」确认框
        for subview in picker.subviews {
            if let button = subview as? UIButton {
                button.sendActions(for: .touchUpInside)
                break
            }
        }
        broadcastPicker = picker
        if let window = UIApplication.shared.windows.first {
            picker.center = CGPoint(x: -200, y: -200)
            window.addSubview(picker)
        }
    }

    // MARK: - Background keep-alive audio

    private func startKeepAliveAudio() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { }
        guard let data = Data(base64Encoded: SILENT_WAV_BASE64),
              let player = try? AVAudioPlayer(data: data) else { return }
        player.numberOfLoops = -1
        player.volume = 0.001
        player.play()
        audioPlayer = player
    }

    private func stopKeepAliveAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Text similarity (移植自 Dart search.dart)

    private static func normalize(_ s: String) -> String {
        let lower = s.lowercased()
        let allowed = CharacterSet(charactersIn: "0123456789abcdefghijklmnopqrstuvwxyz")
        return lower.components(separatedBy: allowed.inverted).joined()
    }

    private static func bigrams(_ s: String) -> Set<String> {
        if s.isEmpty { return [] }
        if s.count == 1 { return [String(s)] }
        var set = Set<String>()
        let chars = Array(s)
        for i in 0..<chars.count - 1 { set.insert(String(chars[i...i + 1])) }
        return set
    }

    private static func similarity(_ a: Set<String>, _ b: Set<String>) -> Double {
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        let inter = Double(a.intersection(b).count)
        if inter == 0 { return 0 }
        let jac = inter / Double(a.count + b.count - Int(inter))
        let containment = inter / Double(b.count)
        return max(jac, containment * 0.95)
    }

    private static func parseOptions(_ raw: String) -> [String] {
        guard let data = raw.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [Any] else { return [] }
        return arr.map { String(describing: $0) }
    }
}
