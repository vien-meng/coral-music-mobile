/**
 * Copyright (C) 2024 Huawei Device Co., Ltd.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 * */

import { FlutterPlugin, FlutterPluginBinding, MethodChannel, FlutterEngine, } from '@ohos/flutter_ohos';
import { EngineLifecycleListener } from '@ohos/flutter_ohos/src/main/ets/embedding/engine/FlutterEngine';
import { MainMethodCallHandler } from './MainMethodCallHandler'

/** JustAudioOhosPlugin **/
export default class JustAudioOhosPlugin implements FlutterPlugin {
  private channel: MethodChannel | null = null;
  private methodCallHandler: MainMethodCallHandler | null = null;

  getUniqueClassName(): string {
    return "JustAudioOhosPlugin"
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    let applicationContext = binding.getApplicationContext();
    AppStorage.setOrCreate('context', applicationContext)
    let messenger = binding.getBinaryMessenger();
    this.methodCallHandler = new MainMethodCallHandler(applicationContext, messenger);
    this.channel = new MethodChannel(messenger, "com.ryanheise.just_audio.methods");
    this.channel.setMethodCallHandler(this.methodCallHandler)
    let engine: FlutterEngine = binding.getFlutterEngine();
    engine.addEngineLifecycleListener({
      onPreEngineRestart: () => {
        this.methodCallHandler?.dispose();
      },
      onEngineWillDestroy: () => {

      }
    } as EngineLifecycleListener);
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.methodCallHandler?.dispose();
    this.methodCallHandler = null;
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null)
    }
  }
}