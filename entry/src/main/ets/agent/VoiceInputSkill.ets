import {
  AgentIntent,
  ConversationContext,
  emptyAgentIntent,
  emptySkillResultData,
  IntentType,
  Skill,
  SkillResult,
  VoiceInputContext
} from './AgentModels';

export class VoiceNormalizer {
  private static fillerPatterns: string[][] = [
    ['嗯', ''], ['啊', ''], ['呃', ''], ['那个', ''],
    ['就是', ''], ['然后', ''], ['对对对', '对'],
    ['帮我帮', '帮我'], ['我想我想', '我想'],
    ['一下下', '一下'], ['看看看', '看看']
  ];

  private static spokenToWritten: string[][] = [
    ['两双', '2双'], ['三件', '3件'], ['四罐', '4罐'],
    ['两百', '200'], ['一百', '100'], ['五十', '50'],
    ['三十', '30'], ['二十', '20'], ['十几', '10+']
  ];

  static normalize(text: string, voiceContext: VoiceInputContext): string {
    let normalized: string = text;
    normalized = VoiceNormalizer.deduplicatePhrases(normalized);
    for (let i = 0; i < VoiceNormalizer.fillerPatterns.length; i += 1) {
      const pattern: string = VoiceNormalizer.fillerPatterns[i][0];
      const replacement: string = VoiceNormalizer.fillerPatterns[i][1];
      while (normalized.indexOf(pattern) >= 0) {
        normalized = normalized.replace(pattern, replacement);
      }
    }
    for (let i = 0; i < VoiceNormalizer.spokenToWritten.length; i += 1) {
      const spoken: string = VoiceNormalizer.spokenToWritten[i][0];
      const written: string = VoiceNormalizer.spokenToWritten[i][1];
      if (normalized.indexOf(spoken) >= 0) {
        normalized = normalized.replace(spoken, written);
      }
    }
    normalized = normalized.replace(/\s+/g, ' ').trim();
    if (normalized.length === 0 && text.length > 0) {
      normalized = text.trim();
    }
    return normalized;
  }

  static deduplicatePhrases(text: string): string {
    const segments: string[] = text.split(/[，。、？！,.!? ]+/);
    const seen: string[] = [];
    const result: string[] = [];
    for (let i = 0; i < segments.length; i += 1) {
      const seg: string = segments[i].trim();
      if (seg.length === 0) {
        continue;
      }
      let isDup: boolean = false;
      for (let j = 0; j < seen.length; j += 1) {
        if (seen[j] === seg || seg.indexOf(seen[j]) === 0 || seen[j].indexOf(seg) === 0) {
          isDup = true;
          break;
        }
      }
      if (!isDup) {
        seen.push(seg);
        result.push(seg);
      }
    }
    if (result.length === 0) {
      return text;
    }
    return result.join('');
  }

  static isVoiceLikeCommand(text: string): boolean {
    const voiceIndicators: string[] = [
      '帮我', '给我', '我想', '要一个', '来一个',
      '买一个', '来点', '弄个', '整一个',
      '就那个', '这个这个', '那个那个'
    ];
    for (let i = 0; i < voiceIndicators.length; i += 1) {
      if (text.indexOf(voiceIndicators[i]) >= 0) {
        return true;
      }
    }
    return false;
  }

  static boostConfidence(intent: AgentIntent): AgentIntent {
    if (!intent.voiceContext.isVoiceInput) {
      return intent;
    }
    const boosted: AgentIntent = emptyAgentIntent();
    boosted.type = intent.type;
    boosted.product = intent.product;
    boosted.category = intent.category;
    boosted.attributes = intent.attributes;
    boosted.quantity = intent.quantity;
    boosted.rawText = intent.rawText;
    boosted.needsSupplement = intent.needsSupplement;
    boosted.supplementQuestions = intent.supplementQuestions.slice();
    boosted.voiceContext = intent.voiceContext;
    boosted.confidence = Math.min(1.0, intent.confidence + 0.1);
    if (intent.type === IntentType.Unknown && VoiceNormalizer.isVoiceLikeCommand(intent.rawText)) {
      boosted.type = IntentType.Compare;
      boosted.confidence = Math.max(boosted.confidence, 0.5);
      boosted.needsSupplement = true;
      if (boosted.supplementQuestions.length === 0) {
        boosted.supplementQuestions = ['您想买什么商品？请再说一次商品名称。'];
      }
    }
    return boosted;
  }
}

export class VoiceInputSkill implements Skill {
  name: string = 'voice_input';
  description: string = '语音输入处理：规范化语音识别文本，增强意图识别';

  canHandle(intent: AgentIntent): boolean {
    return intent.type === IntentType.VoiceCommand;
  }

  execute(intent: AgentIntent, context: ConversationContext): SkillResult {
    const data = emptySkillResultData();
    const normalized: string = VoiceNormalizer.normalize(
      intent.rawText, intent.voiceContext
    );
    const boosted: AgentIntent = VoiceNormalizer.boostConfidence(intent);
    if (normalized.length > 0 && normalized !== intent.rawText) {
      boosted.rawText = normalized;
    }
    const payload: Record<string, Object> = {};
    payload['normalizedText'] = normalized;
    payload['originalText'] = intent.rawText;
    data.payload = payload;
    return {
      success: true,
      data: data,
      message: normalized.length > 0 ? normalized : intent.rawText,
      fallbackUsed: false
    };
  }
}
