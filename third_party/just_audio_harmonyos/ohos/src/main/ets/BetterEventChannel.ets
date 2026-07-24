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

import { EventChannel, BinaryMessenger } from "@ohos/flutter_ohos"
import { EventSink, StreamHandler } from "@ohos/flutter_ohos/src/main/ets/plugin/common/EventChannel"

export class BetterEventChannel implements EventSink {
  private eventSink: EventSink | null = null;

  constructor(messenger: BinaryMessenger, id: string) {
    let eventChannel: EventChannel = new EventChannel(messenger, id);
    eventChannel.setStreamHandler({
      onListen: (args: Object, eventSink: EventSink) => {
        this.eventSink = eventSink;
      },
      onCancel: (args: Object) => {
        this.eventSink = null;
      }
    } as StreamHandler);
  }

  getEventSink(): EventSink | null {
    return this.eventSink
  }

  success(event: ESObject) {
    if (this.eventSink != null) {
      this.eventSink.success(event);
    }
  }

  error(errorCode: string, errorMessage: string, errorDetails: ESObject) {
    if (this.eventSink != null) {
      this.eventSink.error(errorCode, errorMessage, errorDetails);
    }
  }

  endOfStream() {
    if (this.eventSink != null) {
      this.eventSink.endOfStream();
    }
  }
}
