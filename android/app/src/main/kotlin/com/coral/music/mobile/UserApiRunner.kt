package com.coral.music.mobile

import android.app.Activity
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.webkit.JavascriptInterface
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID
import java.util.concurrent.Executors

class UserApiRunner(private val activity: Activity) {
    private val handler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()
    private val pendingResults = mutableMapOf<String, MethodChannel.Result>()
    private var pendingLoad: MethodChannel.Result? = null
    private var script = ""
    private var loaded = false
    private var sources = emptySet<String>()
    private var webView: WebView? = null

    fun load(rawScript: String, result: MethodChannel.Result) {
        if (rawScript.length > 256 * 1024) {
            result.error("invalid_script", "音源脚本超过大小限制", null)
            return
        }
        pendingLoad?.error("cancelled", "新的音源脚本替换了当前加载", null)
        pendingLoad = result
        script = rawScript
        loaded = false
        sources = emptySet()
        val view = ensureWebView()
        view.loadDataWithBaseURL("https://localhost.invalid/", "<html><body></body></html>", "text/html", "UTF-8", null)
        handler.postDelayed({
            if (!loaded && pendingLoad === result) {
                pendingLoad = null
                result.error("timeout", "音源脚本初始化超时", null)
            }
        }, 20_000)
    }

    fun resolveMusicUrl(arguments: Map<*, *>?, result: MethodChannel.Result) {
        val requestArguments = arguments ?: emptyMap<String, Any?>()
        val source = requestArguments["source"] as? String ?: ""
        if (!loaded || source !in sources) {
            result.error("not_ready", "当前音源未支持该歌曲来源", null)
            return
        }
        val musicInfo = requestArguments["musicInfo"] as? Map<*, *> ?: emptyMap<String, Any?>()
        val payload = JSONObject().apply {
            put("source", source)
            put("action", "musicUrl")
            put("info", JSONObject().apply {
                put("type", requestArguments["quality"] as? String ?: "128k")
                put("musicInfo", JSONObject(musicInfo))
            })
        }
        val requestId = UUID.randomUUID().toString()
        pendingResults[requestId] = result
        evaluate("""
            Promise.resolve(window.__coralRequestHandler(${payload}))
              .then((value) => NativeBridge.result(${JSONObject.quote(requestId)}, JSON.stringify({ok: true, value})))
              .catch((error) => NativeBridge.result(${JSONObject.quote(requestId)}, JSON.stringify({ok: false, error: String(error && error.message || error)})));
        """.trimIndent())
        handler.postDelayed({
            pendingResults.remove(requestId)?.error("timeout", "音源取链超时", null)
        }, 20_000)
    }

    fun dispose() {
        pendingLoad?.error("cancelled", "音源运行时已关闭", null)
        pendingLoad = null
        pendingResults.values.forEach { it.error("cancelled", "音源运行时已关闭", null) }
        pendingResults.clear()
        webView?.destroy()
        webView = null
        executor.shutdownNow()
    }

    private fun ensureWebView(): WebView {
        webView?.let { return it }
        return WebView(activity).also { view ->
            view.settings.javaScriptEnabled = true
            view.settings.allowFileAccess = false
            view.settings.allowContentAccess = false
            view.settings.domStorageEnabled = false
            view.settings.databaseEnabled = false
            view.settings.blockNetworkLoads = true
            view.settings.blockNetworkImage = true
            view.settings.setSupportMultipleWindows(false)
            view.addJavascriptInterface(Bridge(), "NativeBridge")
            view.webViewClient = object : WebViewClient() {
                override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest) = true

                override fun onPageFinished(view: WebView, url: String) {
                    evaluate("$BRIDGE_SCRIPT\n$script")
                }
            }
            webView = view
        }
    }

    private fun evaluate(script: String) {
        handler.post { webView?.evaluateJavascript(script, null) }
    }

    private inner class Bridge {
        @JavascriptInterface
        fun ready(rawManifest: String) {
            handler.post {
                try {
                    val sourceObject = JSONObject(rawManifest).optJSONObject("sources") ?: JSONObject()
                    val enabled = buildSet {
                        sourceObject.keys().forEach { source ->
                            val info = sourceObject.optJSONObject(source)
                            val actions = info?.optJSONArray("actions")
                            if (info?.optString("type") == "music" && actions?.toString()?.contains("musicUrl") == true) add(source)
                        }
                    }
                    if (enabled.isEmpty()) throw IllegalArgumentException("音源脚本未声明可用的 musicUrl 来源")
                    sources = enabled
                    loaded = true
                    pendingLoad?.success(mapOf("musicUrlSources" to enabled.toList()))
                    pendingLoad = null
                } catch (error: Exception) {
                    pendingLoad?.error("invalid_manifest", error.message, null)
                    pendingLoad = null
                }
            }
        }

        @JavascriptInterface
        fun request(id: String, rawUrl: String, rawOptions: String) {
            val url = Uri.parse(rawUrl)
            if (url.scheme != "https" || url.host.isNullOrEmpty()) {
                sendRequestResult(id, "", "仅允许 HTTPS 请求")
                return
            }
            executor.execute {
                try {
                    val options = JSONObject(rawOptions)
                    val method = options.optString("method", "get").uppercase()
                    if (method != "GET" && method != "POST") throw IllegalArgumentException("只允许 GET 或 POST 请求")
                    val connection = (URL(rawUrl).openConnection() as HttpURLConnection).apply {
                        requestMethod = method
                        connectTimeout = options.optInt("timeout", 15_000).coerceIn(1_000, 20_000)
                        readTimeout = connectTimeout
                        instanceFollowRedirects = false
                        options.optJSONObject("headers")?.keys()?.forEach { name ->
                            if (name.lowercase() !in setOf("host", "connection", "content-length")) {
                                setRequestProperty(name, options.optJSONObject("headers")?.optString(name))
                            }
                        }
                        val body = options.optString("body", "")
                        if (method == "POST" && body.isNotEmpty()) {
                            require(body.toByteArray().size <= 64 * 1024) { "请求体超过大小限制" }
                            doOutput = true
                            outputStream.use { it.write(body.toByteArray()) }
                        }
                    }
                    val status = connection.responseCode
                    val stream = if (status >= 400) connection.errorStream else connection.inputStream
                    val bytes = stream?.use { input ->
                        val output = ByteArrayOutputStream()
                        val buffer = ByteArray(8192)
                        while (true) {
                            val count = input.read(buffer)
                            if (count < 0) break
                            require(output.size() + count <= 1024 * 1024) { "响应超过大小限制" }
                            output.write(buffer, 0, count)
                        }
                        output.toByteArray()
                    } ?: byteArrayOf()
                    val body = bytes.toString(Charsets.UTF_8)
                    sendRequestResult(id, JSONObject().apply {
                        put("statusCode", status)
                        put("statusMessage", connection.responseMessage ?: "")
                        put("bytes", bytes.size)
                        put("body", body)
                    }.toString(), null)
                    connection.disconnect()
                } catch (error: Exception) {
                    sendRequestResult(id, "", error.message ?: "请求失败")
                }
            }
        }

        @JavascriptInterface
        fun result(id: String, rawResult: String) {
            handler.post {
                val result = pendingResults.remove(id) ?: return@post
                try {
                    val data = JSONObject(rawResult)
                    val value = data.optString("value", "")
                    val uri = Uri.parse(value)
                    if (!data.optBoolean("ok") || uri.scheme != "https" || uri.host.isNullOrEmpty() || value.length > 8192) {
                        result.error("invalid_result", "音源未返回安全的 HTTPS 播放地址", null)
                    } else {
                        result.success(value)
                    }
                } catch (error: Exception) {
                    result.error("invalid_result", "音源未返回安全的 HTTPS 播放地址", null)
                }
            }
        }
    }

    private fun sendRequestResult(id: String, response: String, error: String?) {
        val payload = JSONObject().apply {
            put("error", error)
            if (error == null) {
                val data = JSONObject(response)
                put("response", data)
                put("body", data.optString("body"))
            }
        }
        evaluate("window.__coralRequestDone(${JSONObject.quote(id)}, ${JSONObject.quote(payload.toString())});")
    }

    companion object {
        private const val BRIDGE_SCRIPT = """
          (() => {
            let nextId = 0;
            const callbacks = {};
            window.__coralRequestDone = (id, raw) => {
              const callback = callbacks[id];
              delete callbacks[id];
              if (!callback) return;
              const result = JSON.parse(raw);
              callback(result.error ? new Error(result.error) : null, result.response || null, result.body || null);
            };
            const bridge = {
              EVENT_NAMES: { request: 'request', inited: 'inited' },
              on(event, callback) {
                if (event !== 'request') return Promise.reject(new Error('Unsupported event'));
                window.__coralRequestHandler = callback;
                return Promise.resolve();
              },
              send(event, data) {
                if (event !== 'inited') return Promise.reject(new Error('Unsupported event'));
                NativeBridge.ready(JSON.stringify(data));
                return Promise.resolve();
              },
              request(url, options = {}, callback) {
                const id = String(++nextId);
                callbacks[id] = callback;
                NativeBridge.request(id, String(url), JSON.stringify(options));
                return () => delete callbacks[id];
              },
              env: 'mobile',
              version: '2.0.0',
            };
            window.lx = bridge;
            window.coral = bridge;
          })();
        """
    }
}
