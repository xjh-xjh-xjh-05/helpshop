import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { OrderDraft } from '../models/ShoppingModels';

const TAG: string = 'OrderStore';
const DOMAIN: number = 0x0001;
const STORE_NAME: string = 'helpshop_orders';
const KEY_ORDERS: string = 'orders_json';

export class OrderStore {
  private static instance: preferences.Preferences | null = null;

  static async init(context: common.UIAbilityContext): Promise<void> {
    try {
      OrderStore.instance = await preferences.getPreferences(context, STORE_NAME);
      hilog.info(DOMAIN, TAG, 'OrderStore init success');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'OrderStore init failed');
    }
  }

  static async saveOrders(orders: OrderDraft[]): Promise<void> {
    if (!OrderStore.instance) {
      hilog.warn(DOMAIN, TAG, 'OrderStore not initialized, skip save');
      return;
    }
    try {
      const jsonStr: string = JSON.stringify(orders);
      await OrderStore.instance.put(KEY_ORDERS, jsonStr);
      await OrderStore.instance.flush();
      hilog.info(DOMAIN, TAG, 'OrderStore saveOrders count=' + orders.length.toString());
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'OrderStore saveOrders failed');
    }
  }

  static loadOrders(): OrderDraft[] {
    if (!OrderStore.instance) {
      hilog.warn(DOMAIN, TAG, 'OrderStore not initialized, return empty');
      return [];
    }
    try {
      const jsonStr: string = OrderStore.instance.getSync(KEY_ORDERS, '') as string;
      if (jsonStr.length === 0) {
        return [];
      }
      const parsed: OrderDraft[] = JSON.parse(jsonStr) as OrderDraft[];
      hilog.info(DOMAIN, TAG, 'OrderStore loadOrders count=' + parsed.length.toString());
      return parsed;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'OrderStore loadOrders failed, return empty');
      return [];
    }
  }

  static async clear(): Promise<void> {
    if (!OrderStore.instance) {
      return;
    }
    try {
      await OrderStore.instance.clear();
      await OrderStore.instance.flush();
      hilog.info(DOMAIN, TAG, 'OrderStore cleared');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'OrderStore clear failed');
    }
  }
}
