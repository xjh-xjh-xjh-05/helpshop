import { hilog } from '@kit.PerformanceAnalysisKit';
import { DistributedDataSync, PaymentSyncPayload } from './DistributedDataSync';
import { OrderService } from '../services/OrderService';
import { ReminderService } from '../services/ReminderService';

const DOMAIN: number = 0x0000;
const TAG: string = 'HelpShop';

export interface PaymentEventPayload {
  orderId: string;
  productName: string;
  amount: number;
  elderlyName: string;
  method: string;
  time: string;
  status: string;
}

export class DistributedEventEmitter {
  static readonly EVENT_PAYMENT_SUCCESS: string = 'helpshop.payment.success';
  static readonly EVENT_ORDER_CREATED: string = 'helpshop.order.created';
  static readonly EVENT_PAYMENT_STARTED: string = 'helpshop.payment.started';

  private static lastPaymentEvent: PaymentEventPayload | null = null;

  static getLastPaymentEvent(): PaymentEventPayload | null {
    return DistributedEventEmitter.lastPaymentEvent;
  }

  static emitPaymentStarted(orderId: string, method: string, amount: number): void {
    hilog.info(DOMAIN, TAG, 'DistributedEventEmitter paymentStarted orderId=%{public}s', orderId);
  }

  static emitPaymentSuccess(orderId: string, productName: string, elderlyName: string, amount: number, method: string): void {
    const payload: PaymentEventPayload = {
      orderId: orderId,
      productName: productName,
      amount: amount,
      elderlyName: elderlyName,
      method: method,
      status: 'success',
      time: DistributedDataSync.nowText()
    };
    DistributedEventEmitter.lastPaymentEvent = payload;
    AppStorage.setOrCreate('lastPaymentEvent', JSON.stringify(payload));
    DistributedDataSync.getInstance().emitPaymentSuccess(orderId, productName, elderlyName, amount, method);
    DistributedEventEmitter.syncRemindersAfterChange();
    hilog.info(DOMAIN, TAG, 'DistributedEventEmitter paymentSuccess orderId=%{public}s via distributedDataObject', orderId);
  }

  static emitOrderCreated(orderId: string, productName: string, elderlyName: string): void {
    DistributedEventEmitter.syncOrdersAfterChange();
    hilog.info(DOMAIN, TAG, 'DistributedEventEmitter orderCreated orderId=%{public}s', orderId);
  }

  static syncRemindersAfterChange(): void {
    const allReminders = ReminderService.listAllReminders();
    DistributedDataSync.getInstance().syncReminders(allReminders);
  }

  static syncOrdersAfterChange(): void {
    const allOrders = OrderService.listAllOrders();
    DistributedDataSync.getInstance().syncOrders(allOrders);
  }
}
