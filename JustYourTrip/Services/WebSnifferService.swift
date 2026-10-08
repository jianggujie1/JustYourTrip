import Foundation
import WebKit

/// 网页内容嗅探结果
struct SniffedContent {
    let title: String
    let text: String
    let originalURL: URL
}

/// 纯端侧无头网页与链接文本嗅探服务
@MainActor
final class WebSnifferService: NSObject, WKNavigationDelegate {
    static let shared = WebSnifferService()
    
    private var webView: WKWebView?
    private var continuation: CheckedContinuation<SniffedContent, Error>?
    
    private override init() {
        super.init()
    }
    
    /// 从任意富文本中尝试提取 URL
    static func extractURL(from text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        if let match = matches?.first, let range = Range(match.range, in: text) {
            let urlString = String(text[range])
            return URL(string: urlString)
        }
        return nil
    }
    
    /// 无头加载 URL 并提取内容
    func sniffContent(from url: URL) async throws -> SniffedContent {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            
            let config = WKWebViewConfiguration()
            config.defaultWebpagePreferences.allowsContentJavaScript = true
            
            let webView = WKWebView(frame: .zero, configuration: config)
            // 模拟主流移动端 Safari UA，小红书会输出适合移动端的 H5 页面
            webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
            webView.navigationDelegate = self
            self.webView = webView
            
            var request = URLRequest(url: url)
            request.timeoutInterval = 20
            webView.load(request)
        }
    }
    
    // MARK: - WKNavigationDelegate
    
    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            // 延时 1.5 秒等待前端 SPA 渲染水合
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            
            let jsScript = """
            (() => {
                let ogTitle = document.querySelector('meta[property="og:title"]')?.content || '';
                let title = ogTitle || document.title || '';
                
                let ogDesc = document.querySelector('meta[property="og:description"]')?.content || '';
                let noteDesc = document.querySelector('.note-content')?.innerText 
                            || document.querySelector('.desc')?.innerText 
                            || '';
                let bodyText = document.body ? document.body.innerText : '';
                
                let chosenDesc = ogDesc || noteDesc || bodyText;
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
                    let sniffed = SniffedContent(title: title, text: text, originalURL: webView.url ?? URL(string: "about:blank")!)
                    self.continuation?.resume(returning: sniffed)
                } else {
                    let title = webView.title ?? ""
                    let sniffed = SniffedContent(title: title, text: "", originalURL: webView.url ?? URL(string: "about:blank")!)
                    self.continuation?.resume(returning: sniffed)
                }
            } catch {
                self.continuation?.resume(throwing: error)
            }
            self.continuation = nil
            self.webView = nil
        }
    }
    
    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            self.continuation?.resume(throwing: error)
            self.continuation = nil
            self.webView = nil
        }
    }
    
    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            self.continuation?.resume(throwing: error)
            self.continuation = nil
            self.webView = nil
        }
    }
}
