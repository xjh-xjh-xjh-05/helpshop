import { Address, OrderDraft, PaymentMethod, PaymentStatus, ProductCandidate } from '../models/ShoppingModels';
import { AuthService } from './AuthService';
import { TimeUtils } from '../utils/TimeUtils';
import { CloneUtils } from '../utils/CloneUtils';
import { OrderStore } from './OrderStore';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'OrderService';
const DOMAIN: number = 0x0001;

export class OrderService {
  private static orders: OrderDraft[] | null = null;

  private static ensureLoaded(): void {
    if (OrderService.orders === null) {
      OrderService.orders = OrderStore.loadOrders();
      hilog.info(DOMAIN, TAG, 'OrderService loaded from store, count=' + (OrderService.orders?.length ?? 0).toString());
    }
  }

  private static persist(): void {
    if (OrderService.orders !== null) {
      OrderStore.saveOrders(OrderService.orders);
    }
  }

  static createOrder(product: ProductCandidate, quantity: number, address: Address, method: PaymentMethod): OrderDraft {
    OrderService.ensureLoaded();
    const order: OrderDraft = {
      id: `order-${Date.now()}`,
      elderlyAccountId: AuthService.getCurrentElderlyAccountId(),
      managedByChildAccountId: AuthService.getCurrentChildAccountId(),
      createdAt: TimeUtils.formatDate(new Date()),
      product: CloneUtils.cloneProduct(product),
      quantity: quantity,
      address: CloneUtils.cloneAddress(address),
      totalPrice: product.price * quantity,
      paymentMethod: method,
      paymentStatus: PaymentStatus.Success
    };
    OrderService.orders!.unshift(order);
    OrderService.persist();
    return CloneUtils.cloneOrder(order);
  }

  static listOrders(): OrderDraft[] {
    OrderService.ensureLoaded();
    const elderlyAccountId = AuthService.getCurrentElderlyAccountId();
    const childAccountId = AuthService.getCurrentChildAccountId();
    return OrderService.orders!.filter((item: OrderDraft) => {
      return item.elderlyAccountId === elderlyAccountId || item.managedByChildAccountId === childAccountId;
    }).map((item: OrderDraft) => CloneUtils.cloneOrder(item));
  }

  static listAllOrders(): OrderDraft[] {
    OrderService.ensureLoaded();
    return OrderService.orders!.map((item: OrderDraft) => CloneUtils.cloneOrder(item));
  }

  static countCurrentOrders(): number {
    return OrderService.listOrders().length;
  }

  static clearOrders(): void {
    OrderService.orders = [];
    OrderService.persist();
  }

  static replaceOrders(orders: OrderDraft[]): void {
    OrderService.orders = orders.map((item: OrderDraft) => CloneUtils.cloneOrder(item));
    OrderService.persist();
  }

  static deleteOrder(orderId: string): boolean {
    OrderService.ensureLoaded();
    const index: number = OrderService.orders!.findIndex((item: OrderDraft) => item.id === orderId);
    if (index >= 0) {
      OrderService.orders!.splice(index, 1);
      OrderService.persist();
      return true;
    }
    return false;
  }

  static mergeOrders(remoteOrders: OrderDraft[]): void {
    if (remoteOrders.length === 0) {
      return;
    }
    OrderService.ensureLoaded();
    const existingIds: Set<string> = new Set(OrderService.orders!.map((o: OrderDraft) => o.id));
    let changed: boolean = false;
    for (let i = 0; i < remoteOrders.length; i += 1) {
      if (!existingIds.has(remoteOrders[i].id)) {
        OrderService.orders!.unshift(CloneUtils.cloneOrder(remoteOrders[i]));
        changed = true;
      }
    }
    if (changed) {
      OrderService.persist();
      hilog.info(DOMAIN, TAG, 'OrderService merged orders, total=' + OrderService.orders!.length.toString());
    }
  }

  static paymentMethodName(method: PaymentMethod): string {
    if (method === PaymentMethod.Face) {
      return '人脸支付';
    }
    if (method === PaymentMethod.Fingerprint) {
      return '指纹支付';
    }
    if (method === PaymentMethod.HuaWeiPay) {
      return '华为支付';
    }
    return '密码支付';
  }

}
