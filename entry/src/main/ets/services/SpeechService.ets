import { speechRecognizer } from '@kit.CoreSpeechKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'SpeechService';
const DOMAIN: number = 0x0001;

interface SpeechServiceCallbacks {
  onResult: (text: string, isFinal: boolean) => void;
  onError: (errorCode: number, errorMessage: string) => void;
  onStart: () => void;
  onComplete: () => void;
  onReady: () => void;
}

export class SpeechService {
  private static instance: SpeechService = new SpeechService();
  private engine: speechRecognizer.SpeechRecognitionEngine | null = null;
  private sessionId: string = '';
  private callbacks: SpeechServiceCallbacks | null = null;
  private listening: boolean = false;
  private initialized: boolean = false;

  static getInstance(): SpeechService {
    return SpeechService.instance;
  }

  init(callbacks: SpeechServiceCallbacks): void {
    this.callbacks = callbacks;
    if (this.initialized && this.engine !== null) {
      // 重新绑定 listener，否则新页面的回调收不到识别结果
      this.engine.setListener(this.buildListener());
      if (this.callbacks !== null) {
        this.callbacks.onReady();
      }
      return;
    }
    const extraParam: Record<string, Object> = { 'locate': 'CN', 'recognizerMode': 'short' };
    const initParams: speechRecognizer.CreateEngineParams = {
      language: 'zh-CN',
      online: 1,
      extraParams: extraParam
    };
    speechRecognizer.createEngine(initParams, (err: BusinessError, speechEngine: speechRecognizer.SpeechRecognitionEngine) => {
      if (err) {
        hilog.error(DOMAIN, TAG, 'createEngine failed: ' + err.code.toString() + ' ' + err.message);
        if (this.callbacks !== null) {
          this.callbacks.onError(err.code, err.message);
        }
        return;
      }
      this.engine = speechEngine;
      this.initialized = true;
      hilog.info(DOMAIN, TAG, 'engine created successfully');
      if (this.engine !== null) {
        this.engine.setListener(this.buildListener());
      }
      if (this.callbacks !== null) {
        this.callbacks.onReady();
      }
    });
  }

  startListening(): boolean {
    if (this.engine === null) {
      hilog.error(DOMAIN, TAG, 'engine not initialized');
      return false;
    }
    if (this.listening) {
      hilog.warn(DOMAIN, TAG, 'already listening');
      return false;
    }
    this.sessionId = 'asr-' + Date.now().toString();
    const audioParam: speechRecognizer.AudioInfo = {
      audioType: 'pcm',
      sampleRate: 16000,
      soundChannel: 1,
      sampleBit: 16
    };
    const extraParam: Record<string, Object> = {
      'recognitionMode': 0,
      'vadBegin': 2000,
      'vadEnd': 3000,
      'maxAudioDuration': 20000
    };
    const startParams: speechRecognizer.StartParams = {
      sessionId: this.sessionId,
      audioInfo: audioParam,
      extraParams: extraParam
    };
    try {
      if (this.engine !== null) {
        this.engine.startListening(startParams);
      }
      return true;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'startListening exception');
      return false;
    }
  }

  stopListening(): void {
    if (this.engine === null || !this.listening) {
      return;
    }
    try {
      if (this.engine !== null) {
        this.engine.finish(this.sessionId);
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'finish exception');
    }
  }

  cancelListening(): void {
    if (this.engine === null || !this.listening) {
      return;
    }
    try {
      if (this.engine !== null) {
        this.engine.cancel(this.sessionId);
      }
      this.listening = false;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'cancel exception');
    }
  }

  isListening(): boolean {
    return this.listening;
  }

  isReady(): boolean {
    return this.initialized && this.engine !== null;
  }

  private buildListener(): speechRecognizer.RecognitionListener {
    return {
      onStart: (sid: string, eventMessage: string) => {
        hilog.info(DOMAIN, TAG, 'onStart sid=' + sid);
        this.listening = true;
        if (this.callbacks !== null) {
          this.callbacks.onStart();
        }
      },
      onEvent: (sid: string, eventCode: number, eventMessage: string) => {
        hilog.info(DOMAIN, TAG, 'onEvent code=' + eventCode.toString());
      },
      onResult: (sid: string, result: speechRecognizer.SpeechRecognitionResult) => {
        hilog.info(DOMAIN, TAG, 'onResult isFinal=' + result.isFinal.toString() + ' result=' + result.result);
        if (this.callbacks !== null) {
          this.callbacks.onResult(result.result, result.isFinal);
        }
      },
      onComplete: (sid: string, eventMessage: string) => {
        hilog.info(DOMAIN, TAG, 'onComplete sid=' + sid);
        this.listening = false;
        if (this.callbacks !== null) {
          this.callbacks.onComplete();
        }
      },
      onError: (sid: string, errorCode: number, errorMessage: string) => {
        hilog.error(DOMAIN, TAG, 'onError code=' + errorCode.toString() + ' msg=' + errorMessage);
        this.listening = false;
        if (this.callbacks !== null) {
          this.callbacks.onError(errorCode, errorMessage);
        }
      }
    };
  }

  shutdown(): void {
    if (this.engine !== null) {
      try {
        this.engine.shutdown();
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'shutdown exception');
      }
      this.engine = null;
      this.initialized = false;
      this.listening = false;
    }
  }
}
