import {
  AgentIntent,
  ConversationContext,
  emptySkillResultData,
  IntentType,
  Skill,
  SkillResult
} from './AgentModels';
import { ProductCandidate } from '../models/ShoppingModels';
import { MockProductService } from '../services/MockProductService';
import { PlatformProductGatewayService } from '../services/PlatformProductGatewayService';

export class ProductSearchSkill implements Skill {
  name: string = 'product_search';
  description: string = '商品搜索：根据关键词搜索商品列表';

  canHandle(intent: AgentIntent): boolean {
    return intent.type === IntentType.Search;
  }

  execute(intent: AgentIntent, context: ConversationContext): SkillResult {
    const data = emptySkillResultData();
    try {
      const keyword: string = intent.product.length > 0 ? intent.product : intent.rawText;
      const limit: number = 10;
      const products: ProductCandidate[] = PlatformProductGatewayService.searchCandidates(keyword, limit);
      if (products.length === 0) {
        const allProducts: ProductCandidate[] = MockProductService.getAllProducts().slice(0, limit);
        data.products = allProducts;
        return {
          success: false,
          data: data,
          message: '未找到匹配商品，已返回热门推荐。',
          fallbackUsed: true
        };
      }
      data.products = products;
      return {
        success: true,
        data: data,
        message: '搜索完成，共找到 ' + products.length.toString() + ' 款商品',
        fallbackUsed: false
      };
    } catch (error) {
      const allProducts: ProductCandidate[] = MockProductService.getAllProducts().slice(0, 10);
      data.products = allProducts;
      return {
        success: false,
        data: data,
        message: '搜索服务暂时不可用，已返回热门推荐。',
        fallbackUsed: true
      };
    }
  }
}
