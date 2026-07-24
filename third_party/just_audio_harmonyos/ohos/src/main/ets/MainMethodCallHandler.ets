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

import { BinaryMessenger, MethodCall, MethodCallHandler, MethodResult } from '@ohos/flutter_ohos';
import { AudioPlayer } from './AudioPlayer'

export class MainMethodCallHandler implements MethodCallHandler {
  private applicationContext: Context;
  private messenger: BinaryMessenger;
  private players: Map<string, AudioPlayer> = new Map<string, AudioPlayer>();

  constructor(applicationContext: Context,
    messenger: BinaryMessenger) {
    this.applicationContext = applicationContext;
    this.messenger = messenger;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'init':
        let id: string = call.argument("id");
        if (this.players.has(id)) {
          result.error("Platform player " + id + " already exists", null, null);
          break;
        }
        if (this.applicationContext && this.messenger) {
          this.players.set(id, new AudioPlayer(this.messenger, id));
        }
        result.success(null);
        break;
      case 'disposePlayer':
        let playerId: string = call.argument("id");
        let player: AudioPlayer | undefined = this.players.get(playerId);
        if (player != null) {
          player.dispose();
          this.players.delete(playerId);
        }
        result.success(new Map<String, Object>());
        break;
      case 'disposeAllPlayers':
        this.dispose();
        result.success(new Map<String, Object>());
        break;
      default:
        result.notImplemented();
        break;
    }

  }

  dispose() {
    this.players.forEach(player => {
      player.dispose();
    });
    this.players.clear();
  }
}