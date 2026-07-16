package com.coral.music.mobile

import android.app.Activity
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.webkit.JavascriptInterface
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.security.SecureRandom
import java.util.UUID
import java.util.concurrent.Executors

class UserApiRunner(private val activity: Activity) {
    private val handler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()
    private val pendingResults = mutableMapOf<String, MethodChannel.Result>()
    private val pendingLyricResults = mutableMapOf<String, MethodChannel.Result>()
    private var pendingLoad: MethodChannel.Result? = null
    private var script = ""
    private var loaded = false
    private var sources = emptySet<String>()
    private var lyricSources = emptySet<String>()
    private var webView: WebView? = null

    fun load(rawScript: String, result: MethodChannel.Result) {
        if (rawScript.isBlank() || rawScript.length > 256 * 1024) {
            result.error("invalid_script", "音源脚本超过大小限制", null)
            return
        }
        pendingLoad?.error("cancelled", "新的音源脚本替换了当前加载", null)
        pendingLoad = null
        cancelPendingRequests("新的音源脚本替换了当前运行时")
        pendingLoad = result
        script = rawScript
        loaded = false
        sources = emptySet()
        lyricSources = emptySet()
        val view = ensureWebView()
        resetWebView(view)
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

    fun resolveLyric(arguments: Map<*, *>?, result: MethodChannel.Result) {
        val requestArguments = arguments ?: emptyMap<String, Any?>()
        val source = requestArguments["source"] as? String ?: ""
        if (!loaded || source !in lyricSources) {
            result.error("not_ready", "当前音源未支持该歌曲来源的歌词", null)
            return
        }
        val musicInfo = requestArguments["musicInfo"] as? Map<*, *> ?: emptyMap<String, Any?>()
        val payload = JSONObject().apply {
            put("source", source)
            put("action", "lyric")
            put("info", JSONObject().apply {
                put("isGetLyricx", true)
                put("musicInfo", JSONObject(musicInfo))
            })
        }
        val requestId = UUID.randomUUID().toString()
        pendingLyricResults[requestId] = result
        evaluate("""
            Promise.resolve(window.__coralRequestHandler(${payload}))
              .then((value) => NativeBridge.lyricResult(${JSONObject.quote(requestId)}, JSON.stringify({ok: true, value})))
              .catch((error) => NativeBridge.lyricResult(${JSONObject.quote(requestId)}, JSON.stringify({ok: false, error: String(error && error.message || error)})));
        """.trimIndent())
        handler.postDelayed({
            pendingLyricResults.remove(requestId)?.error("timeout", "音源歌词获取超时", null)
        }, 20_000)
    }

    fun clear(result: MethodChannel.Result) {
        pendingLoad?.error("cancelled", "音源脚本已移除", null)
        pendingLoad = null
        cancelPendingRequests("音源脚本已移除")
        script = ""
        loaded = false
        sources = emptySet()
        lyricSources = emptySet()
        webView?.let(::resetWebView)
        result.success(null)
    }

    fun dispose() {
        pendingLoad?.error("cancelled", "音源运行时已关闭", null)
        pendingLoad = null
        cancelPendingRequests("音源运行时已关闭")
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
                    evaluateUserScript()
                }
            }
            webView = view
        }
    }

    private fun evaluateUserScript() = evaluate(
        """
          window.__coralScriptInfo = { rawScript: ${JSONObject.quote(script)} };
          $BRIDGE_SCRIPT
          window.addEventListener('error', (event) => NativeBridge.scriptError(String(event.message || '音源脚本执行失败')));
          window.addEventListener('unhandledrejection', (event) => {
            const reason = event.reason;
            NativeBridge.scriptError(String(reason && reason.message || reason || '音源脚本初始化失败'));
          });
          try {
            $script
          } catch (error) {
            NativeBridge.scriptError(String(error && error.message || error || '音源脚本执行失败'));
          }
        """.trimIndent(),
    )

    private fun evaluate(script: String) {
        handler.post { webView?.evaluateJavascript(script, null) }
    }

    private fun resetWebView(view: WebView) = view.loadDataWithBaseURL(
        "https://localhost.invalid/",
        "<html><body></body></html>",
        "text/html",
        "UTF-8",
        null,
    )

    private fun cancelPendingRequests(message: String) {
        pendingResults.values.forEach { it.error("cancelled", message, null) }
        pendingResults.clear()
        pendingLyricResults.values.forEach { it.error("cancelled", message, null) }
        pendingLyricResults.clear()
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
                    val lyricEnabled = buildSet {
                        sourceObject.keys().forEach { source ->
                            val info = sourceObject.optJSONObject(source)
                            val actions = info?.optJSONArray("actions")
                            if (info?.optString("type") == "music" && actions?.toString()?.contains("lyric") == true) add(source)
                        }
                    }
                    if (enabled.isEmpty()) throw IllegalArgumentException("音源脚本未声明可用的 musicUrl 来源")
                    sources = enabled
                    lyricSources = lyricEnabled
                    loaded = true
                    pendingLoad?.success(mapOf("musicUrlSources" to enabled.toList(), "lyricSources" to lyricEnabled.toList()))
                    pendingLoad = null
                } catch (error: Exception) {
                    pendingLoad?.error("invalid_manifest", error.message, null)
                    pendingLoad = null
                }
            }
        }

        @JavascriptInterface
        fun scriptError(message: String) {
            handler.post {
                if (loaded || pendingLoad == null) return@post
                pendingLoad?.error("script_error", message.take(1024), null)
                pendingLoad = null
            }
        }

        @JavascriptInterface
        fun md5(value: String): String = MessageDigest.getInstance("MD5")
            .digest(value.toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it.toInt() and 0xff) }

        @JavascriptInterface
        fun randomBytes(size: Int): String {
            require(size in 1..4096) { "随机字节长度超出限制" }
            return android.util.Base64.encodeToString(
                ByteArray(size).also(SecureRandom()::nextBytes),
                android.util.Base64.NO_WRAP,
            )
        }

        @JavascriptInterface
        fun request(id: String, rawUrl: String, rawOptions: String) {
            val url = Uri.parse(rawUrl)
            if (url.scheme != "https" || url.host.isNullOrEmpty()) {
                Log.w("CoralUserApi", "blocked request scheme=${url.scheme ?: "missing"}")
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
                    Log.d("CoralUserApi", "request status=$status method=$method")
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
                    Log.w("CoralUserApi", "request failed=${error::class.java.simpleName}")
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
                    if (!data.optBoolean("ok")) {
                        result.error("source_error", data.optString("error", "音源取链失败").take(1024), null)
                        return@post
                    }
                    val rawValue = data.opt("value")
                    val value = when (rawValue) {
                        is String -> rawValue
                        is JSONObject -> rawValue.optJSONObject("data")
                            ?.optString("url")
                            ?.takeIf(String::isNotBlank)
                            ?: rawValue.optString("url").takeIf(String::isNotBlank)
                        else -> null
                    } ?: throw IllegalArgumentException("音源未返回播放地址")
                    val uri = Uri.parse(value)
                    if (uri.scheme !in setOf("http", "https") || uri.host.isNullOrEmpty() || value.length > 8192) {
                        result.error("invalid_result", "音源未返回有效的 HTTP 播放地址", null)
                    } else {
                        result.success(value)
                    }
                } catch (error: Exception) {
                    result.error("invalid_result", "音源未返回有效的 HTTP 播放地址", null)
                }
            }
        }

        @JavascriptInterface
        fun lyricResult(id: String, rawResult: String) {
            handler.post {
                val result = pendingLyricResults.remove(id) ?: return@post
                try {
                    val data = JSONObject(rawResult)
                    if (!data.optBoolean("ok")) {
                        result.error("invalid_result", "音源歌词获取失败", null)
                        return@post
                    }
                    val value = data.opt("value")
                    val payload = when (value) {
                        is JSONObject -> value.toString()
                        is String -> JSONObject().put("lyric", value).toString()
                        else -> throw IllegalArgumentException()
                    }
                    if (payload.length > 256 * 1024) throw IllegalArgumentException()
                    result.success(payload)
                } catch (error: Exception) {
                    result.error("invalid_result", "音源未返回有效歌词", null)
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
              let body = result.body;
              try { body = JSON.parse(body); } catch (_) {}
              const response = result.response || null;
              if (response) response.body = body;
              callback(result.error ? new Error(result.error) : null, response, body);
            };
            const bridge = {
              EVENT_NAMES: { request: 'request', inited: 'inited' },
              on(event, callback) {
                if (event !== 'request') return Promise.reject(new Error('Unsupported event'));
                window.__coralRequestHandler = callback;
                return Promise.resolve();
              },
              send(event, data) {
                if (event === 'inited') NativeBridge.ready(JSON.stringify(data));
                else if (event !== 'updateAlert') return Promise.reject(new Error('Unsupported event'));
                return Promise.resolve();
              },
              request(url, options = {}, callback) {
                const id = String(++nextId);
                callbacks[id] = callback;
                NativeBridge.request(id, String(url), JSON.stringify(options));
                return () => delete callbacks[id];
              },
              utils: {
                crypto: {
                  md5(value) { return NativeBridge.md5(String(value)); },
                  randomBytes(size) {
                    const bytes = atob(NativeBridge.randomBytes(Number(size)));
                    return Uint8Array.from(bytes, (value) => value.charCodeAt(0));
                  },
                  aesEncrypt() { return Promise.reject(new Error('当前受限运行时不支持 AES 加密')); },
                  rsaEncrypt() { return Promise.reject(new Error('当前受限运行时不支持 RSA 加密')); },
                },
                buffer: {
                  from(value) {
                    if (value instanceof Uint8Array) return value;
                    if (Array.isArray(value)) return Uint8Array.from(value);
                    throw new Error('当前受限运行时仅支持字节数组');
                  },
                  bufToString(value) { return new TextDecoder().decode(value); },
                },
                zlib: {
                  inflate() { return Promise.reject(new Error('当前受限运行时不支持 zlib 解压')); },
                  deflate() { return Promise.reject(new Error('当前受限运行时不支持 zlib 压缩')); },
                },
              },
              currentScriptInfo: window.__coralScriptInfo,
              env: 'mobile',
              version: '2.0.0',
            };
            window.lx = bridge;
            window.coral = bridge;
          })();
        """
    }
}
