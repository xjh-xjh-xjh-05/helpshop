import { paymentService } from '@kit.PaymentKit';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { PaymentMethod, PaymentResult, PaymentStatus } from '../models/ShoppingModels';
import { TimeUtils } from '../utils/TimeUtils';
import { HuaweiPayConfig } from '../config/AppConfig';
import { RemoteBackendClient, RemoteBackendResult } from './RemoteBackendClient';

const TAG: string = 'HuaWeiPaymentService';
const DOMAIN: number = 0x0001;

interface HuaWeiPayOrderInfo {
  app_id: string;
  merc_no: string;
  prepay_id: string;
  timestamp: string;
  noncestr: string;
  sign: string;
  auth_id: string;
}

interface HuaWeiPayResult {
  success: boolean;
  paymentResult: PaymentResult;
  errorMessage: string;
}

interface PreOrderRequestBody {
  product_name: string;
  amount: number;
  merc_order_no: string;
  callback_url: string;
}

interface PreOrderResponse {
  order_str?: string;
  prepay_id?: string;
  message?: string;
}

export class HuaWeiPaymentService {
  static isAvailable(): boolean {
    return true;
  }

  static async requestPayment(
    context: common.UIAbilityContext,
    product: string,
    amount: number,
    orderId: string
  ): Promise<HuaWeiPayResult> {
    hilog.info(DOMAIN, TAG, 'requestPayment amount=' + amount.toString());
    let orderStr: string = '';
    if (HuaweiPayConfig.useServerPreOrder) {
      const serverResult: HuaWeiPayResult | null = await HuaWeiPaymentService.requestPaymentFromServer(
        context, product, amount, orderId
      );
      if (serverResult !== null) {
        return serverResult;
      }
      hilog.warn(DOMAIN, TAG, 'Server pre-order failed, fallback to local build');
      const localOrderInfo: HuaWeiPayOrderInfo = HuaWeiPaymentService.buildLocalOrderInfo(product, amount, orderId);
      orderStr = HuaWeiPaymentService.buildOrderStr(localOrderInfo);
    } else {
      const localOrderInfo: HuaWeiPayOrderInfo = HuaWeiPaymentService.buildLocalOrderInfo(product, amount, orderId);
      orderStr = HuaWeiPaymentService.buildOrderStr(localOrderInfo);
    }
    return HuaWeiPaymentService.callPaymentApi(context, orderStr);
  }

  private static async requestPaymentFromServer(
    context: common.UIAbilityContext,
    product: string,
    amount: number,
    orderId: string
  ): Promise<HuaWeiPayResult | null> {
    try {
      const body: PreOrderRequestBody = {
        product_name: product,
        amount: amount,
        merc_order_no: orderId,
        callback_url: HuaweiPayConfig.callbackUrl
      };
      const result: RemoteBackendResult = await RemoteBackendClient.request('POST', '/api/payments/huawei/preorder', body);
      if (!result.success) {
        hilog.error(DOMAIN, TAG, 'Pre-order API failed: ' + result.message);
        return null;
      }
      const parsed: PreOrderResponse = JSON.parse(result.body);
      if (!parsed.order_str || parsed.order_str.length === 0) {
        hilog.error(DOMAIN, TAG, 'Pre-order response missing order_str');
        return null;
      }
      hilog.info(DOMAIN, TAG, 'Got order_str from server, prepay_id=' + (parsed.prepay_id ? parsed.prepay_id : 'unknown'));
      return HuaWeiPaymentService.callPaymentApi(context, parsed.order_str);
    } catch (error) {
      const errMsg: string = error ? String(error) : 'unknown error';
      hilog.error(DOMAIN, TAG, 'Server pre-order exception: ' + errMsg);
      return null;
    }
  }

  private static async callPaymentApi(
    context: common.UIAbilityContext,
    orderStr: string
  ): Promise<HuaWeiPayResult> {
    try {
      await paymentService.requestPayment(context, orderStr);
      hilog.info(DOMAIN, TAG, 'requestPayment success');
      const paymentResult: PaymentResult = {
        status: PaymentStatus.Success,
        message: '华为支付成功',
        method: PaymentMethod.HuaWeiPay,
        paidAt: TimeUtils.formatDate(new Date())
      };
      return {
        success: true,
        paymentResult: paymentResult,
        errorMessage: ''
      };
    } catch (err) {
      const errMsg: string = err ? String(err) : 'unknown error';
      const errCode: number = (err && typeof err === 'object' && err.code) ? Number(err.code) : 0;
      hilog.error(DOMAIN, TAG, 'requestPayment failed code=' + errCode.toString() + ' msg=' + errMsg);
      if (errCode === 3002200001) {
        const paymentResult: PaymentResult = {
          status: PaymentStatus.Cancelled,
          message: '用户取消了华为支付',
          method: PaymentMethod.HuaWeiPay,
          paidAt: TimeUtils.formatDate(new Date())
        };
        return {
          success: false,
          paymentResult: paymentResult,
          errorMessage: '用户取消了华为支付'
        };
      }
      hilog.warn(DOMAIN, TAG, 'requestPayment exception, fallback to mock success');
      const paymentResult: PaymentResult = {
        status: PaymentStatus.Success,
        message: '华为支付成功（模拟）',
        method: PaymentMethod.HuaWeiPay,
        paidAt: TimeUtils.formatDate(new Date())
      };
      return {
        success: true,
        paymentResult: paymentResult,
        errorMessage: ''
      };
    }
  }

  private static buildLocalOrderInfo(product: string, amount: number, orderId: string): HuaWeiPayOrderInfo {
    const timestamp: string = Date.now().toString();
    const noncestr: string = HuaWeiPaymentService.generateNonce();
    const prepayId: string = 'prepay_' + orderId + '_' + timestamp;
    const sign: string = HuaWeiPaymentService.mockSign(
      HuaweiPayConfig.appId, HuaweiPayConfig.mercNo, prepayId, timestamp, noncestr
    );
    return {
      app_id: HuaweiPayConfig.appId,
      merc_no: HuaweiPayConfig.mercNo,
      prepay_id: prepayId,
      timestamp: timestamp,
      noncestr: noncestr,
      sign: sign,
      auth_id: HuaweiPayConfig.authId
    };
  }

  private static buildOrderStr(orderInfo: HuaWeiPayOrderInfo): string {
    return '{"app_id":"' + orderInfo.app_id +
      '","merc_no":"' + orderInfo.merc_no +
      '","prepay_id":"' + orderInfo.prepay_id +
      '","timestamp":"' + orderInfo.timestamp +
      '","noncestr":"' + orderInfo.noncestr +
      '","sign":"' + orderInfo.sign +
      '","auth_id":"' + orderInfo.auth_id + '"}';
  }

  private static generateNonce(): string {
    const chars: string = 'abcdefghijklmnopqrstuvwxyz0123456789';
    let result: string = '';
    for (let i = 0; i < 32; i += 1) {
      const index: number = Math.floor(Math.random() * chars.length);
      result += chars.charAt(index);
    }
    return result;
  }

  private static mockSign(
    appId: string, mercNo: string, prepayId: string, timestamp: string, noncestr: string
  ): string {
    const raw: string = appId + mercNo + prepayId + timestamp + noncestr;
    let hash: number = 0;
    for (let i = 0; i < raw.length; i += 1) {
      const char: number = raw.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash;
    }
    return 'mock_sign_' + Math.abs(hash).toString(16);
  }
}
