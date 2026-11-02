import Foundation

enum DanmakuError: LocalizedError {
    case badInput
    case network(String)
    case empty
    case server(String)

    var errorDescription: String? {
        switch self {
        case .badInput: return "没识别出 BV 号 / EP 号"
        case .network(let m): return "网络错误：\(m)"
        case .empty: return "没拿到弹幕"
        case .server(let m): return m
        }
    }
}

/// B 站弹幕：BV 号 → cid → comment.bilibili.com/{cid}.xml
enum BiliSource {
    private static let headers: [String: String] = [
        "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
        "Referer": "https://www.bilibili.com/",
        "Accept": "application/json, text/plain, */*"
    ]

    /// 从任意字符串里抠出 BV 号
    static func bvid(from input: String) -> String? {
        let pattern = "BV[0-9A-Za-z]{10}"
        if let r = input.range(of: pattern, options: .regularExpression) {
            return String(input[r])
        }
        return nil
    }

    /// 从 ep 链接里抠出 ep id
    static func epId(from input: String) -> Int? {
        let pattern = "ep(\\d{3,})"
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)),
              m.numberOfRanges > 1,
              let r = Range(m.range(at: 1), in: input) else { return nil }
        return Int(input[r])
    }

    static func request(_ url: URL, method: String = "GET", body: Data? = nil) async throws -> Data {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 20
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
        if let body { req.httpBody = body }
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw DanmakuError.network("无响应") }
        if http.statusCode == 412 { throw DanmakuError.server("B站风控了（412），等一会儿再试") }
        guard (200..<300).contains(http.statusCode) else {
            throw DanmakuError.network("HTTP \(http.statusCode)")
        }
        return data
    }

    /// BV 号 → 第一 P 的 cid
    static func cid(bvid: String) async throws -> Int {
        guard let url = URL(string: "https://api.bilibili.com/x/web-interface/view?bvid=\(bvid)") else {
            throw DanmakuError.badInput
        }
        let data = try await request(url)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let code = root["code"] as? Int, code == 0,
              let d = root["data"] as? [String: Any] else {
            throw DanmakuError.server("B站接口返回异常")
        }
        if let pages = d["pages"] as? [[String: Any]], let first = pages.first, let cid = first["cid"] as? Int {
            return cid
        }
        if let cid = d["cid"] as? Int { return cid }
        throw DanmakuError.server("拿不到 cid")
    }

    /// 直接按 cid 拉弹幕 XML
    static func danmaku(cid: Int) async throws -> [Danmaku] {
        guard let url = URL(string: "https://comment.bilibili.com/\(cid).xml") else {
            throw DanmakuError.badInput
        }
        let data = try await request(url)
        let parsed = try DanmakuXMLParser.parse(data)
        if parsed.isEmpty { throw DanmakuError.empty }
        return parsed.sorted { $0.time < $1.time }
    }

    /// 一个入口：BV / EP / 链接 都行
    static func load(input: String) async throws -> [Danmaku] {
        if let bv = bvid(from: input) {
            let c = try await cid(bvid: bv)
            return try await danmaku(cid: c)
        }
        if let ep = epId(from: input) {
            throw DanmakuError.server("EP 链接暂时不支持，直接贴 BV 号吧（ep\(ep)）")
        }
        throw DanmakuError.badInput
    }
}

/// B站 XML：<d p="时间,模式,颜色,用户,时间戳,池,用户哈希,行号">文本</d>
final class DanmakuXMLParser: NSObject, XMLParserDelegate {
    private var items: [Danmaku] = []
    private var currentText = ""
    private var pending: (TimeInterval, Int, UInt32)?

    static func parse(_ data: Data) throws -> [Danmaku] {
        let p = DanmakuXMLParser()
        let parser = XMLParser(data: data)
        parser.delegate = p
        guard parser.parse() || !p.items.isEmpty else {
            throw DanmakuError.empty
        }
        return p.items
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        guard elementName == "d", let p = attributeDict["p"] else { return }
        let parts = p.split(separator: ",").map(String.init)
        guard parts.count >= 3,
              let time = Double(parts[0]),
              let mode = Int(parts[1]),
              let color = UInt32(parts[2]) else { return }
        pending = (time, mode, color)
        currentText = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        guard elementName == "d", let p = pending else { return }
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            items.append(Danmaku(time: p.0, text: text, color: p.2, mode: p.1))
        }
        pending = nil
        currentText = ""
    }
}
