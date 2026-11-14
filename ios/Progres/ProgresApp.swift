import SwiftUI
import WebKit

@main
struct ProgresApp: App {
    var body: some Scene {
        WindowGroup {
            WebView()
                .ignoresSafeArea()
        }
    }
}

/// Shows the bundled index.html and keeps the workout log in UserDefaults,
/// so the data survives app restarts and reinstalls from Xcode.
struct WebView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        let saved = UserDefaults.standard.string(forKey: Coordinator.storageKey) ?? "[]"
        let boot = "window.__progresNative = " + Coordinator.validJSONArray(saved) + ";"
        controller.addUserScript(WKUserScript(source: boot, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        controller.add(context.coordinator, name: "progres")

        let config = WKWebViewConfiguration()
        config.userContentController = controller

        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = .systemBackground
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.scrollView.bounces = false
        context.coordinator.webView = web

        if let page = Bundle.main.url(forResource: "index", withExtension: "html") {
            web.loadFileURL(page, allowingReadAccessTo: page.deletingLastPathComponent())
        }
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKScriptMessageHandler {
        static let storageKey = "progres.entries"
        weak var webView: WKWebView?

        static func validJSONArray(_ text: String) -> String {
            guard let data = text.data(using: .utf8),
                  (try? JSONSerialization.jsonObject(with: data)) is [Any] else { return "[]" }
            return text
        }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let type = body["type"] as? String,
                  let json = body["json"] as? String else { return }

            switch type {
            case "save":
                UserDefaults.standard.set(json, forKey: Self.storageKey)
            case "export":
                let name = (body["name"] as? String) ?? "progres.json"
                let file = FileManager.default.temporaryDirectory.appendingPathComponent(name)
                guard (try? json.write(to: file, atomically: true, encoding: .utf8)) != nil else { return }
                share(file)
            default:
                break
            }
        }

        private func share(_ file: URL) {
            guard let web = webView, var top = web.window?.rootViewController else { return }
            while let presented = top.presentedViewController { top = presented }
            let sheet = UIActivityViewController(activityItems: [file], applicationActivities: nil)
            sheet.popoverPresentationController?.sourceView = web
            top.present(sheet, animated: true)
        }
    }
}
