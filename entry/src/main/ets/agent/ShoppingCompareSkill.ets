import {
  AgentIntent,
  ConversationContext,
  emptySkillResultData,
  IntentType,
  Skill,
  SkillResult
} from './AgentModels';
import { ProductCandidate, RecommendationResult } from '../models/ShoppingModels';
import { CompareEngine } from './CompareEngine';
import { ReasonBuilder } from './ReasonBuilder';
import { MockProductService, ProductSearchResult } from '../services/MockProductService';
import { PlatformProductGatewayService } from '../services/PlatformProductGatewayService';
import { agentIntentToParsedIntent } from './AgentModels';

export class ShoppingCompareSkill implements Skill {
  name: string = 'shopping_compare';
  description: string = '购物比价：根据商品名返回多平台比价数据';

  canHandle(intent: AgentIntent): boolean {
    return intent.type === IntentType.Compare;
  }

  execute(intent: AgentIntent, context: ConversationContext): SkillResult {
    const data = emptySkillResultData();
    try {
      const parsedIntent = agentIntentToParsedIntent(intent);
      // 优先走平台商品网关，失败回退 Mock
      const gatewayCandidates: ProductCandidate[] = PlatformProductGatewayService.searchCandidates(intent.product, 20);
      let searchResult: ProductSearchResult;
      if (gatewayCandidates.length > 0) {
        searchResult = { products: gatewayCandidates, fallbackUsed: false };
      } else {
        searchResult = MockProductService.searchProductsWithFallback(parsedIntent);
      }
      const candidates: ProductCandidate[] = searchResult.products;
      if (candidates.length === 0) {
        return {
          success: false,
          data: data,
          message: '未找到匹配商品，请尝试其他关键词。',
          fallbackUsed: true
        };
      }
      const recommendation: RecommendationResult = CompareEngine.compare(candidates, intent);
      recommendation.reason = ReasonBuilder.buildReason(
        recommendation.bestProduct,
        recommendation.candidates,
        intent,
        searchResult.fallbackUsed
      );
      recommendation.fallbackUsed = searchResult.fallbackUsed;
      data.recommendation = recommendation;
      data.products = candidates;
      return {
        success: true,
        data: data,
        message: '比价推荐已生成',
        fallbackUsed: searchResult.fallbackUsed
      };
    } catch (error) {
      return {
        success: false,
        data: data,
        message: '比价过程中出现异常',
        fallbackUsed: true
      };
    }
  }
}
