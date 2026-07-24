import http from '@ohos.net.http';
import connection from '@ohos.net.connection';
import url from '@ohos.url';
import { FlutterPlugin, FlutterPluginBinding, MethodCall, MethodCallHandler, MethodChannel, MethodResult } from '@ohos/flutter_ohos';
import { userApiWebController } from './UserApiWebRuntime';

const SCRIPT_LIMIT = 256 * 1024;
const REQUEST_LIMIT = 64 * 1024;
const RESPONSE_LIMIT = 1024 * 1024;
const TIMEOUT_MS = 20 * 1000;
// User API source text is evaluated only in this local, network-disabled page.
const EMPTY_DOCUMENT = '<html><head><meta http-equiv="Content-Security-Policy" content="default-src \'none\'; connect-src \'none\'; script-src \'unsafe-eval\'"></head><body></body></html>';
const DOCUMENT_URL = 'https://localhost.invalid/';

interface NativeHttpResponse {
  statusCode: number;
  statusMessage: string;
  headers: Object;
  bytes: number;
  raw: string;
  body: string;
}

interface NativeHttpRequestResult {
  error: string;
  body?: string;
  response?: NativeHttpResponse;
}

interface UserApiLoadResponse {
  musicUrlSources: Array<string>;
  musicUrlQualities: Record<string, Array<string>>;
}

interface UserApiRequestInfo {
  type: string;
  musicInfo: Object;
}

interface UserApiResolveRequest {
  source: string;
  action: string;
  info: UserApiRequestInfo;
}

interface UserApiResolvedUrl {
  url: string;
  type: string;
}

class EmptyUserApiMusicInfo {}

export default class OhosUserApiPlugin implements FlutterPlugin, MethodCallHandler {
  private static instance: OhosUserApiPlugin | null = null;
  private static webReady = false;
  private static documentReady = false;
  private static proxyRegistered = false;
  private channel: MethodChannel | null = null;
  private loaded = false;
  private sources: Array<string> = [];
  private runtimeVersion = 0;
  private initializationError = '';
  private manifest: Record<string, Object> | null = null;
  private scriptError = '';
  private resolveSequence = 0;
  private resolveResults: Map<string, string> = new Map<string, string>();

  static onWebReady(): void {
    OhosUserApiPlugin.webReady = true;
    OhosUserApiPlugin.instance?.bootstrapWeb();
  }

  static onWebDocumentReady(): void {
    OhosUserApiPlugin.documentReady = true;
  }

  static onWebDocumentBegin(): void {
    OhosUserApiPlugin.documentReady = false;
  }

  async ready(raw: string): Promise<void> {
    try {
      const manifest = this.decode(raw);
      if (manifest == null || typeof manifest !== 'object') {
        this.scriptError = '音源脚本返回了无效的来源声明';
        return;
      }
      this.manifest = manifest as Record<string, Object>;
    } catch (error) {
      this.scriptError = this.message(error);
    }
  }

  async reportScriptError(message: string): Promise<void> {
    this.scriptError = `${message || '音源脚本初始化失败'}`.slice(0, 1024);
  }

  getUniqueClassName(): string { return 'OhosUserApiPlugin'; }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    OhosUserApiPlugin.instance = this;
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'coral_music/user_api');
    this.channel.setMethodCallHandler(this);
    this.bootstrapWeb();
  }

  onDetachedFromEngine(_: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null);
    this.channel = null;
    this.clearState();
    OhosUserApiPlugin.webReady = false;
    OhosUserApiPlugin.documentReady = false;
    OhosUserApiPlugin.proxyRegistered = false;
    OhosUserApiPlugin.instance = null;
  }

  async onMethodCall(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      if (call.method === 'clear') {
        this.resetRuntime();
        result.success(null);
        return;
      }
      if (call.method === 'load') {
        const script = call.argument('script') as string;
        result.success(await this.load(script));
        return;
      }
      if (call.method === 'resolveMusicUrl') {
        result.success(await this.resolve(call.argument('source') as string, call.argument('quality') as string, call.argument('musicInfo')));
        return;
      }
      result.notImplemented();
    } catch (error) {
      result.error('user_api_error', this.message(error), null);
    }
  }

  // ArkWeb async JavaScript proxies cannot return a value. Start the request
  // synchronously, then send the result back through __coralRequestDone.
  request(raw: string): void {
    const version = this.runtimeVersion;
    void this.startRequest(raw, version);
  }

  // runJavaScript cannot return an async JavaScript result. The page sends the
  // resolved value through this synchronous proxy instead.
  resolveDone(raw: string): void {
    try {
      const value = this.decode(raw);
      if (value == null || typeof value !== 'object') return;
      const result = value as Record<string, Object>;
      const id = `${result['id'] ?? ''}`;
      if (id && id.startsWith(`${this.runtimeVersion}:`)) {
        this.resolveResults.set(id, JSON.stringify(result) ?? '');
      }
    } catch (_) { }
  }

  private async startRequest(raw: string, version: number): Promise<void> {
    let id = '';
    try {
      const value = this.decode(raw);
      if (value == null || typeof value !== 'object') {
        throw new Error('音源请求参数无效');
      }
      const request = value as Record<string, Object>;
      id = `${request['id'] ?? ''}`;
      if (!id) throw new Error('音源请求缺少标识');
      const payload = await this.performRequest(request);
      if (version === this.runtimeVersion) await this.completeRequest(id, payload);
    } catch (error) {
      if (id && version === this.runtimeVersion) {
        const failure: NativeHttpRequestResult = { error: this.message(error) };
        await this.completeRequest(id, JSON.stringify(failure));
      }
    }
  }

  private async performRequest(value: Record<string, Object>): Promise<string> {
    try {
      const rawUrl = `${value['url'] ?? ''}`;
      const parsed = new url.URL(rawUrl);
      if ((parsed.protocol !== 'http:' && parsed.protocol !== 'https:') ||
          !parsed.hostname || !(await this.isPublicHost(parsed.hostname))) {
        throw new Error('仅允许公开 HTTP/HTTPS 请求');
      }
      const options = value['options'] as Record<string, Object> | undefined;
      const method = `${options?.['method'] ?? 'GET'}`.toUpperCase();
      if (method !== 'GET' && method !== 'POST') throw new Error('只允许 GET 或 POST 请求');
      if (options?.['formData'] != null) throw new Error('当前受限运行时不支持 multipart 表单');
      const body = this.requestBody(options);
      if (body.length > REQUEST_LIMIT) throw new Error('请求体超过大小限制');
      const timeout = this.requestTimeout(options);
      const headers = this.safeHeaders(options?.['headers']);
      if (method === 'POST' && this.usesFormEncoding(options) && !this.hasHeader(headers, 'content-type')) {
        headers['Content-Type'] = 'application/x-www-form-urlencoded; charset=UTF-8';
      }
      const task = http.createHttp();
      try {
        const response = await task.request(rawUrl, {
          method: method === 'POST' ? http.RequestMethod.POST : http.RequestMethod.GET,
          extraData: method === 'POST' ? body : '',
          header: headers,
          connectTimeout: timeout,
          readTimeout: timeout,
          expectDataType: http.HttpDataType.STRING,
          usingCache: false,
        });
        const responseBody = typeof response.result === 'string'
          ? response.result
          : JSON.stringify(response.result ?? '') ?? '';
        if (responseBody.length > RESPONSE_LIMIT) throw new Error('响应超过大小限制');
        const responsePayload: NativeHttpResponse = {
          statusCode: response.responseCode,
          statusMessage: '',
          headers: response.header ?? {},
          bytes: responseBody.length,
          raw: responseBody,
          body: responseBody,
        };
        const responseResult: NativeHttpRequestResult = {
          error: '',
          body: responseBody,
          response: responsePayload,
        };
        return JSON.stringify(responseResult);
      } finally {
        task.destroy();
      }
    } catch (error) {
      const failure: NativeHttpRequestResult = { error: this.message(error) };
      return JSON.stringify(failure);
    }
  }

  private async completeRequest(id: string, payload: string): Promise<void> {
    try {
      await userApiWebController.runJavaScript(
        `if (typeof window.__coralRequestDone === 'function') window.__coralRequestDone(${JSON.stringify(id)}, ${JSON.stringify(payload)});`,
      );
    } catch (_) { }
  }

  private bootstrapWeb(): void {
    if (!OhosUserApiPlugin.webReady || OhosUserApiPlugin.proxyRegistered) return;
    try {
      userApiWebController.registerJavaScriptProxy(
        this,
        'coralNative',
        ['request', 'resolveDone'],
        ['ready', 'reportScriptError'],
        DOCUMENT_URL,
      );
      OhosUserApiPlugin.proxyRegistered = true;
      this.resetDocument();
    } catch (error) {
      this.initializationError = this.message(error);
    }
  }

  private async load(script: string): Promise<Object> {
    if (!script || script.trim().length === 0 || script.length > SCRIPT_LIMIT) {
      throw new Error('音源脚本为空或超过大小限制');
    }
    if (!OhosUserApiPlugin.webReady || !OhosUserApiPlugin.documentReady) {
      throw new Error('音源运行时正在初始化，请稍后重试');
    }
    const version = this.resetRuntime();
    await this.waitForDocument(version);
    await userApiWebController.runJavaScript(`(() => {
      window.__coralManifest = null;
      window.__coralScriptInfo = { rawScript: ${JSON.stringify(script)} };
      window.fetch = () => Promise.reject(new Error('当前受限运行时禁止直接网络请求'));
      window.XMLHttpRequest = class { constructor() { throw new Error('当前受限运行时禁止直接网络请求'); } };
      window.WebSocket = class { constructor() { throw new Error('当前受限运行时禁止直接网络请求'); } };
      const reportScriptError = (error) => {
        const message = String(error && error.message || error || '音源脚本初始化失败').slice(0, 1024);
        try { if (typeof coralNative !== 'undefined' && typeof coralNative.reportScriptError === 'function') coralNative.reportScriptError(message); } catch (_) {}
      };
      window.addEventListener('error', (event) => reportScriptError(event.error || event.message));
      window.addEventListener('unhandledrejection', (event) => reportScriptError(event.reason));
      const md5 = (input) => {
        const source = new TextEncoder().encode(String(input)); const bits = source.length * 8;
        const size = (((source.length + 8) >>> 6) + 1) * 64; const bytes = new Uint8Array(size);
        bytes.set(source); bytes[source.length] = 0x80; const view = new DataView(bytes.buffer);
        view.setUint32(size - 8, bits >>> 0, true); view.setUint32(size - 4, Math.floor(bits / 0x100000000), true);
        const shift = [7,12,17,22,7,12,17,22,7,12,17,22,7,12,17,22,5,9,14,20,5,9,14,20,5,9,14,20,5,9,14,20,4,11,16,23,4,11,16,23,4,11,16,23,4,11,16,23,6,10,15,21,6,10,15,21,6,10,15,21,6,10,15,21];
        const constants = Array.from({ length: 64 }, (_, i) => Math.floor(Math.abs(Math.sin(i + 1)) * 0x100000000) >>> 0);
        let a0 = 0x67452301, b0 = 0xefcdab89, c0 = 0x98badcfe, d0 = 0x10325476;
        const rotate = (value, count) => (value << count) | (value >>> (32 - count));
        for (let offset = 0; offset < size; offset += 64) { let a = a0, b = b0, c = c0, d = d0;
          for (let i = 0; i < 64; i++) { let f, g; if (i < 16) { f = (b & c) | (~b & d); g = i; } else if (i < 32) { f = (d & b) | (~d & c); g = (5 * i + 1) % 16; } else if (i < 48) { f = b ^ c ^ d; g = (3 * i + 5) % 16; } else { f = c ^ (b | ~d); g = (7 * i) % 16; } const sum = (a + f + constants[i] + view.getUint32(offset + g * 4, true)) >>> 0; a = d; d = c; c = b; b = (b + rotate(sum, shift[i])) >>> 0; }
          a0 = (a0 + a) >>> 0; b0 = (b0 + b) >>> 0; c0 = (c0 + c) >>> 0; d0 = (d0 + d) >>> 0; }
        return [a0,b0,c0,d0].map(word => [0,8,16,24].map(s => ((word >>> s) & 255).toString(16).padStart(2, '0')).join('')).join('');
      };
      const callbacks = {};
      window.__coralRequestDone = (id, raw) => {
        const callback = callbacks[id]; delete callbacks[id];
        if (typeof callback !== 'function') return;
        let value = raw;
        for (let attempt = 0; attempt < 2 && typeof value === 'string'; attempt++) {
          try { value = JSON.parse(value); } catch (_) { break; }
        }
        if (!value || typeof value !== 'object') {
          callback(new Error('音源请求返回格式无效'), null, null);
          return;
        }
        let body = typeof value.body === 'string' ? value.body : '';
        try { body = JSON.parse(body); } catch (_) {}
        const response = value.response && typeof value.response === 'object' ? value.response : null;
        const error = value.error ? new Error(String(value.error)) : null;
        if (!error && !response) {
          callback(new Error('音源请求未返回响应'), null, null);
          return;
        }
        if (response) response.body = body;
        callback(error, response, body);
      };
      let sequence = 0;
      window.__coralRequestHandler = null;
      window.lx = window.coral = {
        on(event, callback) { if (event !== 'request') return Promise.reject(new Error('Unsupported event')); window.__coralRequestHandler = callback; return Promise.resolve(); },
        send(event, data) { if (event === 'inited') { window.__coralManifest = data; try { if (typeof coralNative !== 'undefined' && typeof coralNative.ready === 'function') coralNative.ready(JSON.stringify(data)); } catch (_) {} return Promise.resolve(); } if (event === 'updateAlert') return Promise.resolve(); return Promise.reject(new Error('Unsupported event')); },
        request(url, options = {}, callback) { const id = String(++sequence); if (typeof callback === 'function') callbacks[id] = callback; try { coralNative.request(JSON.stringify({ id, url: String(url), options })); } catch (error) { delete callbacks[id]; if (typeof callback === 'function') callback(error instanceof Error ? error : new Error(String(error)), null, null); } return () => delete callbacks[id]; },
        utils: { crypto: { md5, randomBytes(size) { const bytes = new Uint8Array(Number(size)); if (bytes.length < 1 || bytes.length > 4096) throw new Error('随机字节长度超出限制'); crypto.getRandomValues(bytes); return bytes; }, aesEncrypt() { return Promise.reject(new Error('当前受限运行时不支持 AES 加密')); }, rsaEncrypt() { return Promise.reject(new Error('当前受限运行时不支持 RSA 加密')); } }, buffer: { from(value) { if (value instanceof Uint8Array) return value; if (Array.isArray(value)) return Uint8Array.from(value); throw new Error('当前受限运行时仅支持字节数组'); }, bufToString(value) { return new TextDecoder().decode(value); } }, zlib: { inflate() { return Promise.reject(new Error('当前受限运行时不支持 zlib 解压')); }, deflate() { return Promise.reject(new Error('当前受限运行时不支持 zlib 压缩')); } } },
        EVENT_NAMES: { request: 'request', inited: 'inited' }, currentScriptInfo: window.__coralScriptInfo, env: 'mobile', version: '2.0.0'
      };
      try { (0, eval)(${JSON.stringify(script)}); } catch (error) { reportScriptError(error); }
    })()`);
    const manifest = await this.waitForManifest(version);
    const declared = manifest?.['sources'] as Record<string, Record<string, Object>> | undefined;
    const sources: Array<string> = [];
    const qualities: Record<string, Array<string>> = {};
    if (declared) Object.keys(declared).forEach((source) => {
      const item = declared[source];
      const actions = item['actions'] as Array<string> | undefined;
      if (item['type'] === 'music' && actions?.includes('musicUrl')) {
        sources.push(source);
        const declaredQualities = (item['qualitys'] ?? item['qualities']) as Array<string> | undefined;
        if (declaredQualities && declaredQualities.length > 0) qualities[source] = declaredQualities;
      }
    });
    if (sources.length === 0) throw new Error('音源脚本未声明可用的 musicUrl 来源');
    this.sources = sources;
    this.loaded = true;
    const response: UserApiLoadResponse = {
      musicUrlSources: sources,
      musicUrlQualities: qualities,
    };
    return response;
  }

  private async resolve(source: string, quality: string, musicInfo: Object): Promise<Object> {
    if (!this.loaded || !this.sources.includes(source)) throw new Error('当前音源未支持该歌曲来源');
    const resolvedMusicInfo: Object = musicInfo ?? new EmptyUserApiMusicInfo();
    const requestInfo: UserApiRequestInfo = {
      type: quality || '128k',
      musicInfo: resolvedMusicInfo,
    };
    const request: UserApiResolveRequest = {
      source,
      action: 'musicUrl',
      info: requestInfo,
    };
    const version = this.runtimeVersion;
    const id = `${version}:${++this.resolveSequence}`;
    const payload = JSON.stringify(request);
    try {
      // Do not return the Promise from this script: ArkWeb reports no value for
      // asynchronous JavaScript evaluation. resolveDone carries the envelope.
      await userApiWebController.runJavaScript(`(() => {
        const id = ${JSON.stringify(id)};
        const complete = (value) => {
          try { coralNative.resolveDone(JSON.stringify(value)); }
          catch (_) { try { coralNative.resolveDone(JSON.stringify({ id, ok: false, error: '音源取链结果无法序列化' })); } catch (_) {} }
        };
        Promise.resolve().then(() => {
          if (typeof window.__coralRequestHandler !== 'function') throw new Error('音源脚本未注册请求处理器');
          return window.__coralRequestHandler(${payload});
        }).then(
          value => complete({ id, ok: true, value }),
          error => complete({ id, ok: false, error: String(error && error.message || error) }),
        );
      })()`);
      const envelope = await this.waitForResolve(id, version);
      if (envelope['ok'] !== true) throw new Error(`${envelope['error'] ?? '音源取链失败'}`);
      const result = envelope['value'];
      let url = '';
      let type = '';
      if (typeof result === 'string') {
        url = result;
      } else if (result != null && typeof result === 'object') {
        const rawResult = result as Record<string, Object>;
        const data = rawResult['data'];
        const detail = data != null && typeof data === 'object'
          ? data as Record<string, Object>
          : rawResult;
        url = `${detail['url'] ?? ''}`;
        type = `${detail['type'] ?? ''}`;
      } else {
        throw new Error('音源未返回播放地址');
      }
      if (!/^https?:\/\/[^/]+/i.test(url) || url.length > 8192) throw new Error('音源未返回有效的 HTTP 播放地址');
      const response: UserApiResolvedUrl = { url, type };
      return response;
    } finally {
      this.resolveResults.delete(id);
    }
  }

  private resetRuntime(): number {
    this.clearState();
    this.runtimeVersion += 1;
    this.resetDocument();
    return this.runtimeVersion;
  }

  private resetDocument(): void {
    if (!OhosUserApiPlugin.webReady) return;
    OhosUserApiPlugin.documentReady = false;
    try {
      userApiWebController.loadData(EMPTY_DOCUMENT, 'text/html', 'UTF-8', DOCUMENT_URL);
    } catch (error) {
      this.initializationError = this.message(error);
    }
  }

  private clearState(): void {
    this.loaded = false;
    this.sources = [];
    this.manifest = null;
    this.scriptError = '';
    this.resolveResults.clear();
  }

  private async waitForResolve(id: string, version: number): Promise<Record<string, Object>> {
    for (let attempt = 0; attempt < 80; attempt++) {
      if (version !== this.runtimeVersion) throw new Error('音源脚本已被替换');
      const raw = this.resolveResults.get(id);
      if (raw) {
        const value = this.decode(raw);
        if (value != null && typeof value === 'object') return value as Record<string, Object>;
        throw new Error('音源取链返回格式无效');
      }
      await new Promise<void>((resolve) => setTimeout(resolve, 250));
    }
    throw new Error('音源取链超时');
  }

  private async waitForDocument(version: number): Promise<void> {
    if (this.initializationError) throw new Error(this.initializationError);
    for (let attempt = 0; attempt < 80; attempt++) {
      if (version !== this.runtimeVersion) throw new Error('音源脚本已被替换');
      if (OhosUserApiPlugin.documentReady) return;
      await new Promise<void>((resolve) => setTimeout(resolve, 250));
    }
    throw new Error('音源运行时初始化超时');
  }

  private async waitForManifest(version: number): Promise<Record<string, Object>> {
    for (let attempt = 0; attempt < 80; attempt++) {
      if (version !== this.runtimeVersion) throw new Error('音源脚本已被替换');
      if (this.scriptError) throw new Error(this.scriptError);
      if (this.manifest !== null) return this.manifest;
      const raw = await userApiWebController.runJavaScript('JSON.stringify(window.__coralManifest)');
      try {
        const manifest = this.decode(raw);
        if (manifest && typeof manifest === 'object') return manifest as Record<string, Object>;
      } catch (_) { }
      await new Promise<void>((resolve) => setTimeout(resolve, 250));
    }
    throw new Error('音源脚本初始化超时');
  }

  private requestTimeout(options: Record<string, Object> | undefined): number {
    const value = Number(options?.['timeout'] ?? TIMEOUT_MS);
    return Number.isFinite(value) ? Math.max(1000, Math.min(TIMEOUT_MS, value)) : TIMEOUT_MS;
  }

  private requestBody(options: Record<string, Object> | undefined): string {
    const raw = options?.['body'];
    if (raw != null) return typeof raw === 'string' ? raw : JSON.stringify(raw);
    const form = options?.['form'];
    if (form == null || typeof form !== 'object') return '';
    return Object.keys(form as Object).sort().map((key) =>
      `${encodeURIComponent(key)}=${encodeURIComponent(`${(form as Record<string, Object>)[key] ?? ''}`)}`
    ).join('&');
  }

  private usesFormEncoding(options: Record<string, Object> | undefined): boolean {
    return options?.['body'] == null && options?.['form'] != null;
  }

  private hasHeader(headers: Record<string, string>, name: string): boolean {
    return Object.keys(headers).some((key) => key.toLowerCase() === name);
  }

  private safeHeaders(raw: Object | undefined): Record<string, string> {
    const headers: Record<string, string> = {};
    if (raw == null || typeof raw !== 'object') return headers;
    Object.keys(raw).forEach((key) => {
      if (!['host', 'connection', 'content-length'].includes(key.toLowerCase())) {
        headers[key] = `${(raw as Record<string, Object>)[key] ?? ''}`;
      }
    });
    return headers;
  }

  private async isPublicHost(host: string): Promise<boolean> {
    const value = this.normalizeHost(host);
    if (this.isPrivateAddress(value)) return false;
    try {
      const addresses = await connection.getAddressesByName(value);
      return addresses.length > 0 && addresses.every((address) =>
        !this.isPrivateAddress(this.normalizeHost(address.address))
      );
    } catch (_) {
      return false;
    }
  }

  private normalizeHost(host: string): string {
    return host.toLowerCase().replace(/^\[|\]$/g, '');
  }

  private isPrivateAddress(value: string): boolean {
    if (value === 'localhost' || value.endsWith('.local')) return true;
    const ipv4 = value.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/);
    if (ipv4) {
      const parts = ipv4.slice(1).map((part) => Number(part));
      const first = parts[0];
      const second = parts[1];
      if (parts.some((part) => part > 255)) return true;
      return first === 0 || first === 10 || first === 127 ||
        (first === 100 && second >= 64 && second <= 127) ||
        (first === 169 && second === 254) ||
        (first === 172 && second >= 16 && second <= 31) ||
        (first === 192 && second === 168) ||
        (first === 198 && (second === 18 || second === 19)) || first >= 224;
    }
    const mappedIpv4 = value.match(/^::ffff:(.+)$/);
    if (mappedIpv4) return this.isPrivateAddress(mappedIpv4[1]);
    return value === '::' || value === '::1' || value.startsWith('fc') ||
      value.startsWith('fd') || /^fe[89ab]/.test(value) || value.startsWith('ff');
  }

  private decode(raw: string | null): Object | null {
    if (raw == null || raw.trim().length === 0) return null;
    let value = JSON.parse(raw) as Object | string | null;
    if (typeof value === 'string') value = JSON.parse(value) as Object | null;
    return value;
  }

  private message(error: Object): string { return error instanceof Error ? error.message : `${error}`; }
}
