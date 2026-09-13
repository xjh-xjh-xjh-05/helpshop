import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ReminderRecord } from '../models/ShoppingModels';

const TAG: string = 'ReminderStore';
const DOMAIN: number = 0x0001;
const STORE_NAME: string = 'helpshop_reminders';
const KEY_REMINDERS: string = 'reminders_json';

export class ReminderStore {
  private static instance: preferences.Preferences | null = null;

  static async init(context: common.UIAbilityContext): Promise<void> {
    try {
      ReminderStore.instance = await preferences.getPreferences(context, STORE_NAME);
      hilog.info(DOMAIN, TAG, 'ReminderStore init success');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'ReminderStore init failed');
    }
  }

  static async saveReminders(reminders: ReminderRecord[]): Promise<void> {
    if (!ReminderStore.instance) {
      hilog.warn(DOMAIN, TAG, 'ReminderStore not initialized, skip save');
      return;
    }
    try {
      const jsonStr: string = JSON.stringify(reminders);
      await ReminderStore.instance.put(KEY_REMINDERS, jsonStr);
      await ReminderStore.instance.flush();
      hilog.info(DOMAIN, TAG, 'ReminderStore saveReminders count=' + reminders.length.toString());
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'ReminderStore saveReminders failed');
    }
  }

  static loadReminders(): ReminderRecord[] {
    if (!ReminderStore.instance) {
      hilog.warn(DOMAIN, TAG, 'ReminderStore not initialized, return empty');
      return [];
    }
    try {
      const jsonStr: string = ReminderStore.instance.getSync(KEY_REMINDERS, '') as string;
      if (jsonStr.length === 0) {
        return [];
      }
      const parsed: ReminderRecord[] = JSON.parse(jsonStr) as ReminderRecord[];
      hilog.info(DOMAIN, TAG, 'ReminderStore loadReminders count=' + parsed.length.toString());
      return parsed;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'ReminderStore loadReminders failed, return empty');
      return [];
    }
  }

  static async clear(): Promise<void> {
    if (!ReminderStore.instance) {
      return;
    }
    try {
      await ReminderStore.instance.clear();
      await ReminderStore.instance.flush();
      hilog.info(DOMAIN, TAG, 'ReminderStore cleared');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'ReminderStore clear failed');
    }
  }
}
