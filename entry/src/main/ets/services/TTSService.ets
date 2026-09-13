import { textToSpeech } from '@kit.CoreSpeechKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'TTSService';
const DOMAIN: number = 0x0002;

const POLYPHONE_MAP: Record<string, string> = {
  '着': 'zhuo2',
  '教': 'jiao4',
  '重': 'zhong4',
  '行': 'hang2',
  '便': 'bian4',
  '还': 'hai2',
  '差': 'cha4',
  '长': 'chang2',
  '量': 'liang4',
  '调': 'diao4',
  '种': 'zhong3',
  '发': 'fa1',
  '乐': 'le4',
  '弹': 'tan2',
  '似': 'shi4',
  '散': 'san4',
  '曾': 'ceng2',
  '创': 'chuang4',
  '舍': 'she3',
  '藏': 'cang2',
  '传': 'chuan2',
  '参': 'can1',
  '度': 'du4',
  '处': 'chu4',
  '论': 'lun4',
  '为': 'wei2',
  '得': 'de2',
  '地': 'di4',
  '的': 'de5',
  '了': 'le5',
  '几': 'ji3',
  '相': 'xiang1',
  '应': 'ying1',
  '分': 'fen1',
  '率': 'lv4',
  '占': 'zhan4',
  '冠': 'guan4',
  '强': 'qiang2',
  '朝': 'chao2',
  '落': 'luo4',
  '供': 'gong1',
  '铺': 'pu4',
  '扇': 'shan4',
  '乘': 'cheng2',
  '降': 'jiang4',
  '中': 'zhong1',
  '和': 'he2',
  '只': 'zhi3'
};

export class TTSService {
  private static instance: TTSService = new TTSService();
  private engine: textToSpeech.TextToSpeechEngine | null = null;
  private initialized: boolean = false;
  private initializing: boolean = false;
  private queue: string[] = [];
  private speaking: boolean = false;
  private currentRequestId: string = '';
  private requestCounter: number = 0;
  private enabled: boolean = true;

  setEnabled(on: boolean): void {
    this.enabled = on;
    if (!on) {
      this.stop();
    }
  }

  isEnabled(): boolean {
    return this.enabled;
  }

  static getInstance(): TTSService {
    return TTSService.instance;
  }

  private buildListener(): textToSpeech.SpeakListener {
    return {
      onStart: (requestId: string, response: textToSpeech.StartResponse) => {
        hilog.info(DOMAIN, TAG, 'onStart requestId=' + requestId);
      },
      onComplete: (requestId: string, response: textToSpeech.CompleteResponse) => {
        hilog.info(DOMAIN, TAG, 'onComplete requestId=' + requestId);
        this.speaking = false;
        this.currentRequestId = '';
        this.processQueue();
      },
      onStop: (requestId: string, response: textToSpeech.StopResponse) => {
        hilog.info(DOMAIN, TAG, 'onStop requestId=' + requestId);
        this.speaking = false;
        this.currentRequestId = '';
      },
      onData: (requestId: string, audio: ArrayBuffer, response: textToSpeech.SynthesisResponse) => {
      },
      onError: (requestId: string, errorCode: number, errorMessage: string) => {
        hilog.error(DOMAIN, TAG, 'onError requestId=' + requestId + ' code=' + errorCode.toString() + ' msg=' + errorMessage);
        this.speaking = false;
        this.currentRequestId = '';
        this.processQueue();
      }
    };
  }

  private static correctPolyphones(text: string): string {
    if (text.indexOf('[=') >= 0) {
      return text;
    }
    const chars: string[] = text.split('');
    const corrected: string[] = [];
    for (let i = 0; i < chars.length; i++) {
      const ch: string = chars[i];
      if (i > 0 && chars[i - 1] === '[' && corrected.length > 0 && corrected[corrected.length - 1] === '[') {
        corrected.push(ch);
        continue;
      }
      const pinyin: string | undefined = POLYPHONE_MAP[ch];
      if (pinyin && i + 1 < chars.length) {
        const next: string = chars[i + 1];
        const isCommonPair: Record<string, string> = {
          '着': '手|落|重|急|眼|想|装|穿|找|迷|执|附',
          '教': '育|授|程|室|师|材|训|导|会|案',
          '重': '要|量|新|视|复|点|工|用|大|庆|做',
          '行': '业|情|货|家|程|列|长|政|银|出|发|人',
          '便': '宜|利|民|餐|饭|纸|签|条',
          '还': '是|有|要|能|会|好|在|给|没|去',
          '差': '价|别|距|异|错|评',
          '长': '期|久|城|大|度|远|篇|寿|短|班|江',
          '量': '数|质|产|力|能|杯|饭',
          '调': '查|研|价|整|换|节|配|控|用',
          '种': '类|子|型|群|品|菜|树',
          '发': '现|展|生|送|出|生|布|货|明|售|放',
          '弹': '出|出|性|簧|琴|力',
          '创': '建|业|新|意|办|设',
          '参': '加|与|考|数|谋|看',
          '度': '过|假|高|温|年|制|量',
          '处': '理|室|方|所|境|事',
          '论': '坛|文|理|题|讨|争',
          '占': '比|领|有|地|用',
          '冠': '军|名|绝|病',
          '强': '大|调|化|烈|度',
          '降': '价|低|落|温',
          '供': '应|货|给|需',
          '铺': '子|面|底|张|垫',
          '扇': '子|门|风'
        };
        const pairStr: string | undefined = isCommonPair[ch];
        if (pairStr && pairStr.indexOf(next) >= 0) {
          corrected.push(ch + '[=' + pinyin + ']');
          continue;
        }
      }
      corrected.push(ch);
    }
    return corrected.join('');
  }

  init(): void {
    if (this.initialized || this.initializing) {
      return;
    }
    this.initializing = true;
    const extraParam: Record<string, Object> = {
      'style': 'interaction-broadcast',
      'locate': 'CN',
      'name': 'HelpShopTTS'
    };
    const initParams: textToSpeech.CreateEngineParams = {
      language: 'zh-CN',
      person: 0,
      online: 1,
      extraParams: extraParam
    };
    textToSpeech.createEngine(initParams, (err: BusinessError, ttsEngine: textToSpeech.TextToSpeechEngine) => {
      this.initializing = false;
      if (err) {
        hilog.error(DOMAIN, TAG, 'createEngine failed: ' + err.code.toString() + ' ' + err.message);
        return;
      }
      this.engine = ttsEngine;
      this.initialized = true;
      this.engine.setListener(this.buildListener());
      hilog.info(DOMAIN, TAG, 'TTS engine created successfully');
      this.processQueue();
    });
  }

  speak(text: string): void {
    if (!this.enabled) {
      return;
    }
    if (text.trim().length === 0) {
      return;
    }
    const correctedText: string = TTSService.correctPolyphones(text);
    if (!this.initialized && !this.initializing) {
      this.init();
    }
    this.queue.push(correctedText);
    hilog.info(DOMAIN, TAG, 'speak queued: %{public}s', correctedText);
    this.processQueue();
  }

  private processQueue(): void {
    if (this.speaking || this.queue.length === 0) {
      return;
    }
    if (!this.engine || !this.initialized) {
      return;
    }
    this.speaking = true;
    const text: string = this.queue.shift()!;
    this.requestCounter += 1;
    this.currentRequestId = 'tts-' + Date.now().toString() + '-' + this.requestCounter.toString();
    const speakExtraParam: Record<string, Object> = {
      'queueMode': 0,
      'speed': 1,
      'volume': 2,
      'pitch': 1,
      'languageContext': 'zh-CN',
      'audioType': 'pcm',
      'soundChannel': 3,
      'playType': 1
    };
    const speakParams: textToSpeech.SpeakParams = {
      requestId: this.currentRequestId,
      extraParams: speakExtraParam
    };
    try {
      this.engine.speak(text, speakParams);
      hilog.info(DOMAIN, TAG, 'TTS speaking: %{public}s', text);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'speak exception');
      this.speaking = false;
      this.currentRequestId = '';
      this.processQueue();
    }
  }

  speakImmediate(text: string): void {
    if (!this.enabled) {
      return;
    }
    this.queue = [];
    if (this.speaking && this.engine) {
      try {
        this.engine.stop();
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'stop exception in speakImmediate');
      }
      this.speaking = false;
      this.currentRequestId = '';
    }
    const correctedText: string = TTSService.correctPolyphones(text);
    if (correctedText.trim().length === 0) {
      return;
    }
    if (!this.initialized && !this.initializing) {
      this.init();
    }
    this.queue.push(correctedText);
    hilog.info(DOMAIN, TAG, 'speakImmediate queued: %{public}s', correctedText);
    this.processQueue();
  }

  stop(): void {
    this.queue = [];
    if (this.speaking && this.engine) {
      try {
        this.engine.stop();
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'stop exception');
      }
    }
    this.speaking = false;
    this.currentRequestId = '';
  }

  shutdown(): void {
    this.stop();
    if (this.engine) {
      try {
        this.engine.shutdown();
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'shutdown exception');
      }
      this.engine = null;
    }
    this.initialized = false;
    this.initializing = false;
  }

  isReady(): boolean {
    return this.initialized && this.engine !== null;
  }
}
