import { OrderDraft, ReminderRecord } from '../models/ShoppingModels';
import { AuthService } from './AuthService';
import { OrderService } from './OrderService';
import { CloneUtils } from '../utils/CloneUtils';
import { ReminderStore } from './ReminderStore';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'ReminderService';
const DOMAIN: number = 0x0001;

export class ReminderService {
  private static reminders: ReminderRecord[] | null = null;

  private static ensureLoaded(): void {
    if (ReminderService.reminders === null) {
      ReminderService.reminders = ReminderStore.loadReminders();
      hilog.info(DOMAIN, TAG, 'ReminderService loaded from store, count=' + (ReminderService.reminders?.length ?? 0).toString());
    }
  }

  private static persist(): void {
    if (ReminderService.reminders !== null) {
      ReminderStore.saveReminders(ReminderService.reminders);
    }
  }

  static createShoppingReminder(order: OrderDraft): ReminderRecord {
    ReminderService.ensureLoaded();
    const childAccountId = order.managedByChildAccountId ? order.managedByChildAccountId : AuthService.getCurrentChildAccountId();
    const operatorText = childAccountId && childAccountId.length > 0
      ? AuthService.getAccountName(childAccountId) + ' 已为老人代买'
      : '老人已完成购买';
    const reminder: ReminderRecord = {
      id: 'reminder-' + Date.now().toString(),
      orderId: order.id,
      elderlyAccountId: order.elderlyAccountId,
      childAccountId: childAccountId,
      title: '老人购物提醒',
      content: operatorText + '：' + order.address.receiver + ' 在 ' + order.product.platform + ' 购买了 ' + order.product.name + '，数量 ' + order.quantity.toString() + '，金额 ¥' + order.totalPrice.toFixed(2) + '，支付方式：' + OrderService.paymentMethodName(order.paymentMethod) + '。',
      createdAt: order.createdAt,
      read: false
    };
    ReminderService.reminders!.unshift(reminder);
    ReminderService.persist();
    return CloneUtils.cloneReminder(reminder);
  }

  static listReminders(): ReminderRecord[] {
    ReminderService.ensureLoaded();
    const elderlyAccountId = AuthService.getCurrentElderlyAccountId();
    const childAccountId = AuthService.getCurrentChildAccountId();
    return ReminderService.reminders!.filter((item: ReminderRecord) => {
      return item.elderlyAccountId === elderlyAccountId || item.childAccountId === childAccountId;
    }).map((item: ReminderRecord) => CloneUtils.cloneReminder(item));
  }

  static listAllReminders(): ReminderRecord[] {
    ReminderService.ensureLoaded();
    return ReminderService.reminders!.map((item: ReminderRecord) => CloneUtils.cloneReminder(item));
  }

  static markAllRead(): ReminderRecord[] {
    ReminderService.ensureLoaded();
    const elderlyAccountId = AuthService.getCurrentElderlyAccountId();
    const childAccountId = AuthService.getCurrentChildAccountId();
    ReminderService.reminders!.forEach((item: ReminderRecord) => {
      if (item.elderlyAccountId === elderlyAccountId || item.childAccountId === childAccountId) {
        item.read = true;
      }
    });
    ReminderService.persist();
    return ReminderService.listReminders();
  }

  static countCurrentReminders(): number {
    return ReminderService.listReminders().length;
  }

  static countCurrentUnreadReminders(): number {
    return ReminderService.listReminders().filter((item: ReminderRecord) => !item.read).length;
  }

  static clearReminders(): void {
    ReminderService.reminders = [];
    ReminderService.persist();
  }

  static mergeReminders(remoteReminders: ReminderRecord[]): void {
    if (remoteReminders.length === 0) {
      return;
    }
    ReminderService.ensureLoaded();
    const existingIds: Set<string> = new Set(ReminderService.reminders!.map((r: ReminderRecord) => r.id));
    let changed: boolean = false;
    for (let i = 0; i < remoteReminders.length; i += 1) {
      const remote: ReminderRecord = remoteReminders[i];
      if (!existingIds.has(remote.id)) {
        ReminderService.reminders!.unshift(CloneUtils.cloneReminder(remote));
        changed = true;
      }
    }
    if (changed) {
      ReminderService.persist();
      hilog.info(DOMAIN, TAG, 'ReminderService merged reminders, total=' + ReminderService.reminders!.length.toString());
    }
  }
}
