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
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR AInvoke avPlayer NY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 * */

import { MethodCallHandler, MethodCall, MethodChannel, MethodResult, Any, Log } from '@ohos/flutter_ohos';
import { BetterEventChannel } from './BetterEventChannel';
import { media } from '@kit.MediaKit';
import { BusinessError, systemDateTime } from '@kit.BasicServicesKit';
import { BinaryMessenger } from '@ohos/flutter_ohos';
import MediaSource from './MediaSource';
import { MediaAvPlayer, PlaybackState, onChangeMediaAvPlayerState, AudioPlayerState } from './MediaAvPlayer';

enum ProcessingState {
  none,
  loading,
  buffering,
  ready,
  completed
}

const TAG = "AudioPlayer";

export class AudioPlayer implements MethodCallHandler, onChangeMediaAvPlayerState {
  private pendingPlaybackEvent: Map<String, Object> | null = null;
  private methodChannel: MethodChannel | null = null;
  private eventChannel: BetterEventChannel | null = null;
  private dataEventChannel: BetterEventChannel | null = null;
  private bufferedPosition: number = 0;
  public static TIME_UNSET: number = -9223372036854775807;
  public static AUDIO_SESSION_ID_UNSET: number = 0;
  private initialPos: number | null = null;
  private initialIndex: number | null = null;
  private prepareResult: MethodResult | null = null;
  private playResult: MethodResult | null = null;
  private seekResult: MethodResult | null = null;
  private player: MediaAvPlayer | null = null;
  private mediaSource: MediaSource | null = null;
  private mediaSources: Map<String, MediaSource | undefined> = new Map<String, MediaSource | undefined>();
  private currentIndex: number = 0;
  private audioSessionId: number | null = null;
  private processingState: ProcessingState = ProcessingState.none;
  private seekPos: number | null = null;
  private updatePosition: number = 0;
  private updateTime: number = 0;
  private intervalID: number = 0;

  public constructor(messenger: BinaryMessenger, id: string) {
    this.player = new MediaAvPlayer();
    this.player.setMediaAvPlayerStateChange(this);
    this.methodChannel = new MethodChannel(messenger, "com.ryanheise.just_audio.methods." + id);
    this.methodChannel.setMethodCallHandler(this);
    this.eventChannel = new BetterEventChannel(messenger, "com.ryanheise.just_audio.events." + id);
    this.dataEventChannel = new BetterEventChannel(messenger, "com.ryanheise.just_audio.data." + id);
    this.processingState = ProcessingState.none;
  }

  onErrorCallback(err: BusinessError<void>): void {
    this.sendError(err.name,err.message)
  }

  onUpdateCurrentIndex(updateIndex: number): void {
    this.currentIndex = updateIndex;
    this.broadcastImmediatePlaybackEvent();
  }

  broadcastImmediatePlaybackEvent() {
    this.enqueuePlaybackEvent();
    this.broadcastPendingPlaybackEvent();
  }

  completeSeek() {
    this.seekPos = null;
    this.seekResult?.success(new Map<String, Object>());
    this.seekResult = null;
  }

  setAudioSessionId(audioSessionId: number) {
    if (audioSessionId == AudioPlayer.AUDIO_SESSION_ID_UNSET) {
      this.audioSessionId = null;
    } else {
      this.audioSessionId = audioSessionId;
    }
    this.enqueuePlaybackEvent();
  }

  onAudioSessionIdChanged(audioSessionId: number) {
    this.setAudioSessionId(audioSessionId);
    this.broadcastPendingPlaybackEvent();
  }

  onPlaybackStateChanged(state: PlaybackState) {
    switch (state) {
      case PlaybackState.STATE_READY:
        this.onUpdatePosition();
        this.processingState = ProcessingState.ready;
        this.broadcastImmediatePlaybackEvent();
        if (this.prepareResult != null) {
          let response: Map<String, Object> = new Map<String, Object>();
          response.set("duration", this.getDuration() == AudioPlayer.TIME_UNSET ? -1 : (1000 * this.getDuration()));
          this.prepareResult.success(response);
          this.prepareResult = null;
        }
        if (this.seekResult != null) {
          this.completeSeek();
        }
        break;
      case PlaybackState.STATE_BUFFERING:
        this.updatePositionIfChanged()
        if (this.processingState != ProcessingState.buffering && this.processingState != ProcessingState.loading) {
          this.processingState = ProcessingState.buffering;
          this.broadcastImmediatePlaybackEvent();
        }
        break;
      case PlaybackState.STATE_ENDED:
        if (this.processingState != ProcessingState.completed) {
          this.updatePosition = 0;
          this.processingState = ProcessingState.completed;
          this.broadcastImmediatePlaybackEvent();
        }
        if (this.prepareResult != null) {
          let response: Map<String, Object> = new Map<String, Object>();
          this.prepareResult.success(response);
          this.prepareResult = null;
        }
        if (this.playResult != null) {
          this.playResult.success(new Map<String, Object>());
          this.playResult = null;
        }
        break;
      case PlaybackState.IDLE:
          this.onUpdatePosition();
          this.processingState = ProcessingState.none;
          this.broadcastImmediatePlaybackEvent();
          if (this.prepareResult != null) {
            let response: Map<String, Object> = new Map<String, Object>();
            response.set("duration", -1);
            this.prepareResult.success(response);
            this.prepareResult = null;
          }
          if (this.seekResult != null) {
            this.completeSeek();
          }
        break;
    }
  }

  private updatePositionIfChanged(): boolean {
    let currentPosition = this.getCurrentPosition();
    if (currentPosition == this.updatePosition) {
      return false;
    }
    this.updatePosition = this.getCurrentPosition();
    this.updateTime = systemDateTime.getTime();
    return true;
  }

  public play(result: MethodResult) {
    this.player?.play(result);
    if (this.playResult != null) {
      this.playResult.success(new Map<String, Object>());
    }
    this.onUpdatePosition();
    if (this.processingState == ProcessingState.completed && this.playResult != null) {
      this.playResult.success(new Map<String, Object>());
      this.playResult = null;
    }
  }

  public pause(result: MethodResult) {
    this.player?.pause(result);
    this.onUpdatePosition();
    if (this.playResult != null) {
      this.playResult.success(new Map<String, Object>());
      this.playResult = null;
    }
  }

  private setVolume(volume: number) {
    this.player?.setVolume(volume);
  }

  private setSpeed(speed: number) {
    this.player?.setSpeed(speed);
    this.onUpdatePosition();
    this.enqueuePlaybackEvent();
  }

  private seek(position: number, index: number, result: MethodResult) {
    if (this.processingState == ProcessingState.none || this.processingState == ProcessingState.loading) {
      result.success(new Map<String, Object>());
      return;
    }
    this.abortSeek();
    this.seekPos = position;
    this.seekResult = result;
    try {
      this.player?.seek(position, index);
    } catch (e) {
      this.seekResult = null;
      this.seekPos = null;
      console.error(TAG, 'seek::error:' + JSON.stringify(e));
    }
  }

  private abortSeek() {
    if (this.seekResult != null) {
      try {
        this.seekResult.success(new Map<String, Object>());
      } catch (e) {
        console.error(TAG, 'abortSeek::error:' + JSON.stringify(e));
      }
      this.seekResult = null;
      this.seekPos = null;
    }
  }

  async onMethodCall(call: MethodCall, result: MethodResult) {
    try {
      switch (call.method) {
        //开始加载当前音频源，一旦已知或不可用，将立即返回音频时间为null
        case "load":
          let initialPosition: number = call.argument("initialPosition");
          let initialIndex: number = call.argument("initialIndex");
          await this.load(this.getAudioSource(call.argument("audioSource")),
            initialPosition == null ? AudioPlayer.TIME_UNSET : initialPosition / 1000,
            initialIndex, result);
          break;
      //播放
        case "play":
          this.play(result);
          break;
      //暂停
        case "pause":
          this.pause(result);
          break;
      //设置音量
        case "setVolume":
          this.setVolume(Number.parseFloat(call.argument("volume")));
          result.success(new Map<String, Object>());
          break;
      //设置速度
        case "setSpeed":
          if(this.player == null){
            result.error("setSpeed error: player is null",null,null);
            return;
          }
          //如果不在已准备、播放中、暂停、已完成状态下，avPlayer调用setPeed会提示操作不支持
          if(this.player.state != AudioPlayerState.PREPARED && this.player.state != AudioPlayerState.PLAY
            && this.player.state != AudioPlayerState.PAUSE && this.player.state != AudioPlayerState.COMPLETED){
            result.success(new Map<String, Object>());
            return;
          }
          this.setSpeed(call.argument("speed"));
          result.success(new Map<String, Object>());
          break;
      //设置声音的基频（音调）
        case "setPitch":
          result.success(new Map<String, Object>());
          break;
        case "setSkipSilence":
          result.success(new Map<String, Object>());
          break;
      //设置 LoopMode。
        case "setLoopMode":
          this.player?.setLoopMode(parseInt(call.argument("loopMode")));
          result.success(new Map<String, Object>());
          break;
      //设置是否启用随机播放模式
        case "setShuffleMode":
          this.player?.setShuffleMode(call.argument("shuffleMode") == 1);
          result.success(new Map<String, Object>());
          break;
      //设置随机顺序
        case "setShuffleOrder":
          let json: Map<Any, Any> = call.argument("audioSource");
          this.player?.setShuffleOrder(json.get("shuffleOrder"));
          this.setShuffleOrder(call.argument("audioSource"));
          result.success(new Map<String, Object>());
          break;
      //跳转到指定播放位置
        case "seek":
          let position: number = Number.parseInt(call.argument("position"));
          let index: number = Number.parseInt(call.argument("index"));
          this.seek(position == null ? AudioPlayer.TIME_UNSET : (position / 1000), index, result);
          break;
        case "concatenatingInsertAll":
          this.player?.addPublicMediaSources(call.argument("currentIndex"),
            this.getAudioSources(call.argument("children")));
          this.player?.setShuffleOrder(call.argument("shuffleOrder"));
          result.success(new Map<string,object>());
          break;
        case "concatenatingRemoveRange":
          this.player?.removeMediaSourceRange(call.argument("startIndex"),
            call.argument("endIndex"));
          this.player?.setShuffleOrder(call.argument("shuffleOrder"));
          result.success(new Map<string,object>());
          break;
        case "concatenatingMove":
          this.player?.moveMediaSource(call.argument("currentIndex"),
            call.argument("newIndex"));
          this.player?.setShuffleOrder(call.argument("shuffleOrder"));
          result.success(new Map<string,object>());
          break;
        default:
          result.notImplemented();
          break;
      }
    } catch (err) {
      result.error("Error: " + err.getMessage(), null, null);
    } finally {
      this.broadcastPendingPlaybackEvent();
    }
  }

  onStartBuffering() {
    this.processingState = ProcessingState.buffering;
    this.broadcastImmediatePlaybackEvent();
  }

  onEndBuffering() {
    this.processingState = ProcessingState.ready;
    this.broadcastImmediatePlaybackEvent();
  }

  private setShuffleOrder(json: Any) {
    let map: Map<Any, Any> = json;
    let id: string = map.get("id");
    let mediaSource: MediaSource = this.mediaSources.get(id) as MediaSource;
    if (mediaSource == null) {
      return;
    }
    switch (map.get("type")) {
      case "concatenating":
        mediaSource.setShuffleOrder(map.get("shuffleOrder"));
        let children: Array<Object> = map.get("children");
        children.forEach(child => {
          this.setShuffleOrder(child);
        });
        break;
      case "looping":
        this.setShuffleOrder(map.get("child"));
        break;
    }
  }

  dispose() {
    if (this.processingState == ProcessingState.loading) {
      this.abortExistingConnection();
    }
    if (this.playResult != null) {
      this.playResult.success(new Map<String, Object>());
      this.playResult = null;
    }
    clearInterval(this.intervalID);
    this.mediaSources.clear();
    this.mediaSource = null;
    if (this.player != null) {
      this.player.dispose();
      this.player = null;
      this.processingState = ProcessingState.none;
      this.broadcastImmediatePlaybackEvent();
    }
    this.eventChannel?.endOfStream();
    this.dataEventChannel?.endOfStream();
  }

  private decodeAudioSource(json: Any): MediaSource {
    let map: Map<Any, Any> = json;
    let id: string = this.mapGet(map, "id");
    let type: string = this.mapGet(map, "type");
    let header: Record<string, string> = this.mapGet(map, "headers")
    switch (this.mapGet(map, "type")) {
      case "progressive":
        let mediaSource: MediaSource = new MediaSource();
        mediaSource
          .setUri(decodeURIComponent(this.mapGet(map, "uri") as string))
          .setId(id)
          .setType(type);
        if (header) {
          mediaSource.setHeader(header);
        }
        return mediaSource;
      case "dash":
      case "hls":
        let dashMediaSource: MediaSource = new MediaSource();
        if (header) {
          dashMediaSource.setHeader(header);
        }
        dashMediaSource
          .setId(id)
          .setType(type).setMimeType(media.AVMimeTypes.APPLICATION_M3U8)
          .setUri(decodeURIComponent(this.mapGet(map, "uri") as string));

        return dashMediaSource;
      case "concatenating":
        let mediaSources: Array<MediaSource> = this.getAudioSourcesArray(this.mapGet(map, "children"));
        let concatenatingMediaSource = new MediaSource();
        concatenatingMediaSource
          .setId(id)
          .setType(type)
          .setMimeType(media.AVMimeTypes.APPLICATION_M3U8)
          .setAtomic(false)
          .setUseLazyPreparation(this.mapGet(map, "useLazyPreparation") as boolean)
          .setShuffleOrder(this.mapGet(map, "shuffleOrder"))
          .setChildMediaSource(mediaSources);
        return concatenatingMediaSource;
      case "clipping":
        let childMediaSource = this.getAudioSource(this.mapGet(map, "child"));
        let start = parseInt(this.mapGet(map, "start"));
        let end = parseInt(this.mapGet(map, "end"));
        let clippingMediaSource = new MediaSource();
        clippingMediaSource
          .setId(id)
          .setStartUs(start)
          .setEndUs(end)
          .setUri(decodeURIComponent(childMediaSource.getUri()))
          .setType(this.mapGet(map, "type"));
        return clippingMediaSource;
      case "looping":
        let count: number = this.mapGet(map, "count");
        let looperChild = this.getAudioSource(this.mapGet(map, "child"));
        let looperChildren: Array<MediaSource> = new Array<MediaSource>(count)
        for (let i = 0; i < looperChildren.length; i++) {
          looperChildren[i] = looperChild!;
        }
        let loopingMediaSource = new MediaSource();
        loopingMediaSource
          .setChildMediaSource(looperChildren)
          .setAtomic(false)
          .setId(id)
          .setType(type);
        return loopingMediaSource;
      default:
        throw new Error("Unknown AudioSource type: " + this.mapGet(map, "type"));
    }
  }

  private getAudioSourcesArray(json: Any): Array<MediaSource> {
    let mediaSources: Array<MediaSource> = this.getAudioSources(json);
    return mediaSources;
  }

  private getAudioSources(json: Any): Array<MediaSource> {
    if (!(json instanceof Array)) {
      throw new Error("List expected: " + json);
    }
    let audioSources: Array<Any> = json;
    let mediaSources: Array<MediaSource> = new Array<MediaSource>();
    for (let i = 0; i < audioSources.length; i++) {
      mediaSources.push(this.getAudioSource(audioSources[i]));
    }
    return mediaSources;
  }

  private mapGet(o: Any, key: String): Any {
    if (o instanceof Map) {
      return o.get(key);
    } else {
      return null;
    }
  }

  private getAudioSource(json: Any): MediaSource {
    let map: Map<Any, Any> = json;
    let id: string = this.mapGet(map, "id") as string;
    let mediaSource: MediaSource | undefined;
    if (this.mediaSources) {
      mediaSource = this.mediaSources.get(id);
    }
    if (mediaSource == undefined) {
      mediaSource = this.decodeAudioSource(map);
      if (mediaSource) {
        this.mediaSources.set(id, mediaSource);
      }
    }
    return mediaSource;
  }

  private async load(mediaSource: MediaSource, initialPosition: number, initialIndex: number, result: MethodResult) {
    this.initialPos = initialPosition;
    this.initialIndex = initialIndex;
    this.currentIndex = initialIndex != null ? initialIndex : 0;

    switch (this.processingState) {
      case ProcessingState.none:
        break;
      case ProcessingState.loading:
        this.abortExistingConnection();
        this.player?.stop();
        break;
      default:
        this.player?.stop();
        break;
    }
    this.prepareResult = result;
    this.onUpdatePosition();
    this.processingState = ProcessingState.loading;
    await this.enqueuePlaybackEvent();
    this.mediaSource = mediaSource;
    if (this.player) {
      if (this.initialIndex || this.initialIndex == 0) {
        this.player.isPlaying = true;
        await this.player.load(mediaSource, this.initialIndex,this.initialPos);
      } else {
        await this.player.load(mediaSource, this.currentIndex);
      }
    }
  }

  abortExistingConnection() {
    this.sendError("abort", "Connection aborted");
  }

  private sendError(errorCode: string, errorMsg: string, details?: Any) {
    if (this.prepareResult != null) {
      this.prepareResult.error(errorCode, errorMsg, details);
      this.prepareResult = null;
    }

    this.eventChannel?.error(errorCode, errorMsg, details);
    if (this.player){
      this.player.state = AudioPlayerState.ERROR;
      // 通知状态变化
      this.player.mediaAvPlayerStateChangeListener?.onPlaybackStateChanged(PlaybackState.IDLE);
    }

  }

  onUpdatePosition() {
    this.updatePosition = this.getCurrentPosition();
    this.updateTime = systemDateTime.getTime();
  }

  onUpdateBufferedPosition(bufferedPosition: number): void {
    this.bufferedPosition = bufferedPosition;
  }

  getCurrentPosition(): number {
    if (this.initialPos != AudioPlayer.TIME_UNSET) {
      return this.initialPos ? this.initialPos : 0;
    } else if (this.processingState == ProcessingState.none || this.processingState == ProcessingState.loading) {
      let pos: number = this.player?.getCurrentTime() ? this.player?.getCurrentTime() : 0;
      return pos < 0 ? 0 : pos;
    } else if (this.seekPos != null && this.seekPos != AudioPlayer.TIME_UNSET) {
      return this.seekPos;
    } else {
      return this.player?.getCurrentTime() ? this.player?.getCurrentTime() : 0;
    }
  }

  completeInitial() {
    this.initialIndex = null;
    this.initialPos = AudioPlayer.TIME_UNSET;
  }

  async enqueuePlaybackEvent() {
    if (this.player?.songList.length == 0) {
      await this.player.avPlayer?.reset();
      this.processingState = ProcessingState.completed;
    }
    let event: Map<String, Object> = new Map<String, Object>();
    this.pendingPlaybackEvent = this.createPlaybackEvent();
  }

  // Creates an event based on the current state.
  private createPlaybackEvent() {
    this.onUpdatePosition();
    let event: Map<String, Object> = new Map<String, Object>();
    let duration: ESObject = this.getDuration() == AudioPlayer.TIME_UNSET ? null : (1000 * this.getDuration());
    event.set("processingState", this.processingState.valueOf());
    event.set("updatePosition",
      this.updatePosition > 0 ? this.updatePosition * 1000 != duration ? 1000 * this.updatePosition : 0 : 0);
    event.set("updateTime", this.updateTime);
    event.set("bufferedPosition", 1000 * Math.max(this.updatePosition, this.bufferedPosition));
    event.set("duration", duration);
    event.set("currentIndex", this.currentIndex);
    event.set("audioSessionId", this.audioSessionId!);
    return event;
  }

  private getDuration(): number {
    if (this.processingState == ProcessingState.none || this.processingState == ProcessingState.loading ||
      this.player == null) {
      return AudioPlayer.TIME_UNSET;
    } else {
      return this.player.getDuration() ? this.player.getDuration() : 0;
    }
  }

  // Broadcast the pending playback event if it was set.
  private broadcastPendingPlaybackEvent() {
    if (this.pendingPlaybackEvent != null) {
      this.eventChannel?.success(this.pendingPlaybackEvent);
      this.pendingPlaybackEvent = null;
    }
  }
}
