import {
  AgentIntent,
  ConversationContext,
  emptySkillResultData,
  IntentType,
  Skill,
  SkillResult
} from './AgentModels';
import { Address, PaymentMethod, ProductCandidate } from '../models/ShoppingModels';
import { PlatformProductGatewayService } from '../services/PlatformProductGatewayService';
import { AddressService } from '../services/AddressService';
import { AgentSessionManager } from './AgentSessionManager';

export class ProductSelectSkill implements Skill {
  name: string = 'product_select';
  description: string = '选择推荐商品：根据序号选择推荐列表中的商品，自动确认订单并准备支付';

  canHandle(intent: AgentIntent): boolean {
    return intent.type === IntentType.ProductSelect;
  }

  execute(intent: AgentIntent, context: ConversationContext): SkillResult {
    const data = emptySkillResultData();
    const idx: number = intent.selectedIndex > 0 ? intent.selectedIndex : 1;
    const qty: number = intent.quantity > 0 ? intent.quantity : 1;

    let products: ProductCandidate[] = PlatformProductGatewayService.searchCandidates(
      intent.product.length > 0 ? intent.product : '',
      10
    );
    if (products.length === 0 && context.pendingIntent.product.length > 0) {
      products = PlatformProductGatewayService.searchCandidates(
        context.pendingIntent.product,
        10
      );
    }

    if (products.length === 0) {
      return {
        success: false,
        data: data,
        message: '没有找到推荐商品，请重新搜索。',
        fallbackUsed: false
      };
    }

    const selectIdx: number = Math.min(idx, products.length) - 1;
    const selected: ProductCandidate = products[selectIdx];

    AgentSessionManager.setProduct(selected);
    AgentSessionManager.setQuantity(qty);

    const address: Address | undefined = AddressService.getDefaultAddress();
    if (!address) {
      return {
        success: false,
        data: data,
        message: '需要收货地址，请先添加收货地址。',
        fallbackUsed: false
      };
    }
    AgentSessionManager.setAddress(address.id);

    data.products = products;
    data.orderPreview = {
      product: selected,
      quantity: qty,
      address: address,
      totalPrice: selected.price * qty,
      paymentUrl: ''
    };
    data.paymentPreview = {
      product: selected,
      quantity: qty,
      totalPrice: selected.price * qty,
      availableMethods: [PaymentMethod.HuaWeiPay],
      recommendedMethod: PaymentMethod.HuaWeiPay,
      needsAddress: false,
      ready: true
    };

    return {
      success: true,
      data: data,
      message: '已选择' + selected.name + '，默认地址已确认，正在准备支付。',
      fallbackUsed: false
    };
  }
}
