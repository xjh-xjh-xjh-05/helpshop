import { distributedDataObject } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { OrderDraft, PaymentMethod, PaymentStatus, ReminderRecord } from '../models/ShoppingModels';
import { OrderService } from '../services/OrderService';
import { ReminderService } from '../services/ReminderService';

const DOMAIN: number = 0x0001;
const TAG: string = 'HelpShop';
const SESSION_ID: string = 'helpshop_family_sync';

export interface PaymentSyncPayload {
  orderId: string;
  productName: string;
  amount: number;
  elderlyName: string;
  method: string;
  time: string;
  status: string;
}

class PaymentEventSource {
  orderId: string = '';
  productName: string = '';
  amount: number = 0;
  elderlyName: string = '';
  method: string = '';
  time: string = '';
  status: string = '';
}

class ReminderSyncSource {
  id: string = '';
  orderId: string = '';
  elderlyAccountId: string = '';
  childAccountId: string = '';
  title: string = '';
  content: string = '';
  createdAt: string = '';
  read: number = 0;
  version: number = 0;
}

class OrderSyncSource {
  id: string = '';
  elderlyAccountId: string = '';
  managedByChildAccountId: string = '';
  createdAt: string = '';
  productName: string = '';
  productId: string = '';
  platform: string = '';
  price: number = 0;
  quantity: number = 0;
  totalPrice: number = 0;
  addressId: string = '';
  addressReceiver: string = '';
  addressPhone: string = '';
  addressDetail: string = '';
  paymentMethod: string = '';
  paymentStatus: string = '';
  imageUrl: string = '';
}

class SyncRoot {
  paymentJson: string = '';
  remindersJson: string = '';
  remindersVersion: number = 0;
  ordersJson: string = '';
  ordersVersion: number = 0;
}

type DataChangeListener = (sessionId: string, fields: Array<string>) => void;

export class DistributedDataSync {
  private static instance: DistributedDataSync | null = null;
  private dataObject: distributedDataObject.DataObject | null = null;
  private paymentListeners: DataChangeListener[] = [];
  private reminderListeners: DataChangeListener[] = [];
  private orderListeners: DataChangeListener[] = [];
  private initialized: boolean = false;

  static getInstance(): DistributedDataSync {
    if (!DistributedDataSync.instance) {
      DistributedDataSync.instance = new DistributedDataSync();
    }
    return DistributedDataSync.instance;
  }

  init(context: common.Context): void {
    if (this.initialized) {
      hilog.info(DOMAIN, TAG, 'DistributedDataSync already initialized');
      return;
    }
    try {
      const source: SyncRoot = new SyncRoot();
      this.dataObject = distributedDataObject.create(context, source);
      this.dataObject.setSessionId(SESSION_ID);
      this.dataObject.on('change', (sessionId: string, fields: Array<string>) => {
        hilog.info(DOMAIN, TAG, 'DistributedDataSync change sessionId=%{public}s fields=%{public}s', sessionId, fields.join(','));
        this.onDataChanged(sessionId, fields);
      });
      this.dataObject.on('status', (sessionId: string, networkId: string, status: string) => {
        hilog.info(DOMAIN, TAG, 'DistributedDataSync status=%{public}s networkId=%{public}s', status, networkId);
      });
      this.initialized = true;
      hilog.info(DOMAIN, TAG, 'DistributedDataSync init success, sessionId=%{public}s', SESSION_ID);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'DistributedDataSync init failed');
    }
  }

  emitPaymentSuccess(orderId: string, productName: string, elderlyName: string, amount: number, method: string): void {
    if (!this.dataObject) {
      hilog.warn(DOMAIN, TAG, 'DistributedDataSync not initialized, skip emitPaymentSuccess');
      return;
    }
    const payload: PaymentEventSource = new PaymentEventSource();
    payload.orderId = orderId;
    payload.productName = productName;
    payload.amount = amount;
    payload.elderlyName = elderlyName;
    payload.method = method;
    payload.time = DistributedDataSync.nowText();
    payload.status = 'success';
    this.dataObject['paymentJson'] = JSON.stringify(payload);
    hilog.info(DOMAIN, TAG, 'DistributedDataSync emitPaymentSuccess orderId=%{public}s', orderId);
  }

  syncReminders(reminders: ReminderRecord[]): void {
    if (!this.dataObject) {
      hilog.warn(DOMAIN, TAG, 'DistributedDataSync not initialized, skip syncReminders');
      return;
    }
    const items: ReminderSyncSource[] = reminders.map((r: ReminderRecord) => {
      const src: ReminderSyncSource = new ReminderSyncSource();
      src.id = r.id;
      src.orderId = r.orderId;
      src.elderlyAccountId = r.elderlyAccountId ? r.elderlyAccountId : '';
      src.childAccountId = r.childAccountId ? r.childAccountId : '';
      src.title = r.title;
      src.content = r.content;
      src.createdAt = r.createdAt;
      src.read = r.read ? 1 : 0;
      src.version = 0;
      return src;
    });
    this.dataObject['remindersJson'] = JSON.stringify(items);
    const currentVersion: number = this.dataObject['remindersVersion'] as number;
    this.dataObject['remindersVersion'] = currentVersion + 1;
    hilog.info(DOMAIN, TAG, 'DistributedDataSync syncReminders count=%{public}d', items.length);
  }

  syncOrders(orders: OrderDraft[]): void {
    if (!this.dataObject) {
      hilog.warn(DOMAIN, TAG, 'DistributedDataSync not initialized, skip syncOrders');
      return;
    }
    const items: OrderSyncSource[] = orders.map((o: OrderDraft) => {
      const src: OrderSyncSource = new OrderSyncSource();
      src.id = o.id;
      src.elderlyAccountId = o.elderlyAccountId ? o.elderlyAccountId : '';
      src.managedByChildAccountId = o.managedByChildAccountId ? o.managedByChildAccountId : '';
      src.createdAt = o.createdAt;
      src.productName = o.product.name;
      src.productId = o.product.id;
      src.platform = o.product.platform;
      src.price = o.product.price;
      src.quantity = o.quantity;
      src.totalPrice = o.totalPrice;
      src.addressId = o.address.id;
      src.addressReceiver = o.address.receiver;
      src.addressPhone = o.address.phone;
      src.addressDetail = o.address.detail;
      src.paymentMethod = o.paymentMethod;
      src.paymentStatus = o.paymentStatus;
      src.imageUrl = o.product.imageUrl ? o.product.imageUrl : '';
      return src;
    });
    this.dataObject['ordersJson'] = JSON.stringify(items);
    const currentVersion: number = this.dataObject['ordersVersion'] as number;
    this.dataObject['ordersVersion'] = currentVersion + 1;
    hilog.info(DOMAIN, TAG, 'DistributedDataSync syncOrders count=%{public}d', items.length);
  }

  onPaymentChange(listener: DataChangeListener): void {
    this.paymentListeners.push(listener);
  }

  onReminderChange(listener: DataChangeListener): void {
    this.reminderListeners.push(listener);
  }

  offPaymentChange(listener: DataChangeListener): void {
    const idx: number = this.paymentListeners.indexOf(listener);
    if (idx >= 0) {
      this.paymentListeners.splice(idx, 1);
    }
  }

  offReminderChange(listener: DataChangeListener): void {
    const idx: number = this.reminderListeners.indexOf(listener);
    if (idx >= 0) {
      this.reminderListeners.splice(idx, 1);
    }
  }

  onOrderChange(listener: DataChangeListener): void {
    this.orderListeners.push(listener);
  }

  offOrderChange(listener: DataChangeListener): void {
    const idx: number = this.orderListeners.indexOf(listener);
    if (idx >= 0) {
      this.orderListeners.splice(idx, 1);
    }
  }

  getPaymentPayload(): PaymentSyncPayload | null {
    if (!this.dataObject) {
      return null;
    }
    const raw: string = this.dataObject['paymentJson'] as string;
    if (raw.length === 0) {
      return null;
    }
    try {
      return JSON.parse(raw) as PaymentSyncPayload;
    } catch (error) {
      return null;
    }
  }

  getRemindersFromSync(): ReminderRecord[] {
    if (!this.dataObject) {
      return [];
    }
    const raw: string = this.dataObject['remindersJson'] as string;
    if (raw.length === 0) {
      return [];
    }
    try {
      const items: ReminderSyncSource[] = JSON.parse(raw) as ReminderSyncSource[];
      return items.map((src: ReminderSyncSource): ReminderRecord => ({
        id: src.id,
        orderId: src.orderId,
        elderlyAccountId: src.elderlyAccountId.length > 0 ? src.elderlyAccountId : undefined,
        childAccountId: src.childAccountId.length > 0 ? src.childAccountId : undefined,
        title: src.title,
        content: src.content,
        createdAt: src.createdAt,
        read: src.read === 1
      }));
    } catch (error) {
      return [];
    }
  }

  getOrdersFromSync(): OrderDraft[] {
    if (!this.dataObject) {
      return [];
    }
    const raw: string = this.dataObject['ordersJson'] as string;
    if (raw.length === 0) {
      return [];
    }
    try {
      const items: OrderSyncSource[] = JSON.parse(raw) as OrderSyncSource[];
      return items.map((src: OrderSyncSource): OrderDraft => ({
        id: src.id,
        elderlyAccountId: src.elderlyAccountId.length > 0 ? src.elderlyAccountId : undefined,
        managedByChildAccountId: src.managedByChildAccountId.length > 0 ? src.managedByChildAccountId : undefined,
        createdAt: src.createdAt,
        product: {
          id: src.productId,
          platform: src.platform,
          name: src.productName,
          price: src.price,
          rating: 0,
          sales: 0,
          shopName: '',
          description: '',
          tags: [],
          recommendScore: 0,
          imageUrl: src.imageUrl.length > 0 ? src.imageUrl : undefined
        },
        quantity: src.quantity,
        address: {
          id: src.addressId,
          receiver: src.addressReceiver,
          phone: src.addressPhone,
          detail: src.addressDetail,
          isDefault: false
        },
        totalPrice: src.totalPrice,
        paymentMethod: src.paymentMethod as PaymentMethod,
        paymentStatus: src.paymentStatus as PaymentStatus
      }));
    } catch (error) {
      return [];
    }
  }

  private onDataChanged(sessionId: string, fields: Array<string>): void {
    if (!this.dataObject) {
      return;
    }
    const hasPaymentChange: boolean = fields.indexOf('paymentJson') >= 0;
    if (hasPaymentChange) {
      hilog.info(DOMAIN, TAG, 'DistributedDataSync payment changed');
      for (let i = 0; i < this.paymentListeners.length; i += 1) {
        this.paymentListeners[i](sessionId, fields);
      }
    }
    const hasReminderChange: boolean = fields.indexOf('remindersJson') >= 0 || fields.indexOf('remindersVersion') >= 0;
    if (hasReminderChange) {
      hilog.info(DOMAIN, TAG, 'DistributedDataSync reminders changed');
      this.mergeRemindersFromRemote();
      for (let i = 0; i < this.reminderListeners.length; i += 1) {
        this.reminderListeners[i](sessionId, fields);
      }
    }
    const hasOrderChange: boolean = fields.indexOf('ordersJson') >= 0 || fields.indexOf('ordersVersion') >= 0;
    if (hasOrderChange) {
      hilog.info(DOMAIN, TAG, 'DistributedDataSync orders changed');
      this.mergeOrdersFromRemote();
      for (let i = 0; i < this.orderListeners.length; i += 1) {
        this.orderListeners[i](sessionId, fields);
      }
    }
  }

  private mergeRemindersFromRemote(): void {
    const remoteReminders: ReminderRecord[] = this.getRemindersFromSync();
    if (remoteReminders.length === 0) {
      return;
    }
    ReminderService.mergeReminders(remoteReminders);
    hilog.info(DOMAIN, TAG, 'DistributedDataSync merged %{public}d remote reminders', remoteReminders.length);
  }

  private mergeOrdersFromRemote(): void {
    const remoteOrders: OrderDraft[] = this.getOrdersFromSync();
    if (remoteOrders.length === 0) {
      return;
    }
    OrderService.mergeOrders(remoteOrders);
    hilog.info(DOMAIN, TAG, 'DistributedDataSync merged %{public}d remote orders', remoteOrders.length);
  }

  static nowText(): string {
    const d = new Date();
    return d.getFullYear().toString() + '-' +
      (d.getMonth() + 1).toString().padStart(2, '0') + '-' +
      d.getDate().toString().padStart(2, '0') + ' ' +
      d.getHours().toString().padStart(2, '0') + ':' +
      d.getMinutes().toString().padStart(2, '0') + ':' +
      d.getSeconds().toString().padStart(2, '0');
  }
}
