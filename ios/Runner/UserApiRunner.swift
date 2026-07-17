import Flutter
import Foundation
import WebKit

/// Session-only LX User API runtime. It deliberately exposes no file, storage,
/// navigation or direct WebKit network surface to imported scripts.
final class UserApiRunner: NSObject, WKNavigationDelegate, WKScriptMessageHandler, URLSessionDataDelegate, URLSessionTaskDelegate {
  private static let scriptLimit = 256 * 1024
  private static let responseLimit = 1024 * 1024
  private static let requestLimit = 64 * 1024

  private var webView: WKWebView?
  private var script = ""
  private var loaded = false
  private var sources = Set<String>()
  private var lyricSources = Set<String>()
  private var pendingLoad: FlutterResult?
  private var pendingResults = [String: FlutterResult]()
  private var pendingLyricResults = [String: FlutterResult]()
  private var loadTimeout: DispatchWorkItem?
  private var requestTimeouts = [String: DispatchWorkItem]()
  private lazy var session: URLSession = {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.httpShouldSetCookies = false
    configuration.httpCookieStorage = nil
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    return URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
  }()
  private var httpRequests = [Int: HttpRequest]()

  private struct HttpRequest {
    let id: String
    var response: HTTPURLResponse?
    var data = Data()
  }

  func load(_ rawScript: String, result: @escaping FlutterResult) {
    guard !rawScript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          rawScript.utf8.count <= Self.scriptLimit else {
      result(FlutterError(code: "invalid_script", message: "音源脚本为空或超过大小限制", details: nil))
      return
    }
    pendingLoad?(FlutterError(code: "cancelled", message: "新的音源脚本替换了当前加载", details: nil))
    cancelPendingRequests(message: "新的音源脚本替换了当前运行时")
    loadTimeout?.cancel()
    script = rawScript
    loaded = false
    sources.removeAll()
    lyricSources.removeAll()
    pendingLoad = result
    resetWebView()
    let timeout = DispatchWorkItem { [weak self] in
      guard let self, !self.loaded else { return }
      self.pendingLoad?(FlutterError(code: "timeout", message: "音源脚本初始化超时", details: nil))
      self.pendingLoad = nil
    }
    loadTimeout = timeout
    DispatchQueue.main.asyncAfter(deadline: .now() + 20, execute: timeout)
  }

  func clear(result: @escaping FlutterResult) {
    pendingLoad?(FlutterError(code: "cancelled", message: "音源脚本已移除", details: nil))
    pendingLoad = nil
    loadTimeout?.cancel()
    cancelPendingRequests(message: "音源脚本已移除")
    script = ""
    loaded = false
    sources.removeAll()
    lyricSources.removeAll()
    resetWebView()
    result(nil)
  }

  func resolveMusicUrl(arguments: [String: Any]?, result: @escaping FlutterResult) {
    let values = arguments ?? [:]
    let source = values["source"] as? String ?? ""
    guard loaded, sources.contains(source) else {
      result(FlutterError(code: "not_ready", message: "当前音源未支持该歌曲来源", details: nil))
      return
    }
    let payload: [String: Any] = [
      "source": source,
      "action": "musicUrl",
      "info": [
        "type": values["quality"] as? String ?? "128k",
        "musicInfo": values["musicInfo"] as? [String: Any] ?? [:],
      ],
    ]
    resolve(payload: payload, lyric: false, result: result)
  }

  func resolveLyric(arguments: [String: Any]?, result: @escaping FlutterResult) {
    let values = arguments ?? [:]
    let source = values["source"] as? String ?? ""
    guard loaded, sources.contains(source) else {
      result(FlutterError(code: "not_ready", message: "当前音源未支持该歌曲来源的歌词", details: nil))
      return
    }
    let payload: [String: Any] = [
      "source": source,
      "action": "lyric",
      "info": [
        "isGetLyricx": true,
        "musicInfo": values["musicInfo"] as? [String: Any] ?? [:],
      ],
    ]
    resolve(payload: payload, lyric: true, result: result)
  }

  func dispose() {
    clear { _ in }
    session.invalidateAndCancel()
    webView?.configuration.userContentController.removeScriptMessageHandler(forName: "coralNative")
    webView = nil
  }

  private func resolve(payload: [String: Any], lyric: Bool, result: @escaping FlutterResult) {
    guard let encoded = try? JSONSerialization.data(withJSONObject: payload),
          let json = String(data: encoded, encoding: .utf8) else {
      result(FlutterError(code: "invalid_result", message: lyric ? "音源未返回有效歌词" : "音源未返回有效的 HTTP 播放地址", details: nil))
      return
    }
    let id = UUID().uuidString
    if lyric { pendingLyricResults[id] = result } else { pendingResults[id] = result }
    let callback = lyric ? "lyricResult" : "result"
    evaluate("""
      Promise.resolve(window.__coralRequestHandler(\(json)))
        .then((value) => window.__coralNative({method: '\(callback)', id: \(jsonString(id)), ok: true, value}))
        .catch((error) => window.__coralNative({method: '\(callback)', id: \(jsonString(id)), ok: false, error: String(error && error.message || error)}));
    """)
    let timeout = DispatchWorkItem { [weak self] in
      guard let self else { return }
      let failure = FlutterError(code: "timeout", message: lyric ? "音源歌词获取超时" : "音源取链超时", details: nil)
      if lyric { self.pendingLyricResults.removeValue(forKey: id)?(failure) }
      else { self.pendingResults.removeValue(forKey: id)?(failure) }
    }
    requestTimeouts[id] = timeout
    DispatchQueue.main.asyncAfter(deadline: .now() + 20, execute: timeout)
  }

  private func ensureWebView() -> WKWebView {
    if let webView { return webView }
    let configuration = WKWebViewConfiguration()
    configuration.websiteDataStore = .nonPersistent()
    configuration.preferences.javaScriptEnabled = true
    configuration.userContentController.add(self, name: "coralNative")
    let view = WKWebView(frame: .zero, configuration: configuration)
    view.navigationDelegate = self
    webView = view
    return view
  }

  private func resetWebView() {
    let view = ensureWebView()
    // CSP protects against direct fetch/XHR. The bridge below also replaces the
    // APIs so a script has to use the native, HTTPS-only request path.
    view.loadHTMLString("<html><head><meta http-equiv=\"Content-Security-Policy\" content=\"connect-src 'none'\"></head><body></body></html>", baseURL: URL(string: "https://localhost.invalid/"))
  }

  private func evaluateUserScript() {
    guard !script.isEmpty else { return }
    let source = jsonString(script)
    evaluate("""
      (() => {
        window.__coralScriptInfo = { rawScript: \(source) };
        window.fetch = () => Promise.reject(new Error('当前受限运行时禁止直接网络请求'));
        window.XMLHttpRequest = class { constructor() { throw new Error('当前受限运行时禁止直接网络请求'); } };
        \(Self.bridgeScript)
        window.addEventListener('error', (event) => window.__coralNative({method: 'scriptError', message: String(event.message || '音源脚本执行失败')}));
        window.addEventListener('unhandledrejection', (event) => window.__coralNative({method: 'scriptError', message: String(event.reason && event.reason.message || event.reason || '音源脚本初始化失败')}));
        try { (0, eval)(window.__coralScriptInfo.rawScript); }
        catch (error) { window.__coralNative({method: 'scriptError', message: String(error && error.message || error || '音源脚本执行失败')}); }
      })();
    """)
  }

  private func evaluate(_ javascript: String) {
    webView?.evaluateJavaScript(javascript) { _, error in
      guard let error, self.pendingLoad != nil else { return }
      self.pendingLoad?(FlutterError(code: "script_error", message: error.localizedDescription, details: nil))
      self.pendingLoad = nil
    }
  }

  private func cancelPendingRequests(message: String) {
    let failure = FlutterError(code: "cancelled", message: message, details: nil)
    pendingResults.values.forEach { $0(failure) }
    pendingLyricResults.values.forEach { $0(failure) }
    pendingResults.removeAll()
    pendingLyricResults.removeAll()
    requestTimeouts.values.forEach { $0.cancel() }
    requestTimeouts.removeAll()
    httpRequests.keys.forEach { taskId in
      session.getAllTasks { tasks in tasks.first(where: { $0.taskIdentifier == taskId })?.cancel() }
    }
    httpRequests.removeAll()
  }

  private func jsonString(_ value: String) -> String {
    let data = try! JSONSerialization.data(withJSONObject: [value])
    return String(data: data, encoding: .utf8)!.dropFirst().dropLast().description
  }

  // MARK: WKNavigationDelegate

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    evaluateUserScript()
  }

  func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    let url = navigationAction.request.url
    decisionHandler(url?.host == "localhost.invalid" || url?.scheme == "about" ? .allow : .cancel)
  }

  // MARK: WKScriptMessageHandler

  func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    guard message.name == "coralNative", let body = message.body as? [String: Any], let method = body["method"] as? String else { return }
    switch method {
    case "ready": handleReady(body["manifest"] as? String ?? "")
    case "scriptError":
      guard !loaded, let result = pendingLoad else { return }
      result(FlutterError(code: "script_error", message: (body["message"] as? String ?? "音源脚本执行失败").prefix(1024).description, details: nil))
      pendingLoad = nil
      loadTimeout?.cancel()
    case "request": startRequest(body)
    case "result": handleResult(body, lyric: false)
    case "lyricResult": handleResult(body, lyric: true)
    default: break
    }
  }

  private func handleReady(_ rawManifest: String) {
    do {
      guard let data = rawManifest.data(using: .utf8),
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let declared = root["sources"] as? [String: Any] else { throw RuntimeError("音源脚本未声明来源") }
      let music = declared.compactMap { key, value -> String? in
        guard let item = value as? [String: Any], item["type"] as? String == "music",
              (item["actions"] as? [String])?.contains("musicUrl") == true else { return nil }
        return key
      }
      guard !music.isEmpty else { throw RuntimeError("音源脚本未声明可用的 musicUrl 来源") }
      sources = Set(music)
      lyricSources = Set(declared.compactMap { key, value in
        guard let item = value as? [String: Any], item["type"] as? String == "music",
              (item["actions"] as? [String])?.contains("lyric") == true else { return nil }
        return key
      })
      loaded = true
      pendingLoad?(["musicUrlSources": music.sorted(), "lyricSources": lyricSources.sorted()])
      pendingLoad = nil
      loadTimeout?.cancel()
    } catch {
      pendingLoad?(FlutterError(code: "invalid_manifest", message: error.localizedDescription, details: nil))
      pendingLoad = nil
      loadTimeout?.cancel()
    }
  }

  private func handleResult(_ body: [String: Any], lyric: Bool) {
    guard let id = body["id"] as? String else { return }
    requestTimeouts.removeValue(forKey: id)?.cancel()
    let result = lyric ? pendingLyricResults.removeValue(forKey: id) : pendingResults.removeValue(forKey: id)
    guard let result else { return }
    guard body["ok"] as? Bool == true else {
      result(FlutterError(code: "source_error", message: (body["error"] as? String ?? (lyric ? "音源歌词获取失败" : "音源取链失败")).prefix(1024).description, details: nil))
      return
    }
    if lyric {
      let value = body["value"]
      let payload: Any = value is String ? ["lyric": value!] : value ?? [:]
      guard JSONSerialization.isValidJSONObject(payload), let data = try? JSONSerialization.data(withJSONObject: payload), data.count <= Self.scriptLimit else {
        result(FlutterError(code: "invalid_result", message: "音源未返回有效歌词", details: nil)); return
      }
      result(String(data: data, encoding: .utf8))
      return
    }
    let raw = body["value"]
    let detail = (raw as? [String: Any])?["data"] as? [String: Any] ?? raw as? [String: Any] ?? (raw as? String).map { ["url": $0] }
    guard let detail, let url = detail["url"] as? String, url.count <= 8192,
          let uri = URL(string: url), ["http", "https"].contains(uri.scheme?.lowercased() ?? ""), uri.host != nil else {
      result(FlutterError(code: "invalid_result", message: "音源未返回有效的 HTTP 播放地址", details: nil)); return
    }
    result(["url": url, "type": detail["type"] as? String ?? ""])
  }

  // MARK: restricted native HTTP

  private func startRequest(_ body: [String: Any]) {
    guard let id = body["id"] as? String, let rawUrl = body["url"] as? String,
          let url = URL(string: rawUrl), url.scheme?.lowercased() == "https", url.host != nil else {
      sendRequestResult(id: body["id"] as? String ?? "", error: "仅允许 HTTPS 请求"); return
    }
    let options = body["options"] as? [String: Any] ?? [:]
    let method = (options["method"] as? String ?? "get").uppercased()
    guard method == "GET" || method == "POST" else { sendRequestResult(id: id, error: "只允许 GET 或 POST 请求"); return }
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.timeoutInterval = min(max(options["timeout"] as? TimeInterval ?? 15, 1), 20)
    request.httpShouldHandleCookies = false
    if let headers = options["headers"] as? [String: String] {
      headers.forEach { name, value in
        if !["host", "connection", "content-length"].contains(name.lowercased()) { request.setValue(value, forHTTPHeaderField: name) }
      }
    }
    if let text = options["body"] as? String, !text.isEmpty {
      let data = Data(text.utf8)
      guard method == "POST", data.count <= Self.requestLimit else { sendRequestResult(id: id, error: "请求体超过大小限制"); return }
      request.httpBody = data
    }
    let task = session.dataTask(with: request)
    httpRequests[task.taskIdentifier] = HttpRequest(id: id)
    task.resume()
  }

  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
    guard var item = httpRequests[dataTask.taskIdentifier], let http = response as? HTTPURLResponse,
          response.expectedContentLength <= Int64(Self.responseLimit) || response.expectedContentLength < 0 else {
      httpRequests.removeValue(forKey: dataTask.taskIdentifier).map { sendRequestResult(id: $0.id, error: "响应超过大小限制") }
      completionHandler(.cancel); return
    }
    item.response = http
    httpRequests[dataTask.taskIdentifier] = item
    completionHandler(.allow)
  }

  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    guard var item = httpRequests[dataTask.taskIdentifier] else { return }
    guard item.data.count + data.count <= Self.responseLimit else {
      httpRequests.removeValue(forKey: dataTask.taskIdentifier).map { sendRequestResult(id: $0.id, error: "响应超过大小限制") }
      dataTask.cancel(); return
    }
    item.data.append(data)
    httpRequests[dataTask.taskIdentifier] = item
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
    completionHandler(nil)
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    guard let item = httpRequests.removeValue(forKey: task.taskIdentifier) else { return }
    guard error == nil, let response = item.response else { sendRequestResult(id: item.id, error: error?.localizedDescription ?? "请求失败"); return }
    sendRequestResult(id: item.id, response: [
      "statusCode": response.statusCode,
      "statusMessage": HTTPURLResponse.localizedString(forStatusCode: response.statusCode),
      "bytes": item.data.count,
      "body": String(data: item.data, encoding: .utf8) ?? "",
    ])
  }

  private func sendRequestResult(id: String, response: [String: Any]? = nil, error: String? = nil) {
    guard !id.isEmpty else { return }
    var payload: [String: Any] = ["error": error as Any]
    if let response { payload["response"] = response; payload["body"] = response["body"] }
    guard let data = try? JSONSerialization.data(withJSONObject: payload), let json = String(data: data, encoding: .utf8) else { return }
    evaluate("window.__coralRequestDone(\(jsonString(id)), \(jsonString(json)));" )
  }

  private struct RuntimeError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
  }

  private static let bridgeScript = """
    (() => {
      const callbacks = {};
      window.__coralNative = (payload) => window.webkit.messageHandlers.coralNative.postMessage(payload);
      // WebKit messaging is asynchronous, while LX expects md5() to return a
      // string immediately. Keep the small deterministic implementation here
      // instead of opening a synchronous native escape hatch.
      const md5 = (input) => {
        const source = new TextEncoder().encode(String(input));
        const bits = source.length * 8;
        const size = (((source.length + 8) >>> 6) + 1) * 64;
        const bytes = new Uint8Array(size);
        bytes.set(source); bytes[source.length] = 0x80;
        const view = new DataView(bytes.buffer);
        view.setUint32(size - 8, bits >>> 0, true);
        view.setUint32(size - 4, Math.floor(bits / 0x100000000), true);
        const shift = [7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
          5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20,
          4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
          6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21];
        const constants = Array.from({length: 64}, (_, index) =>
          Math.floor(Math.abs(Math.sin(index + 1)) * 0x100000000) >>> 0);
        let a0 = 0x67452301, b0 = 0xefcdab89, c0 = 0x98badcfe, d0 = 0x10325476;
        const rotate = (value, count) => (value << count) | (value >>> (32 - count));
        for (let offset = 0; offset < size; offset += 64) {
          let a = a0, b = b0, c = c0, d = d0;
          for (let index = 0; index < 64; index++) {
            let f, g;
            if (index < 16) { f = (b & c) | (~b & d); g = index; }
            else if (index < 32) { f = (d & b) | (~d & c); g = (5 * index + 1) % 16; }
            else if (index < 48) { f = b ^ c ^ d; g = (3 * index + 5) % 16; }
            else { f = c ^ (b | ~d); g = (7 * index) % 16; }
            const sum = (a + f + constants[index] + view.getUint32(offset + g * 4, true)) >>> 0;
            a = d; d = c; c = b; b = (b + rotate(sum, shift[index])) >>> 0;
          }
          a0 = (a0 + a) >>> 0; b0 = (b0 + b) >>> 0;
          c0 = (c0 + c) >>> 0; d0 = (d0 + d) >>> 0;
        }
        return [a0, b0, c0, d0].map((word) => [0, 8, 16, 24]
          .map((shift) => ((word >>> shift) & 0xff).toString(16).padStart(2, '0')).join('')).join('');
      };
      window.__coralRequestDone = (id, raw) => {
        const callback = callbacks[id]; delete callbacks[id]; if (!callback) return;
        const result = JSON.parse(raw); let body = result.body;
        try { body = JSON.parse(body); } catch (_) {}
        const response = result.response || null; if (response) response.body = body;
        callback(result.error ? new Error(result.error) : null, response, body);
      };
      let sequence = 0;
      const bridge = {
        EVENT_NAMES: { request: 'request', inited: 'inited' },
        on(event, callback) { if (event !== 'request') return Promise.reject(new Error('Unsupported event')); window.__coralRequestHandler = callback; return Promise.resolve(); },
        send(event, data) { if (event === 'inited') window.__coralNative({method: 'ready', manifest: JSON.stringify(data)}); else if (event !== 'updateAlert') return Promise.reject(new Error('Unsupported event')); return Promise.resolve(); },
        request(url, options = {}, callback) { const id = String(++sequence); callbacks[id] = callback; window.__coralNative({method: 'request', id, url: String(url), options}); return () => delete callbacks[id]; },
        utils: {
          crypto: {
            md5(value) { return md5(value); },
            randomBytes(size) { const bytes = new Uint8Array(Number(size)); if (bytes.length < 1 || bytes.length > 4096) throw new Error('随机字节长度超出限制'); crypto.getRandomValues(bytes); return bytes; },
            aesEncrypt() { return Promise.reject(new Error('当前受限运行时不支持 AES 加密')); },
            rsaEncrypt() { return Promise.reject(new Error('当前受限运行时不支持 RSA 加密')); },
          },
          buffer: { from(value) { if (value instanceof Uint8Array) return value; if (Array.isArray(value)) return Uint8Array.from(value); throw new Error('当前受限运行时仅支持字节数组'); }, bufToString(value) { return new TextDecoder().decode(value); } },
          zlib: { inflate() { return Promise.reject(new Error('当前受限运行时不支持 zlib 解压')); }, deflate() { return Promise.reject(new Error('当前受限运行时不支持 zlib 压缩')); } },
        },
        currentScriptInfo: window.__coralScriptInfo, env: 'mobile', version: '2.0.0',
      };
      window.lx = bridge; window.coral = bridge;
    })();
  """
}
