import AVFoundation
import Combine
import Foundation

/// 播放器 + 弹幕时间轴
final class PlayerModel: ObservableObject {
    let player = AVPlayer()

    @Published var isPlaying = false
    @Published var duration: TimeInterval = 0
    @Published var currentTimeText: String = "00:00"
    @Published var danmaku: [Danmaku] = []
    @Published var statusText: String = ""
    @Published var videoName: String = ""
    @Published var hasVideo: Bool = false
    @Published var isLoadingDanmaku: Bool = false

    /// 高频更新，故意不进 @Published，靠 TimelineView 刷新
    private(set) var currentTime: TimeInterval = 0

    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var lastTextUpdate: TimeInterval = 0

    init() {
        addObservers()
    }

    deinit {
        if let o = timeObserver { player.removeTimeObserver(o) }
        if let e = endObserver { NotificationCenter.default.removeObserver(e) }
    }

    private func addObservers() {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.05, preferredTimescale: 600),
            queue: .main
        ) { [weak self] t in
            guard let self else { return }
            let seconds = CMTimeGetSeconds(t)
            guard seconds.isFinite else { return }
            self.currentTime = seconds
            if seconds - self.lastTextUpdate > 0.4 {
                self.lastTextUpdate = seconds
                self.currentTimeText = Self.format(seconds)
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isPlaying = false
        }
    }

    func load(url: URL) {
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        videoName = url.lastPathComponent
        hasVideo = true
        danmaku = []
        statusText = ""
        currentTime = 0

        Task {
            let d = try? await item.asset.load(.duration)
            let seconds = d.map { CMTimeGetSeconds($0) } ?? 0
            await MainActor.run {
                self.duration = seconds.isFinite ? seconds : 0
            }
        }
        play()
    }

    func play() {
        player.play()
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func togglePlay() {
        isPlaying ? pause() : play()
    }

    func seek(to seconds: TimeInterval) {
        let target = CMTime(seconds: max(0, seconds), preferredTimescale: 600)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = seconds
    }

    func step(_ delta: TimeInterval) {
        seek(to: currentTime + delta)
    }

    static func format(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "00:00" }
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }
}
