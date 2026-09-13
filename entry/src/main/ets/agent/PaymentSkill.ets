import {
  AgentIntent,
  ConversationContext,
  emptyProductCandidate,
  emptySkillResultData,
  IntentType,
  PaymentPreview,
  Skill,
  SkillResult
} from './AgentModels';
import { PaymentMethod, ProductCandidate } from '../models/ShoppingModels';
import { AgentSessionManager } from './AgentSessionManager';
import { AddressService } from '../services/AddressService';

export class PaymentSkill implements Skill {
  name: string = 'payment';
  description: string = '支付：推荐支付方式，校验前置条件，生成支付预览';

  canHandle(intent: AgentIntent): boolean {
    return intent.type === IntentType.Pay;
  }

  execute(intent: AgentIntent, context: ConversationContext): SkillResult {
    const data = emptySkillResultData();
    const session = AgentSessionManager.getSession();
    const product: ProductCandidate = session.selectedProduct.id.length > 0
      ? session.selectedProduct
      : emptyProductCandidate();
    const quantity: number = session.quantity > 0 ? session.quantity : 1;
    if (product.id.length === 0) {
      return {
        success: false,
        data: data,
        message: '请先选择商品再进行支付。',
        fallbackUsed: false
      };
    }
    const hasAddress: boolean = AddressService.getDefaultAddress() !== undefined;
    const availableMethods: PaymentMethod[] = [
      PaymentMethod.HuaWeiPay,
      PaymentMethod.Face,
      PaymentMethod.Fingerprint,
      PaymentMethod.Password
    ];
    // 精确匹配用户意图，未指定则默认华为支付
    const detected: PaymentMethod = PaymentSkill.detectPaymentMethod(intent.rawText);
    AgentSessionManager.setPaymentMethod(detected);
    const totalPrice: number = product.price * quantity;
    const ready: boolean = product.id.length > 0 && hasAddress;
    const paymentPreview: PaymentPreview = {
      product: product,
      quantity: quantity,
      totalPrice: totalPrice,
      availableMethods: availableMethods,
      recommendedMethod: detected,
      needsAddress: !hasAddress,
      ready: ready
    };
    data.paymentPreview = paymentPreview;
    if (!hasAddress) {
      return {
        success: false,
        data: data,
        message: '请先添加收货地址，再进行支付。',
        fallbackUsed: false
      };
    }
    AgentSessionManager.waitPayment();
    return {
      success: true,
      data: data,
      message: '支付准备就绪，总计 ¥' + totalPrice.toFixed(2) + '。',
      fallbackUsed: false
    };
  }

  private static detectPaymentMethod(text: string): PaymentMethod {
    if (text.indexOf('华为') >= 0) {
      return PaymentMethod.HuaWeiPay;
    }
    if (text.indexOf('人脸') >= 0) {
      return PaymentMethod.Face;
    }
    if (text.indexOf('指纹') >= 0) {
      return PaymentMethod.Fingerprint;
    }
    if (text.indexOf('密码') >= 0) {
      return PaymentMethod.Password;
    }
    return PaymentMethod.HuaWeiPay;
  }
}
