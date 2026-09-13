import {
  AgentIntent,
  ConversationContext,
  emptySkillResultData,
  IntentType,
  OrderPreview,
  Skill,
  SkillResult
} from './AgentModels';
import { Address, ParsedIntent, ProductCandidate } from '../models/ShoppingModels';
import { MockProductService } from '../services/MockProductService';
import { AddressService } from '../services/AddressService';
import { TTSService } from '../services/TTSService';
import { AgentSessionManager } from './AgentSessionManager';

export class OrderConfirmSkill implements Skill {
  name: string = 'order_confirm';
  description: string = '下单确认：生成订单预览，确认后触发支付';

  canHandle(intent: AgentIntent): boolean {
    return intent.type === IntentType.OrderConfirm;
  }

  execute(intent: AgentIntent, context: ConversationContext): SkillResult {
    const data = emptySkillResultData();
    try {
      let productId: string = '';
      if (context.pendingIntent.product.length > 0 && context.pendingIntent.type === IntentType.Compare) {
        const candidates: ProductCandidate[] = OrderConfirmSkill.findCandidates(context.pendingIntent);
        if (candidates.length > 0) {
          productId = candidates[0].id;
        }
      }
      const product: ProductCandidate | undefined = productId.length > 0
        ? MockProductService.getProductById(productId)
        : undefined;
      if (!product) {
        return {
          success: false,
          data: data,
          message: '请先选择商品，再进行下单确认。',
          fallbackUsed: false
        };
      }
      const address: Address | undefined = AddressService.getDefaultAddress();
      // 一键流程：若 session 中未设置地址，自动取默认地址填入
      if (address && AgentSessionManager.getSession().addressId.length === 0) {
        AgentSessionManager.setAddress(address.id);
      }
      if (!address) {
        const ttsText: string = '购买' + product.name + '需要收货地址，请先添加收货地址再来下单。';
        TTSService.getInstance().speak(ttsText);
        return {
          success: false,
          data: data,
          message: ttsText,
          fallbackUsed: false
        };
      }
      const orderPreview: OrderPreview = {
        product: product,
        quantity: intent.quantity,
        address: address,
        totalPrice: product.price * intent.quantity,
        paymentUrl: ''
      };
      data.orderPreview = orderPreview;
      return {
        success: true,
        data: data,
        message: '订单预览已生成',
        fallbackUsed: false
      };
    } catch (error) {
      return {
        success: false,
        data: data,
        message: '下单服务暂时不可用，请稍后再试。',
        fallbackUsed: true
      };
    }
  }

  private static findCandidates(intent: AgentIntent): ProductCandidate[] {
    const parsedIntent: ParsedIntent = {
      product: intent.product,
      attributes: intent.attributes.features.concat(intent.attributes.rawAttributes),
      quantity: intent.quantity,
      rawText: intent.rawText
    };
    const searchResult = MockProductService.searchProductsWithFallback(parsedIntent);
    return searchResult.products;
  }
}
