import {
  AgentIntent,
  AgentSessionStatus,
  ConversationContext,
  emptyAgentIntent,
  emptyStructuredAttributes,
  IntentType,
  StructuredAttributes,
  VoiceInputContext,
  cloneAgentIntent
} from './AgentModels';
import { VoiceNormalizer } from './VoiceInputSkill';
import { MOCK_PRODUCTS } from '../mock/MockData';
import { ProductCandidate } from '../models/ShoppingModels';
import { AgentSessionManager } from './AgentSessionManager';

interface DictionaryEntry {
  keyword: string;
  standardValue: string;
}

interface SelectPattern {
  pattern: string;
  index: number;
}

export class IntentEngine {
  private static productKeywords: string[] = [];

  private static ensureProductKeywords(): void {
    if (IntentEngine.productKeywords.length > 0) {
      return;
    }
    const keywords: string[] = [];
    for (let i = 0; i < MOCK_PRODUCTS.length; i += 1) {
      const product: ProductCandidate = MOCK_PRODUCTS[i];
      // 提取商品名中的关键词片段
      const nameParts: string[] = product.name.split(/[\s,，、]+/);
      for (let j = 0; j < nameParts.length; j += 1) {
        const part: string = nameParts[j];
        if (part.length >= 2 && keywords.indexOf(part) < 0) {
          keywords.push(part);
        }
      }
      // 提取标签
      for (let j = 0; j < product.tags.length; j += 1) {
        const tag: string = product.tags[j];
        if (tag.length >= 2 && keywords.indexOf(tag) < 0) {
          keywords.push(tag);
        }
      }
    }
    IntentEngine.productKeywords = keywords;
  }

  private static getProductKeywords(): string[] {
    IntentEngine.ensureProductKeywords();
    return IntentEngine.productKeywords;
  }

  private static categoryMap: string[][] = [
    ['鞋', '跑鞋', '健步鞋', '散步鞋', '鞋服出行'],
    ['血压计', '血压仪', '健康监测'],
    ['奶粉', '营养食品'],
    ['手机', '老人机', '手机数码'],
    ['台灯', '护眼灯', '家居照明'],
    ['大米', '主食粮油'],
    ['药盒', '分药盒', '健康照护'],
    ['推车', '买菜车', '生活辅助'],
    ['暖脚器', '保暖用品'],
    ['毛毯', '家纺保暖'],
    ['耳机', '手机数码']
  ];

  private static colorEntries: DictionaryEntry[] = [
    { keyword: '黑色', standardValue: '黑色' },
    { keyword: '白色', standardValue: '白色' },
    { keyword: '红色', standardValue: '红色' },
    { keyword: '蓝色', standardValue: '蓝色' },
    { keyword: '灰色', standardValue: '灰色' },
    { keyword: '棕色', standardValue: '棕色' },
    { keyword: '深色', standardValue: '深色' },
    { keyword: '浅色', standardValue: '浅色' }
  ];

  private static sizeEntries: DictionaryEntry[] = [
    { keyword: '大号', standardValue: '大号' },
    { keyword: '小号', standardValue: '小号' },
    { keyword: '中号', standardValue: '中号' },
    { keyword: '加大', standardValue: '加大' },
    { keyword: '大尺寸', standardValue: '大号' },
    { keyword: '小尺寸', standardValue: '小号' },
    { keyword: '宽脚', standardValue: '宽楦' }
  ];

  private static materialEntries: DictionaryEntry[] = [
    { keyword: '真皮', standardValue: '真皮' },
    { keyword: '布面', standardValue: '布面' },
    { keyword: '透气', standardValue: '透气' },
    { keyword: '软底', standardValue: '软底' },
    { keyword: '橡胶', standardValue: '橡胶' }
  ];

  private static featureEntries: DictionaryEntry[] = [
    { keyword: '不累脚', standardValue: '不累脚' },
    { keyword: '防滑', standardValue: '防滑' },
    { keyword: '无糖', standardValue: '无糖' },
    { keyword: '高钙', standardValue: '高钙' },
    { keyword: '大字体', standardValue: '大字体' },
    { keyword: '大按键', standardValue: '大按键' },
    { keyword: '护眼', standardValue: '护眼' },
    { keyword: '便宜', standardValue: '便宜' },
    { keyword: '安全', standardValue: '安全' },
    { keyword: '保暖', standardValue: '保暖' },
    { keyword: '长续航', standardValue: '长续航' },
    { keyword: '语音', standardValue: '语音' },
    { keyword: '智能', standardValue: '智能' },
    { keyword: '减震', standardValue: '减震' },
    { keyword: '足弓', standardValue: '足弓支撑' },
    { keyword: '稳定', standardValue: '稳定' },
    { keyword: '折叠', standardValue: '折叠' },
    { keyword: '恒温', standardValue: '恒温' },
    { keyword: '加厚', standardValue: '加厚' }
  ];

  private static compareTriggers: string[] = [
    '买', '购', '要', '想买', '帮我买', '来一个', '来一件',
    '需要', '想要', '给我', '弄个', '整一个'
  ];

  private static searchTriggers: string[] = [
    '搜', '找', '看看', '有什么', '推荐', '哪些',
    '帮我找', '搜索', '查询', '查查'
  ];

  private static orderTriggers: string[] = [
    '下单', '确认', '购买这个', '买这个', '就这个',
    '要这个', '订购'
  ];

  private static payTriggers: string[] = [
    '付款', '支付', '结账', '买单', '付钱',
    '华为支付', '人脸支付', '指纹支付', '密码支付'
  ];

  private static adminTriggers: string[] = [
    '所有用户', '用户列表', '所有订单', '平台统计', '系统数据',
    '审计日志', '异常订单', '后台管理'
  ];

  private static csTriggers: string[] = [
    '工单', '退款', '投诉', '物流问题', '支付失败',
    '帮老人', '咨询'
  ];

  private static orderQueryTriggers: string[] = [
    '我的订单', '订单查询', '买了什么', '物流', '配送',
    '订单列表', '查订单', '看订单', '订单状态', '已买'
  ];

  private static addressManageTriggers: string[] = [
    '我的地址', '添加地址', '修改地址', '删除地址', '默认地址',
    '收货地址', '地址列表', '地址管理', '看地址', '地址'
  ];

  private static reminderManageTriggers: string[] = [
    '提醒', '提醒我', '我的提醒', '标记已读', '全部已读',
    '提醒列表', '看提醒', '消息提醒', '通知'
  ];

  private static familyBindTriggers: string[] = [
    '绑定老人', '绑定家人', '绑定码', '我的绑定', '绑定',
    '家庭绑定', '查看绑定', '已绑定'
  ];

  static parse(text: string, context?: ConversationContext, voiceContext?: VoiceInputContext, role?: string): AgentIntent {
    let processedText: string = text.trim();
    const isVoice: boolean = voiceContext !== undefined && voiceContext.isVoiceInput;
    if (isVoice && voiceContext !== undefined) {
      processedText = VoiceNormalizer.normalize(processedText, voiceContext);
    }
    if (processedText.length === 0) {
      const empty: AgentIntent = emptyAgentIntent();
      empty.rawText = processedText;
      empty.type = IntentType.Unknown;
      empty.confidence = 0;
      empty.voiceContext = voiceContext ? voiceContext : empty.voiceContext;
      return empty;
    }

    const intent: AgentIntent = emptyAgentIntent();
    intent.rawText = processedText;
    intent.type = IntentEngine.classifyIntentType(processedText, context, role);
    intent.product = IntentEngine.extractProduct(processedText);
    intent.category = IntentEngine.extractCategory(intent.product);
    intent.attributes = IntentEngine.extractAttributes(processedText);
    intent.quantity = IntentEngine.extractQuantity(processedText);

    if (isVoice && intent.product.length === 0 && intent.type !== IntentType.Unknown) {
      intent.product = IntentEngine.extractProductFromTriggers(processedText);
      if (intent.product.length > 0) {
        intent.category = IntentEngine.extractCategory(intent.product);
      }
    }

    intent.confidence = IntentEngine.calculateConfidence(intent);
    if (isVoice) {
      intent.confidence = Math.min(1.0, intent.confidence + 0.15);
    }
    intent.needsSupplement = intent.confidence < 0.6;
    intent.supplementQuestions = IntentEngine.generateSupplementQuestions(intent);
    intent.voiceContext = voiceContext ? voiceContext : intent.voiceContext;

    if (intent.type === IntentType.ProductSelect) {
      intent.selectedIndex = IntentEngine.extractSelectIndex(processedText);
      intent.confidence = 1.0;
      intent.needsSupplement = false;
      if (context && context.pendingIntent.product.length > 0) {
        intent.product = context.pendingIntent.product;
        intent.category = context.pendingIntent.category;
      }
    }

    if (isVoice) {
      const boosted: AgentIntent = VoiceNormalizer.boostConfidence(intent);
      boosted.voiceContext = voiceContext ? voiceContext : boosted.voiceContext;
      if (boosted.type === IntentType.Unknown && VoiceNormalizer.isVoiceLikeCommand(processedText)) {
        boosted.type = IntentType.VoiceCommand;
        boosted.confidence = Math.max(boosted.confidence, 0.4);
        boosted.needsSupplement = true;
        if (boosted.supplementQuestions.length === 0) {
          boosted.supplementQuestions = ['您想买什么商品？请再说一次商品名称。'];
        }
      }
      return boosted;
    }

    if (intent.type === IntentType.Supplement && context && context.pendingIntent.product.length > 0) {
      const merged: AgentIntent = IntentEngine.mergeSupplement(context.pendingIntent, intent);
      merged.type = IntentType.Compare;
      merged.confidence = IntentEngine.calculateConfidence(merged);
      merged.needsSupplement = merged.confidence < 0.6;
      merged.supplementQuestions = IntentEngine.generateSupplementQuestions(merged);
      return merged;
    }

    return intent;
  }

  static extractSelectIndex(text: string): number {
    const patterns: SelectPattern[] = [
      { pattern: '买第三个', index: 3 }, { pattern: '买第3', index: 3 },
      { pattern: '选第三个', index: 3 }, { pattern: '选第3', index: 3 },
      { pattern: '第三个', index: 3 }, { pattern: '第3', index: 3 },
      { pattern: '买第二个', index: 2 }, { pattern: '买第2', index: 2 },
      { pattern: '选第二个', index: 2 }, { pattern: '选第2', index: 2 },
      { pattern: '第二个', index: 2 }, { pattern: '第2', index: 2 },
      { pattern: '买第一个', index: 1 }, { pattern: '买第1', index: 1 },
      { pattern: '选第一个', index: 1 }, { pattern: '选第1', index: 1 },
      { pattern: '第一个', index: 1 }, { pattern: '第1', index: 1 },
      { pattern: '买3', index: 3 }, { pattern: '选3', index: 3 },
      { pattern: '买2', index: 2 }, { pattern: '选2', index: 2 },
      { pattern: '买1', index: 1 }, { pattern: '选1', index: 1 }
    ];
    for (let i = 0; i < patterns.length; i += 1) {
      if (text.indexOf(patterns[i].pattern) >= 0) {
        return patterns[i].index;
      }
    }
    return -1;
  }

  static isProductSelectIntent(text: string, context?: ConversationContext): boolean {
    const idx: number = IntentEngine.extractSelectIndex(text);
    if (idx > 0) {
      if (context && context.pendingIntent && context.pendingIntent.type === IntentType.Compare) {
        return true;
      }
      const session = AgentSessionManager.getSession();
      if (session && session.status !== AgentSessionStatus.Idle) {
        return true;
      }
    }
    return false;
  }

  private static classifyIntentType(text: string, context?: ConversationContext, role?: string): IntentType {
    if (IntentEngine.isProductSelectIntent(text, context)) {
      return IntentType.ProductSelect;
    }
    if (role === 'admin' || role === 'elderly') {
      for (let i = 0; i < IntentEngine.adminTriggers.length; i += 1) {
        if (text.indexOf(IntentEngine.adminTriggers[i]) >= 0) {
          return IntentType.AdminQuery;
        }
      }
    }
    if (role === 'customer_service' || role === 'cs') {
      for (let i = 0; i < IntentEngine.csTriggers.length; i += 1) {
        if (text.indexOf(IntentEngine.csTriggers[i]) >= 0) {
          return IntentType.CSAsk;
        }
      }
    }
    for (let i = 0; i < IntentEngine.orderQueryTriggers.length; i += 1) {
      if (text.indexOf(IntentEngine.orderQueryTriggers[i]) >= 0) {
        return IntentType.OrderQuery;
      }
    }
    for (let i = 0; i < IntentEngine.addressManageTriggers.length; i += 1) {
      if (text.indexOf(IntentEngine.addressManageTriggers[i]) >= 0) {
        return IntentType.AddressManage;
      }
    }
    for (let i = 0; i < IntentEngine.reminderManageTriggers.length; i += 1) {
      if (text.indexOf(IntentEngine.reminderManageTriggers[i]) >= 0) {
        return IntentType.ReminderManage;
      }
    }
    for (let i = 0; i < IntentEngine.familyBindTriggers.length; i += 1) {
      if (text.indexOf(IntentEngine.familyBindTriggers[i]) >= 0) {
        return IntentType.FamilyBind;
      }
    }
    for (let i = 0; i < IntentEngine.payTriggers.length; i += 1) {
      if (text.indexOf(IntentEngine.payTriggers[i]) >= 0) {
        return IntentType.Pay;
      }
    }
    for (let i = 0; i < IntentEngine.orderTriggers.length; i += 1) {
      if (text.indexOf(IntentEngine.orderTriggers[i]) >= 0) {
        return IntentType.OrderConfirm;
      }
    }
    for (let i = 0; i < IntentEngine.compareTriggers.length; i += 1) {
      if (text.indexOf(IntentEngine.compareTriggers[i]) >= 0) {
        return IntentType.Compare;
      }
    }
    for (let i = 0; i < IntentEngine.searchTriggers.length; i += 1) {
      if (text.indexOf(IntentEngine.searchTriggers[i]) >= 0) {
        return IntentType.Search;
      }
    }
    if (context && context.pendingIntent.product.length > 0) {
      const hasAttribute: boolean = IntentEngine.hasOnlyAttributeWords(text);
      if (hasAttribute) {
        return IntentType.Supplement;
      }
    }
    if (IntentEngine.extractProduct(text).length > 0) {
      return IntentType.Compare;
    }
    return IntentType.Unknown;
  }

  private static extractProduct(text: string): string {
    for (let i = 0; i < IntentEngine.getProductKeywords().length; i += 1) {
      if (text.indexOf(IntentEngine.getProductKeywords()[i]) >= 0) {
        return IntentEngine.getProductKeywords()[i];
      }
    }
    for (let i = 0; i < MOCK_PRODUCTS.length; i += 1) {
      const product: ProductCandidate = MOCK_PRODUCTS[i];
      for (let j = 0; j < product.tags.length; j += 1) {
        const tag: string = product.tags[j];
        if (tag.length >= 2 && text.indexOf(tag) >= 0) {
          return tag;
        }
      }
    }
    for (let i = 0; i < IntentEngine.categoryMap.length; i += 1) {
      const group: string[] = IntentEngine.categoryMap[i];
      for (let j = 0; j < group.length - 1; j += 1) {
        if (text.indexOf(group[j]) >= 0) {
          return group[j];
        }
      }
    }
    return '';
  }

  private static extractProductFromTriggers(text: string): string {
    let cleaned: string = text;
    const allTriggers: string[] = IntentEngine.compareTriggers
      .concat(IntentEngine.searchTriggers)
      .concat(IntentEngine.orderTriggers);
    allTriggers.sort((a: string, b: string) => b.length - a.length);
    for (let i = 0; i < allTriggers.length; i += 1) {
      cleaned = cleaned.split(allTriggers[i]).join('');
    }
    const fillerWords: string[] = [
      '的', '了', '一', '个', '我', '帮', '给', '来', '用', '去',
      '要', '和', '与', '及', '上', '下', '是', '有', '就', '那',
      '这', '很', '都', '还', '也', '吧', '呢', '啊', '哦', '嗯',
      '点', '些', '种', '款', '把', '台', '支', '套', '包', '盒',
      '瓶', '件', '双', '对', '两', '三', '四', '五', '不', '更',
      '最', '比较', '能够', '可以', '适合', '需要', '想要', '喜欢'
    ];
    for (let i = 0; i < fillerWords.length; i += 1) {
      cleaned = cleaned.split(fillerWords[i]).join('');
    }
    cleaned = cleaned.replace(/\s+/g, '').trim();
    if (cleaned.length >= 2) {
      return cleaned;
    }
    return '';
  }

  private static extractCategory(product: string): string {
    for (let i = 0; i < IntentEngine.categoryMap.length; i += 1) {
      const group: string[] = IntentEngine.categoryMap[i];
      for (let j = 0; j < group.length - 1; j += 1) {
        if (group[j] === product) {
          return group[group.length - 1];
        }
      }
    }
    return '';
  }

  private static extractAttributes(text: string): StructuredAttributes {
    const attrs: StructuredAttributes = emptyStructuredAttributes();
    const matchedFeatures: string[] = [];
    const rawAttrs: string[] = [];

    for (let i = 0; i < IntentEngine.colorEntries.length; i += 1) {
      if (text.indexOf(IntentEngine.colorEntries[i].keyword) >= 0) {
        attrs.color = IntentEngine.colorEntries[i].standardValue;
        break;
      }
    }
    for (let i = 0; i < IntentEngine.sizeEntries.length; i += 1) {
      if (text.indexOf(IntentEngine.sizeEntries[i].keyword) >= 0) {
        attrs.size = IntentEngine.sizeEntries[i].standardValue;
        break;
      }
    }
    for (let i = 0; i < IntentEngine.materialEntries.length; i += 1) {
      if (text.indexOf(IntentEngine.materialEntries[i].keyword) >= 0) {
        attrs.material = IntentEngine.materialEntries[i].standardValue;
        break;
      }
    }
    for (let i = 0; i < IntentEngine.featureEntries.length; i += 1) {
      if (text.indexOf(IntentEngine.featureEntries[i].keyword) >= 0) {
        matchedFeatures.push(IntentEngine.featureEntries[i].standardValue);
      }
    }
    attrs.features = matchedFeatures;

    const allDictionaryWords: string[] = [];
    for (let i = 0; i < IntentEngine.colorEntries.length; i += 1) {
      allDictionaryWords.push(IntentEngine.colorEntries[i].keyword);
    }
    for (let i = 0; i < IntentEngine.sizeEntries.length; i += 1) {
      allDictionaryWords.push(IntentEngine.sizeEntries[i].keyword);
    }
    for (let i = 0; i < IntentEngine.materialEntries.length; i += 1) {
      allDictionaryWords.push(IntentEngine.materialEntries[i].keyword);
    }
    for (let i = 0; i < IntentEngine.featureEntries.length; i += 1) {
      allDictionaryWords.push(IntentEngine.featureEntries[i].keyword);
    }
    for (let i = 0; i < IntentEngine.compareTriggers.length; i += 1) {
      allDictionaryWords.push(IntentEngine.compareTriggers[i]);
    }
    for (let i = 0; i < IntentEngine.searchTriggers.length; i += 1) {
      allDictionaryWords.push(IntentEngine.searchTriggers[i]);
    }
    for (let i = 0; i < IntentEngine.orderTriggers.length; i += 1) {
      allDictionaryWords.push(IntentEngine.orderTriggers[i]);
    }
    for (let i = 0; i < IntentEngine.payTriggers.length; i += 1) {
      allDictionaryWords.push(IntentEngine.payTriggers[i]);
    }
    for (let i = 0; i < IntentEngine.getProductKeywords().length; i += 1) {
      allDictionaryWords.push(IntentEngine.getProductKeywords()[i]);
    }

    // 从文本中剔除已知词和填充词，剩余 >=2 字的片段作为 rawAttributes
    let remaining: string = text;
    for (let i = 0; i < allDictionaryWords.length; i += 1) {
      remaining = remaining.split(allDictionaryWords[i]).join('');
    }
    const fillerWords: string[] = [
      '的', '了', '一', '个', '想', '我', '帮', '看', '给', '来',
      '双', '件', '罐', '把', '台', '支', '套', '包', '盒', '瓶',
      '用', '和', '与', '及', '要', '去', '到', '上', '下', '是',
      '两', '三', '四', '五', '六', '七', '八', '九', '十',
      '1', '2', '3', '4', '5', '6', '7', '8', '9', '0'
    ];
    for (let i = 0; i < fillerWords.length; i += 1) {
      remaining = remaining.split(fillerWords[i]).join('');
    }
    remaining = remaining.replace(/\s+/g, '');
    if (remaining.length >= 2) {
      rawAttrs.push(remaining);
    }
    attrs.rawAttributes = rawAttrs;

    return attrs;
  }

  static extractQuantity(text: string): number {
    if (text.indexOf('双') >= 0) {
      const num: number = IntentEngine.extractNumericQuantity(text);
      return num > 1 ? num : 2;
    }
    if (text.indexOf('对') >= 0) {
      const num: number = IntentEngine.extractNumericQuantity(text);
      return num > 1 ? num : 2;
    }
    return IntentEngine.extractNumericQuantity(text);
  }

  private static extractNumericQuantity(text: string): number {
    if (text.indexOf('九') >= 0 || text.indexOf('9') >= 0) {
      return 9;
    }
    if (text.indexOf('八') >= 0 || text.indexOf('8') >= 0) {
      return 8;
    }
    if (text.indexOf('七') >= 0 || text.indexOf('7') >= 0) {
      return 7;
    }
    if (text.indexOf('六') >= 0 || text.indexOf('6') >= 0) {
      return 6;
    }
    if (text.indexOf('五') >= 0 || text.indexOf('5') >= 0) {
      return 5;
    }
    if (text.indexOf('四') >= 0 || text.indexOf('4') >= 0) {
      return 4;
    }
    if (text.indexOf('三') >= 0 || text.indexOf('3') >= 0) {
      return 3;
    }
    if (text.indexOf('两') >= 0 || text.indexOf('二') >= 0 || text.indexOf('2') >= 0) {
      return 2;
    }
    if (text.indexOf('一') >= 0 || text.indexOf('1') >= 0) {
      return 1;
    }
    return 1;
  }

  private static calculateConfidence(intent: AgentIntent): number {
    let score: number = 0;
    if (intent.product.length > 0) {
      score += 0.5;
    }
    if (intent.category.length > 0) {
      score += 0.1;
    }
    if (intent.attributes.features.length > 0) {
      score += 0.2;
    }
    if (intent.attributes.color.length > 0 || intent.attributes.size.length > 0) {
      score += 0.1;
    }
    if (intent.type !== IntentType.Unknown) {
      score += 0.1;
    }
    return Math.min(1.0, score);
  }

  private static generateSupplementQuestions(intent: AgentIntent): string[] {
    const questions: string[] = [];
    if (intent.product.length === 0) {
      questions.push('您想买什么商品？');
      return questions;
    }
    if (intent.attributes.color.length === 0 && IntentEngine.isColorRelevantProduct(intent.product)) {
      questions.push('您对颜色有偏好吗？');
    }
    if (intent.attributes.size.length === 0 && IntentEngine.isSizeRelevantProduct(intent.product)) {
      questions.push('您需要什么尺寸？');
    }
    if (intent.attributes.features.length === 0) {
      questions.push('有什么特别的需求吗？比如价格范围、功能偏好等。');
    }
    return questions;
  }

  private static isColorRelevantProduct(product: string): boolean {
    const colorRelevant: string[] = ['鞋', '手机', '跑鞋'];
    for (let i = 0; i < colorRelevant.length; i += 1) {
      if (product.indexOf(colorRelevant[i]) >= 0) {
        return true;
      }
    }
    return false;
  }

  private static isSizeRelevantProduct(product: string): boolean {
    const sizeRelevant: string[] = ['鞋', '推车'];
    for (let i = 0; i < sizeRelevant.length; i += 1) {
      if (product.indexOf(sizeRelevant[i]) >= 0) {
        return true;
      }
    }
    return false;
  }

  private static hasOnlyAttributeWords(text: string): boolean {
    if (text.length > 6) {
      return false;
    }
    const attributeWords: string[] = [];
    for (let i = 0; i < IntentEngine.colorEntries.length; i += 1) {
      attributeWords.push(IntentEngine.colorEntries[i].keyword);
    }
    for (let i = 0; i < IntentEngine.sizeEntries.length; i += 1) {
      attributeWords.push(IntentEngine.sizeEntries[i].keyword);
    }
    for (let i = 0; i < IntentEngine.materialEntries.length; i += 1) {
      attributeWords.push(IntentEngine.materialEntries[i].keyword);
    }
    for (let i = 0; i < IntentEngine.featureEntries.length; i += 1) {
      attributeWords.push(IntentEngine.featureEntries[i].keyword);
    }
    for (let i = 0; i < attributeWords.length; i += 1) {
      if (text.indexOf(attributeWords[i]) >= 0) {
        return true;
      }
    }
    return false;
  }

  static mergeSupplementIntent(baseIntent: AgentIntent, supplementText: string): AgentIntent {
    const supplement: AgentIntent = IntentEngine.parse(supplementText);
    return IntentEngine.mergeSupplement(baseIntent, supplement);
  }

  private static mergeSupplement(baseIntent: AgentIntent, supplement: AgentIntent): AgentIntent {
    const merged: AgentIntent = cloneAgentIntent(baseIntent);
    merged.rawText = baseIntent.rawText + ' ' + supplement.rawText;
    if (supplement.attributes.color.length > 0) {
      merged.attributes.color = supplement.attributes.color;
    }
    if (supplement.attributes.size.length > 0) {
      merged.attributes.size = supplement.attributes.size;
    }
    if (supplement.attributes.material.length > 0) {
      merged.attributes.material = supplement.attributes.material;
    }
    for (let i = 0; i < supplement.attributes.features.length; i += 1) {
      const feature: string = supplement.attributes.features[i];
      if (merged.attributes.features.indexOf(feature) < 0) {
        merged.attributes.features.push(feature);
      }
    }
    for (let i = 0; i < supplement.attributes.rawAttributes.length; i += 1) {
      const raw: string = supplement.attributes.rawAttributes[i];
      if (merged.attributes.rawAttributes.indexOf(raw) < 0) {
        merged.attributes.rawAttributes.push(raw);
      }
    }
    if (supplement.quantity > 1) {
      merged.quantity = supplement.quantity;
    }
    return merged;
  }

  static extractProductIndex(text: string): number {
    if (text.indexOf('第三') >= 0 || text.indexOf('第3') >= 0 || text.indexOf('3') >= 0) {
      return 2;
    }
    if (text.indexOf('第二') >= 0 || text.indexOf('第2') >= 0 || text.indexOf('2') >= 0) {
      return 1;
    }
    if (text.indexOf('第一') >= 0 || text.indexOf('第1') >= 0 || text.indexOf('1') >= 0) {
      return 0;
    }
    return 0;
  }
}
