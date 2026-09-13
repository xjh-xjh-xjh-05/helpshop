import { PaymentMethod, PaymentRecord, PaymentResult, PaymentStatus, ProductCandidate } from '../models/ShoppingModels';
import { AuthService } from './AuthService';
import { CloneUtils } from '../utils/CloneUtils';

export class PaymentRecordService {
  private static records: PaymentRecord[] = [];

  static createRecord(result: PaymentResult, amount: number, product?: ProductCandidate, orderId?: string): PaymentRecord {
    const record: PaymentRecord = {
      id: `pay-record-${Date.now()}`,
      orderId: orderId,
      elderlyAccountId: AuthService.getCurrentElderlyAccountId(),
      productId: product ? product.id : undefined,
      amount: amount,
      method: result.method,
      status: result.status,
      message: result.message,
      createdAt: result.paidAt
    };
    PaymentRecordService.records.unshift(record);
    return CloneUtils.clonePaymentRecord(record);
  }

  static listRecords(): PaymentRecord[] {
    const elderlyAccountId = AuthService.getCurrentElderlyAccountId();
    return PaymentRecordService.records.filter((item: PaymentRecord) => {
      return item.elderlyAccountId === elderlyAccountId;
    }).map((item: PaymentRecord) => CloneUtils.clonePaymentRecord(item));
  }

  static countCurrentRecords(): number {
    return PaymentRecordService.listRecords().length;
  }

  static createFailureRecord(result: PaymentResult): PaymentRecord {
    return PaymentRecordService.createRecord(result, 0, undefined, undefined);
  }

  static methodFallback(): PaymentMethod {
    return PaymentMethod.Face;
  }

  static statusName(status: PaymentStatus): string {
    if (status === PaymentStatus.Success) {
      return '支付成功';
    }
    if (status === PaymentStatus.Failed) {
      return '支付失败';
    }
    if (status === PaymentStatus.Cancelled) {
      return '支付取消';
    }
    return '待支付';
  }

}
