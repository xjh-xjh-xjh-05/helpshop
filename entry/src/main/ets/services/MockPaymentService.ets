import { PaymentMethod, PaymentResult, PaymentStatus } from '../models/ShoppingModels';
import { TimeUtils } from '../utils/TimeUtils';

export class MockPaymentService {
  static paySuccess(method: PaymentMethod): PaymentResult {
    return {
      status: PaymentStatus.Success,
      message: `${MockPaymentService.methodName(method)}支付成功，购物提醒已模拟发送给子女端。`,
      method: method,
      paidAt: TimeUtils.formatDate(new Date())
    };
  }

  static payFailed(): PaymentResult {
    return {
      status: PaymentStatus.Failed,
      message: '支付失败，请检查余额或稍后重新支付。',
      method: PaymentMethod.Face,
      paidAt: TimeUtils.formatDate(new Date())
    };
  }

  static payCancelled(): PaymentResult {
    return {
      status: PaymentStatus.Cancelled,
      message: '已取消支付，可返回确认页重新发起。',
      method: PaymentMethod.Face,
      paidAt: TimeUtils.formatDate(new Date())
    };
  }

  private static methodName(method: PaymentMethod): string {
    if (method === PaymentMethod.Face) {
      return '人脸';
    }
    if (method === PaymentMethod.Fingerprint) {
      return '指纹';
    }
    if (method === PaymentMethod.HuaWeiPay) {
      return '华为';
    }
    return '密码';
  }

}
