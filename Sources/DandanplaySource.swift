import CryptoKit
import Foundation

/// 弹弹play 开放 API（需要自己在 dandanplay 申请 AppId / AppSecret）
enum DandanplaySource {
    private static let host = "https://api.dandanplay.net"

    private static func sign(path: String, appId: String, appSecret: String) -> (String, String) {
        let timestamp = String(Int(Date().timeIntervalSince1970))
        let raw = appId + timestamp + path + appSecret
        let digest = SHA256.hash(data: Data(raw.utf8))
        let signature = Data(digest).base64EncodedString()
        return (timestamp, signature)
    }

    private static func request(path: String, appId: String, appSecret: String,
                                method: String = "GET", body: Data? = nil) async throws -> Data {
        guard let url = URL(string: host + path) else { throw DanmakuError.badInput }
        let (ts, sig) = sign(path: path, appId: appId, appSecret: appSecret)
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 20
        req.setValue(appId, forHTTPHeaderField: "X-AppId")
        req.setValue(ts, forHTTPHeaderField: "X-Timestamp")
        req.setValue(sig, forHTTPHeaderField: "X-Signature")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            throw DanmakuError.server("弹弹play HTTP \(code)")
        }
        return data
    }

    /// 用文件名去匹配剧集
    static func match(fileName: String, appId: String, appSecret: String) async throws -> Int {
        let body = try JSONSerialization.data(withJSONObject: ["fileName": fileName, "matchMode": "fileNameOnly"])
        let data = try await request(path: "/api/v2/match", appId: appId, appSecret: appSecret,
                                     method: "POST", body: body)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let matches = root["matches"] as? [[String: Any]],
              let first = matches.first,
              let epId = first["episodeId"] as? Int else {
            throw DanmakuError.server("弹弹play 没匹配到片子")
        }
        return epId
    }

    /// 按 episodeId 拉弹幕
    static func danmaku(episodeId: Int, appId: String, appSecret: String) async throws -> [Danmaku] {
        let path = "/api/v2/comment/\(episodeId)?withRelated=true&chConvert=1"
        let data = try await request(path: path, appId: appId, appSecret: appSecret)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let comments = root["comments"] as? [[String: Any]] else {
            throw DanmakuError.empty
        }
        var out: [Danmaku] = []
        out.reserveCapacity(comments.count)
        for c in comments {
            guard let p = c["p"] as? String, let m = c["m"] as? String else { continue }
            let parts = p.split(separator: ",").map(String.init)
            guard parts.count >= 3,
                  let time = Double(parts[0]),
                  let mode = Int(parts[1]),
                  let color = UInt32(parts[2]) else { continue }
            out.append(Danmaku(time: time, text: m, color: color, mode: mode))
        }
        if out.isEmpty { throw DanmakuError.empty }
        return out.sorted { $0.time < $1.time }
    }

    static func load(fileName: String, appId: String, appSecret: String) async throws -> [Danmaku] {
        guard !appId.isEmpty, !appSecret.isEmpty else {
            throw DanmakuError.server("先在设置里填弹弹play 的 AppId / AppSecret")
        }
        let ep = try await match(fileName: fileName, appId: appId, appSecret: appSecret)
        return try await danmaku(episodeId: ep, appId: appId, appSecret: appSecret)
    }
}
