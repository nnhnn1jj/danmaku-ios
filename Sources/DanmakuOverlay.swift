import SwiftUI

/// 弹幕浮层：按播放时间把弹幕画在画面上
struct DanmakuOverlay: View {
    let items: [Danmaku]
    let settings: DanmakuSettings
    let time: () -> TimeInterval

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { _ in
            Canvas { ctx, size in
                guard settings.danmakuEnabled, !items.isEmpty else { return }
                let now = time()
                guard now > 0 else { return }
                let lineHeight = settings.fontSize * 1.6
                let maxLanes = max(1, settings.laneCount)
                let scrollDuration = max(2.0, settings.speed)

                var active: [(Danmaku, Int)] = []
                var i = lowerBound(now - scrollDuration)
                while i < items.count, items[i].time <= now {
                    active.append((items[i], i))
                    i += 1
                }

                for (item, index) in active {
                    let elapsed = now - item.time
                    if elapsed < 0 || elapsed > scrollDuration { continue }

                    let text = Text(item.text)
                        .font(.system(size: settings.fontSize, weight: .semibold))
                        .foregroundColor(settings.unifiedWhite ? .white : color(item.color))

                    let estimatedWidth = CGFloat(item.text.count) * settings.fontSize * 0.98

                    if item.mode == 5 && settings.showTop {
                        // 顶部固定 4 秒
                        let visible = elapsed < 4
                        guard visible else { continue }
                        let lane = index % min(maxLanes, 3)
                        ctx.opacity = settings.opacity * (elapsed > 3 ? (4 - elapsed) : 1)
                        ctx.draw(text, at: CGPoint(x: size.width / 2, y: lineHeight * CGFloat(lane + 1) - lineHeight / 2),
                                 anchor: .center)
                        ctx.opacity = 1
                    } else if item.mode == 4 {
                        // 底部固定 4 秒
                        let visible = elapsed < 4
                        guard visible else { continue }
                        let lane = index % 2
                        ctx.opacity = settings.opacity * (elapsed > 3 ? (4 - elapsed) : 1)
                        ctx.draw(text,
                                 at: CGPoint(x: size.width / 2,
                                             y: size.height - lineHeight * CGFloat(lane + 1) + lineHeight / 2),
                                 anchor: .center)
                        ctx.opacity = 1
                    } else {
                        let progress = elapsed / scrollDuration
                        let x = size.width - CGFloat(progress) * (size.width + estimatedWidth)
                        let lane = index % maxLanes
                        let y = lineHeight * CGFloat(lane) + lineHeight / 2 + 2
                        ctx.opacity = settings.opacity
                        ctx.draw(text, at: CGPoint(x: x, y: y), anchor: .leading)
                        ctx.opacity = 1
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }

    private func color(_ rgb: UInt32) -> Color {
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255
        return Color(red: r, green: g, blue: b)
    }

    /// 找第一个 time >= target 的下标
    private func lowerBound(_ target: TimeInterval) -> Int {
        var lo = 0, hi = items.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if items[mid].time < target { lo = mid + 1 } else { hi = mid }
        }
        return lo
    }
}

/// AVPlayerLayer 的 SwiftUI 包装
struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        let v = PlayerUIView()
        v.playerLayer.player = player
        return v
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.playerLayer.player = player
    }
}

final class PlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        playerLayer.videoGravity = .resizeAspect
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
