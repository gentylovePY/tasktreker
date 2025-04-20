import SwiftUI
import WebKit

struct YandexAuthWebView: UIViewRepresentable {
    @EnvironmentObject var authManager: AuthManager
    let url: URL
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: YandexAuthWebView
        
        init(_ parent: YandexAuthWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url, url.absoluteString.contains("code=") {
                parent.authManager.handleCallback(url: url)
                decisionHandler(.cancel)
                parent.authManager.showWebView = false
                return
            }
            decisionHandler(.allow)
        }
    }
}
