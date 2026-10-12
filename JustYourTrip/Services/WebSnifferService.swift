import Foundation
import WebKit

/// 网页内容嗅探结果
struct SniffedContent {
    let title: String
    let text: String
    let originalURL: URL
    let finalURL: URL?
    let isSufficient: Bool
    let sourceMethod: String
}

/// 网页嗅探错误类型
enum WebSnifferError: LocalizedError {
    case invalidURL
    case antiCrawlerBlocked(title: String)
    case networkError(String)
    case emptyContent
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无法识别该网页链接地址"
        case .antiCrawlerBlocked(let title):
            return "该平台开启了防爬限制或需要客户端登录（\(title.isEmpty ? "安全验证" : title)）"
        case .networkError(let msg):
            return "网页访问失败: \(msg)"
        case .emptyContent:
            return "未能从该网页提取到有效攻略正文"
        }
    }
}

/// 纯端侧双引擎网页嗅探服务 (Engine 1: 高速 HTTP 重定向直连 + 智能 SSR 萃取；Engine 2: Headless WebKit 降级兜底)
@MainActor
final class WebSnifferService: NSObject, WKNavigationDelegate {
    static let shared = WebSnifferService()
    
    private var webView: WKWebView?
    private var webViewContinuation: CheckedContinuation<SniffedContent, Error>?
    private var webViewTimeoutTask: Task<Void, Never>?
    
    private override init() {
        super.init()
    }
    
    // MARK: - 静态 URL 识别与文本清洗
    
    /// 从任意富文本中提取 URL（支持社媒无协议头短链接、带参数链接及中文字符包围）
    static func extractURL(from text: String) -> URL? {
        let pattern = #"((?:https?:\/\/)?(?:[a-zA-Z0-9-]+\.)+(?:com|cn|tv|net|org|cc|me|link|top|vip|app|site|io|so)(?::[0-9]+)?(?:\/[^\s\u4e00-\u9fa5\uff00-\uffef<>\"\'\(\)\[\]\{\}]*)?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return fallbackExtractURL(from: text)
        }
        
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        if let match = regex.firstMatch(in: text, options: [], range: nsRange),
           let range = Range(match.range, in: text) {
            var raw = String(text[range])
            // 剥除末尾标点与闭合括号
            let invalidTrailing: [Character] = [".", ",", ";", ":", "!", "?", ")", ">", "\"", "'", "，", "。", "！", "？", "；", "：", "）", "》", "」", "』", "、", "/", "#"]
            while let last = raw.last, invalidTrailing.contains(last) {
                raw.removeLast()
            }
            if !raw.lowercased().hasPrefix("http://") && !raw.lowercased().hasPrefix("https://") {
                raw = "https://" + raw
            }
            if let url = URL(string: raw), let host = url.host, host.contains(".") {
                return url
            }
        }
        
        return fallbackExtractURL(from: text)
    }
    
    private static func fallbackExtractURL(from text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        if let match = matches?.first, let range = Range(match.range, in: text) {
            let urlString = String(text[range])
            return URL(string: urlString)
        }
        return nil
    }
    
    /// 移除文本中的 URL
    static func removeURL(from text: String) -> String {
        let pattern = #"((?:https?:\/\/)?(?:[a-zA-Z0-9-]+\.)+(?:com|cn|tv|net|org|cc|me|link|top|vip|app|site|io|so)(?::[0-9]+)?(?:\/[^\s\u4e00-\u9fa5\uff00-\uffef<>\"\'\(\)\[\]\{\}]*)?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return text
        }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: nsRange, withTemplate: "")
    }
    
    /// 清除社媒分享模版废话（如 "快来看吧！复制本条信息打开小红书 App"）
    static func cleanSocialBoilerplate(from text: String) -> String {
        var cleaned = removeURL(from: text)
        let boilerplates = [
            #"复制本条信息.*?(?:小红书|App)"#,
            #"打开(?:小红书|抖音|哔哩哔哩|微信).*?App"#,
            #"快来看吧[！!]"#,
            #"发布了一篇小红书笔记"#,
            #"复制此链接.*?(?:打开抖音|查看)"#,
            #"长按复制.*"#
        ]
        for p in boilerplates {
            if let regex = try? NSRegularExpression(pattern: p, options: [.caseInsensitive]) {
                cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: NSRange(cleaned.startIndex..<cleaned.endIndex, in: cleaned), withTemplate: "")
            }
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - 双引擎嗅探入口
    
    /// 依次调用 HTTP 直连引擎和 WebKit 引擎
    func sniffContent(from url: URL) async throws -> SniffedContent {
        // Engine 1: 高速 HTTP 重定向直连 (0.2s - 0.8s)
        do {
            let httpResult = try await fetchViaHTTP(from: url)
            if httpResult.isSufficient {
                return httpResult
            }
        } catch {
            // HTTP 失败时平滑降级至 Engine 2
        }
        
        // Engine 2: 无头 WebKit 渲染兜底 (针对动态 SPA)
        do {
            let webKitResult = try await fetchViaWebView(from: url)
            if webKitResult.isSufficient {
                return webKitResult
            }
            // 若 WebKit 抓取到的内容仍然不足，判断是否遭遇反爬拦截
            if Self.isAntiCrawlerPage(title: webKitResult.title, text: webKitResult.text) {
                throw WebSnifferError.antiCrawlerBlocked(title: webKitResult.title)
            }
            return webKitResult
        } catch let snifferError as WebSnifferError {
            throw snifferError
        } catch {
            throw WebSnifferError.emptyContent
        }
    }
    
    // MARK: - Engine 1: HTTP 直连萃取
    
    private func fetchViaHTTP(from url: URL) async throws -> SniffedContent {
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh-Hans;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config)
        
        let (data, response) = try await session.data(for: request)
        let finalURL = response.url
        
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .unicode) else {
            throw WebSnifferError.emptyContent
        }
        
        let (title, text) = Self.parseHTMLMetadataAndContent(from: html)
        let isSufficient = Self.isContentSufficient(title: title, text: text)
        
        return SniffedContent(
            title: title,
            text: text,
            originalURL: url,
            finalURL: finalURL,
            isSufficient: isSufficient,
            sourceMethod: "HTTP"
        )
    }
    
    // MARK: - Engine 2: Headless WebKit 降级兜底
    
    private func fetchViaWebView(from url: URL) async throws -> SniffedContent {
        return try await withCheckedThrowingContinuation { continuation in
            self.webViewContinuation = continuation
            
            let config = WKWebViewConfiguration()
            config.defaultWebpagePreferences.allowsContentJavaScript = true
            
            // 采用 100x100 尺寸避免被 WebKit 激进节流
            let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 100, height: 100), configuration: config)
            webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
            webView.navigationDelegate = self
            self.webView = webView
            
            // 超时保护定时器
            self.webViewTimeoutTask?.cancel()
            self.webViewTimeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 12_000_000_000)
                guard let self = self, let cont = self.webViewContinuation else { return }
                self.webViewContinuation = nil
                self.webView = nil
                cont.resume(throwing: WebSnifferError.networkError("网页加载超时"))
            }
            
            var request = URLRequest(url: url)
            request.timeoutInterval = 12
            webView.load(request)
        }
    }
    
    // MARK: - WKNavigationDelegate
    
    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            self.webViewTimeoutTask?.cancel()
            self.webViewTimeoutTask = nil
            
            // 等待前端 SPA 水合 (1.2 秒)
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            
            let jsScript = """
            (() => {
                let xhsTitle = "";
                let xhsDesc = "";
                let state = window.__INITIAL_STATE__ || window.__INITIAL_DATA__;
                if (state) {
                    try {
                        let noteMap = state.note?.noteDetailMap || {};
                        let firstKey = Object.keys(noteMap)[0];
                        if (firstKey && noteMap[firstKey]?.note) {
                            let n = noteMap[firstKey].note;
                            xhsTitle = n.title || "";
                            xhsDesc = n.desc || "";
                            if (n.tagList && Array.isArray(n.tagList)) {
                                xhsDesc += "\\n标签: " + n.tagList.map(t => "#" + (t.name || "")).join(" ");
                            }
                        }
                    } catch(e) {}
                }
                
                let ogTitle = document.querySelector('meta[property="og:title"]')?.content 
                           || document.querySelector('meta[name="twitter:title"]')?.content 
                           || document.title || '';
                let title = xhsTitle || ogTitle;
                
                let ogDesc = document.querySelector('meta[property="og:description"]')?.content 
                          || document.querySelector('meta[name="description"]')?.content || '';
                let noteDesc = document.querySelector('.note-content')?.innerText 
                            || document.querySelector('.desc')?.innerText 
                            || document.querySelector('.article-content')?.innerText
                            || document.querySelector('#js_content')?.innerText
                            || '';
                let bodyText = document.body ? document.body.innerText : '';
                
                let chosenDesc = xhsDesc || noteDesc || ogDesc || bodyText;
                return JSON.stringify({ title: title, text: chosenDesc });
            })();
            """
            
            do {
                let result = try await webView.evaluateJavaScript(jsScript)
                if let jsonStr = result as? String,
                   let data = jsonStr.data(using: .utf8),
                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                    let title = dict["title"] ?? ""
                    let text = dict["text"] ?? ""
                    let isSufficient = Self.isContentSufficient(title: title, text: text)
                    let sniffed = SniffedContent(
                        title: title,
                        text: text,
                        originalURL: webView.url ?? URL(string: "about:blank")!,
                        finalURL: webView.url,
                        isSufficient: isSufficient,
                        sourceMethod: "WebKit"
                    )
                    self.webViewContinuation?.resume(returning: sniffed)
                } else {
                    let title = webView.title ?? ""
                    let sniffed = SniffedContent(
                        title: title,
                        text: "",
                        originalURL: webView.url ?? URL(string: "about:blank")!,
                        finalURL: webView.url,
                        isSufficient: false,
                        sourceMethod: "WebKit"
                    )
                    self.webViewContinuation?.resume(returning: sniffed)
                }
            } catch {
                self.webViewContinuation?.resume(throwing: error)
            }
            self.webViewContinuation = nil
            self.webView = nil
        }
    }
    
    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            self.webViewTimeoutTask?.cancel()
            self.webViewTimeoutTask = nil
            self.webViewContinuation?.resume(throwing: error)
            self.webViewContinuation = nil
            self.webView = nil
        }
    }
    
    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            self.webViewTimeoutTask?.cancel()
            self.webViewTimeoutTask = nil
            self.webViewContinuation?.resume(throwing: error)
            self.webViewContinuation = nil
            self.webView = nil
        }
    }
    
    // MARK: - HTML 解析与信息萃取算法
    
    static func parseHTMLMetadataAndContent(from html: String) -> (title: String, text: String) {
        var detectedTitle = ""
        var detectedText = ""
        
        // 1. 尝试从 window.__INITIAL_STATE__ 或 __INITIAL_DATA__ 中解析
        let statePatterns = [
            #"window\.__INITIAL_STATE__\s*=\s*(\{.+?\});?\s*<\/script>"#,
            #"window\.__INITIAL_DATA__\s*=\s*(\{.+?\});?\s*<\/script>"#
        ]
        for pattern in statePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
                if let match = regex.firstMatch(in: html, options: [], range: nsRange),
                   match.numberOfRanges > 1,
                   let range = Range(match.range(at: 1), in: html) {
                    let jsonString = String(html[range])
                    if let data = jsonString.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let (t, d) = extractFromInitialState(json) {
                            detectedTitle = t
                            detectedText = d
                            break
                        }
                    }
                }
            }
        }
        
        // 2. 提取 Open Graph Title 与 HTML Title
        if detectedTitle.isEmpty {
            let titlePatterns = [
                #"<meta[^>]*property=[\"']og:title[\"'][^>]*content=[\"'](.*?)[\"']"#,
                #"<meta[^>]*content=[\"'](.*?)[\"'][^>]*property=[\"']og:title[\"']"#,
                #"<meta[^>]*name=[\"']twitter:title[\"'][^>]*content=[\"'](.*?)[\"']"#,
                #"<title>(.*?)</title>"#
            ]
            for p in titlePatterns {
                if let regex = try? NSRegularExpression(pattern: p, options: [.caseInsensitive, .dotMatchesLineSeparators]),
                   let match = regex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..<html.endIndex, in: html)),
                   match.numberOfRanges > 1,
                   let range = Range(match.range(at: 1), in: html) {
                    detectedTitle = String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                    break
                }
            }
        }
        
        // 3. 提取 Open Graph Description 与 Meta Description
        if detectedText.isEmpty {
            let descPatterns = [
                #"<meta[^>]*property=[\"']og:description[\"'][^>]*content=[\"'](.*?)[\"']"#,
                #"<meta[^>]*content=[\"'](.*?)[\"'][^>]*property=[\"']og:description[\"']"#,
                #"<meta[^>]*name=[\"']description[\"'][^>]*content=[\"'](.*?)[\"']"#,
                #"<meta[^>]*content=[\"'](.*?)[\"'][^>]*name=[\"']description[\"']"#,
                #"<meta[^>]*name=[\"']twitter:description[\"'][^>]*content=[\"'](.*?)[\"']"#
            ]
            for p in descPatterns {
                if let regex = try? NSRegularExpression(pattern: p, options: [.caseInsensitive, .dotMatchesLineSeparators]),
                   let match = regex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..<html.endIndex, in: html)),
                   match.numberOfRanges > 1,
                   let range = Range(match.range(at: 1), in: html) {
                    let candidate = String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if candidate.count > detectedText.count {
                        detectedText = candidate
                    }
                }
            }
        }
        
        // 4. 若 meta description 较短，尝试从正文解析干净文本
        if detectedText.count < 60 {
            let bodyText = cleanHTMLToPlainText(html)
            if bodyText.count > detectedText.count {
                detectedText = bodyText
            }
        }
        
        return (detectedTitle, detectedText)
    }
    
    /// 从小红书或 SPA 的 INITIAL_STATE JSON 树中提取笔记标题与正文
    private static func extractFromInitialState(_ json: [String: Any]) -> (String, String)? {
        // 小红书典型结构: note -> noteDetailMap -> [noteId] -> note -> {title, desc, tagList}
        if let note = json["note"] as? [String: Any] {
            if let map = note["noteDetailMap"] as? [String: Any],
               let firstKey = map.keys.first,
               let detail = map[firstKey] as? [String: Any],
               let n = detail["note"] as? [String: Any] {
                let title = n["title"] as? String ?? ""
                var desc = n["desc"] as? String ?? ""
                if let tags = n["tagList"] as? [[String: Any]] {
                    let tagNames = tags.compactMap { $0["name"] as? String }.filter { !$0.isEmpty }
                    if !tagNames.isEmpty {
                        desc += "\n\n标签: " + tagNames.map { "#\($0)" }.joined(separator: " ")
                    }
                }
                if !desc.isEmpty || !title.isEmpty {
                    return (title, desc)
                }
            }
        }
        return nil
    }
    
    /// HTML 正文清洗器：移除脚本样式并转换段落为文本
    static func cleanHTMLToPlainText(_ html: String) -> String {
        var text = html
        let removeTags = [
            #"<head[^>]*>.*?</head>"#,
            #"<script[^>]*>.*?</script>"#,
            #"<style[^>]*>.*?</style>"#,
            #"<svg[^>]*>.*?</svg>"#,
            #"<noscript[^>]*>.*?</noscript>"#
        ]
        for p in removeTags {
            if let regex = try? NSRegularExpression(pattern: p, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
                text = regex.stringByReplacingMatches(in: text, options: [], range: NSRange(text.startIndex..<text.endIndex, in: text), withTemplate: "")
            }
        }
        let breakTags: [String: String] = [
            #"<br\s*\/?>"# : "\n",
            #"<\/p>"# : "\n\n",
            #"<\/div>"# : "\n",
            #"<\/li>"# : "\n",
            #"<\/h[1-6]>"# : "\n\n",
            #"<\/tr>"# : "\n"
        ]
        for (p, rep) in breakTags {
            if let regex = try? NSRegularExpression(pattern: p, options: [.caseInsensitive]) {
                text = regex.stringByReplacingMatches(in: text, options: [], range: NSRange(text.startIndex..<text.endIndex, in: text), withTemplate: rep)
            }
        }
        if let tagRegex = try? NSRegularExpression(pattern: #"<[^>]+>"#, options: []) {
            text = tagRegex.stringByReplacingMatches(in: text, options: [], range: NSRange(text.startIndex..<text.endIndex, in: text), withTemplate: "")
        }
        let entities: [(String, String)] = [
            ("&nbsp;", " "),
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&#39;", "'"),
            ("&ldquo;", "“"),
            ("&rdquo;", "”"),
            ("&lsquo;", "‘"),
            ("&rsquo;", "’"),
            ("&mdash;", "—")
        ]
        for (entity, char) in entities {
            text = text.replacingOccurrences(of: entity, with: char)
        }
        if let blankLines = try? NSRegularExpression(pattern: #"\n\s*\n\s*\n+"#, options: []) {
            text = blankLines.stringByReplacingMatches(in: text, options: [], range: NSRange(text.startIndex..<text.endIndex, in: text), withTemplate: "\n\n")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - 质量与反爬校验
    
    static func isAntiCrawlerPage(title: String, text: String) -> Bool {
        let combined = (title + " " + text).lowercased()
        let keywords = [
            "安全验证", "滑块验证", "滑动验证", "请完成验证", "登录后查看",
            "登录小红书", "访问过于频繁", "403 forbidden", "access denied", "robot check"
        ]
        return keywords.contains { combined.contains($0) }
    }
    
    static func isContentSufficient(title: String, text: String) -> Bool {
        if isAntiCrawlerPage(title: title, text: text) {
            return false
        }
        // 字数需达到至少 30 个字才能构成有效游记攻略
        return text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 30
    }
}
