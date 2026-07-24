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

import { media } from '@kit.MediaKit';
import { LoopMode } from './MediaAvPlayer'
import { Log } from '@ohos/flutter_ohos';

export default class MediaSource implements media.MediaSource {
  // OpenHarmony API 20 (DevEco 6.1.1) made this interface member mandatory.
  enableOfflineCache(enable: boolean): void {}
  header: Record<string, string> | null = null
  id: string = "";
  uri: string = "";
  type: string = "";
  startUs: number = 0;
  endUs: number = 0;
  isAtomic: boolean = false;
  useLazyPreparation: boolean = false;
  musicPlayMode: LoopMode = LoopMode.DEFAULT
  shuffleOrder: number[] = []
  childMediaSource: MediaSource[] = []
  mimeType: media.AVMimeTypes = media.AVMimeTypes.APPLICATION_M3U8

  setStartUs(startUs: number): MediaSource {
    this.startUs = startUs;
    return this;
  }

  setEndUs(endUs: number): MediaSource {
    this.endUs = endUs;
    return this;
  }

  getStartUs(): number {
    return this.startUs
  }

  getEndUs(): number {
    return this.endUs
  }

  setMimeType(mimeType: media.AVMimeTypes): MediaSource {
    this.mimeType = mimeType;
    return this;
  }

  setMediaResourceLoaderDelegate(): void {
    Log.d("MediaSource", "empty implement")
  }

  getMimeType(): media.AVMimeTypes {
    return this.mimeType;
  }

  setHeader(header: Record<string, string>) {
    this.header = header
  }

  getHeader(): Record<string, string> | null {
    return this.header;
  }

  setId(id: string): MediaSource {
    this.id = id;
    return this;
  }

  getId(): string {
    return this.id;
  }

  setUri(uri: string): MediaSource {
    this.uri = uri;
    return this;
  }

  getUri(): string {
    return this.uri;
  }

  setType(type: string): MediaSource {
    this.type = type;
    return this;
  }

  getType(): string {
    return this.type;
  }

  setAtomic(isAtomic: boolean): MediaSource {
    this.isAtomic = isAtomic;
    return this;
  }

  setMusicPlayMode(musicPlayMode: LoopMode): MediaSource {
    this.musicPlayMode = musicPlayMode;
    return this;
  }

  getMusicPlayMode(): LoopMode {
    return this.musicPlayMode
  }

  IsAtomic(): boolean {
    return this.isAtomic;
  }

  setUseLazyPreparation(useLazyPreparation: boolean): MediaSource {
    this.useLazyPreparation = useLazyPreparation;
    return this;
  }

  IsUseLazyPreparation(): boolean {
    return this.useLazyPreparation;
  }

  setShuffleOrder(shuffleOrder: number[]): MediaSource {
    this.shuffleOrder = shuffleOrder;
    return this;
  }

  getShuffleOrder(): number[] {
    return this.shuffleOrder
  }

  setChildMediaSource(childMediaSource: MediaSource[]): MediaSource {
    this.childMediaSource = childMediaSource
    return this;
  }

  getChildMediaSource(): MediaSource[] {
    return this.childMediaSource
  }
}
