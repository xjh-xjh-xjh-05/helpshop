import {
  AgentIntent,
  AgentActionType,
  ConversationContext,
  emptyAgentIntent,
  emptySkillResultData,
  IntentType,
  SkillResult,
  cloneAgentIntent
} from './AgentModels';
import { ProductCandidate } from '../models/ShoppingModels';
import { MockProductService } from '../services/MockProductService';

export class AgentErrorHandler {
  static handle(error: Error, intent: AgentIntent, context: ConversationContext): SkillResult {
    const fallbackResult: SkillResult = AgentErrorHandler.tryLocalFallback(intent);
    fallbackResult.message = AgentErrorHandler.buildFriendlyErrorMessage(error) + ' ' + fallbackResult.message;
    fallbackResult.fallbackUsed = true;
    return fallbackResult;
  }

  static handleUnknownIntent(text: string, context: ConversationContext): SkillResult {
    const emptyIntent: AgentIntent = cloneAgentIntent(emptyAgentIntent());
    emptyIntent.type = IntentType.Unknown;
    emptyIntent.rawText = text;
    emptyIntent.confidence = 0;
    const data = emptySkillResultData();
    const allProducts: ProductCandidate[] = MockProductService.getAllProducts().slice(0, 5);
    data.products = allProducts;
    return {
      success: false,
      data: data,
      message: '未能理解您的需求，请换个说法再试试。以下是一些热门商品供您参考。',
      fallbackUsed: true
    };
  }

  private static tryLocalFallback(intent: AgentIntent): SkillResult {
    const data = emptySkillResultData();
    if (intent.type === IntentType.Compare || intent.type === IntentType.Search) {
      const keyword: string = intent.product.length > 0 ? intent.product : intent.rawText;
      const allProducts: ProductCandidate[] = MockProductService.getAllProducts();
      const matched: ProductCandidate[] = allProducts.filter((item: ProductCandidate) => {
        return item.name.indexOf(keyword) >= 0 ||
          item.tags.some((tag: string) => keyword.indexOf(tag) >= 0 || tag.indexOf(keyword) >= 0);
      });
      data.products = matched.length > 0 ? matched.slice(0, 5) : allProducts.slice(0, 5);
      return {
        success: matched.length > 0,
        data: data,
        message: matched.length > 0 ? '已降级为本地模糊匹配。' : '未找到匹配商品，已返回热门推荐。',
        fallbackUsed: true
      };
    }
    if (intent.type === IntentType.OrderConfirm) {
      return {
        success: false,
        data: data,
        message: '下单服务暂时不可用，请稍后再试。',
        fallbackUsed: true
      };
    }
    return {
      success: false,
      data: data,
      message: '服务暂时不可用，请稍后再试。',
      fallbackUsed: true
    };
  }

  private static buildFriendlyErrorMessage(error: Error): string {
    const message: string = error.message;
    if (message.indexOf('network') >= 0 || message.indexOf('Network') >= 0) {
      return '网络似乎不太通畅。';
    }
    if (message.indexOf('timeout') >= 0 || message.indexOf('Timeout') >= 0) {
      return '请求超时，请稍后重试。';
    }
    return '遇到了一点问题。';
  }
}
