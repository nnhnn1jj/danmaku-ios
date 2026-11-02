import Foundation

struct Danmaku: Identifiable, Equatable {
    let id = UUID()
    /// 出现时间，秒
    let time: TimeInterval
    let text: String
    /// 0xRRGGBB
    let color: UInt32
    /// 1 = 滚动，4 = 底部，5 = 顶部
    let mode: Int
}

struct DanmakuSettings: Codable {
    var fontSize: Double = 15
    var opacity: Double = 0.85
    /// 横穿屏幕所需秒数，越小越快
    var speed: Double = 8.0
    var laneCount: Int = 8
    var showTop: Bool = true
    var unifiedWhite: Bool = false
    var danmakuEnabled: Bool = true

    var dandanplayAppId: String = ""
    var dandanplayAppSecret: String = ""

    static let key = "danmaku.settings.v1"

    static func load() -> DanmakuSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let s = try? JSONDecoder().decode(DanmakuSettings.self, from: data) else {
            return DanmakuSettings()
        }
        return s
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: DanmakuSettings.key)
        }
    }
}

/// 从各种弹幕格式里抽出来的解析结果
enum DanmakuFormat {
    case bilibiliXML
    case dandanplayJSON
}
