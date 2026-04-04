import SwiftUI
import WebKit

/// Embeds a YouTube video using WKWebView. Shows a placeholder when no video ID is set.
/// This is the only WKWebView in the app — there is no native SwiftUI YouTube player.
struct YouTubePlayerView: UIViewRepresentable {
    let videoId: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = .all

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard !videoId.isEmpty else {
            webView.loadHTMLString(placeholderHTML, baseURL: nil)
            return
        }
        webView.loadHTMLString(embedHTML(for: videoId), baseURL: nil)
    }

    private func embedHTML(for id: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no">
        <style>
          * { margin: 0; padding: 0; box-sizing: border-box; }
          html, body { width: 100%; height: 100%; background: #000; }
          iframe { width: 100%; height: 100%; border: 0; display: block; }
        </style>
        </head>
        <body>
        <iframe
          src="https://www.youtube-nocookie.com/embed/\(id)?playsinline=1&rel=0&modestbranding=1"
          allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
          allowfullscreen>
        </iframe>
        </body>
        </html>
        """
    }

    private var placeholderHTML: String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          * { margin: 0; padding: 0; }
          html, body { width: 100%; height: 100%; background: #1c1c1e;
                       display: flex; align-items: center; justify-content: center; }
          p { color: #636366; font-family: -apple-system; font-size: 14px; }
        </style>
        </head>
        <body><p>Video coming soon</p></body>
        </html>
        """
    }
}
