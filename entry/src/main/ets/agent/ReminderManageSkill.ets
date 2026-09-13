import {
  AgentIntent,
  ConversationContext,
  emptySkillResultData,
  IntentType,
  Skill,
  SkillResult
} from './AgentModels';
import { ReminderRecord } from '../models/ShoppingModels';
import { ReminderService } from '../services/ReminderService';

export class ReminderManageSkill implements Skill {
  name: string = 'reminder_manage';
  description: string = '提醒管理：查看提醒列表或标记全部已读';

  canHandle(intent: AgentIntent): boolean {
    return intent.type === IntentType.ReminderManage;
  }

  execute(intent: AgentIntent, context: ConversationContext): SkillResult {
    const data = emptySkillResultData();
    try {
      const action: string = ReminderManageSkill.detectAction(intent.rawText);
      if (action === 'markRead') {
        return ReminderManageSkill.handleMarkRead();
      }
      return ReminderManageSkill.handleList();
    } catch (error) {
      return {
        success: false,
        data: emptySkillResultData(),
        message: '提醒服务暂时不可用，请稍后再试。',
        fallbackUsed: true
      };
    }
  }

  private static detectAction(text: string): string {
    if (text.indexOf('已读') >= 0 || text.indexOf('标记') >= 0 || text.indexOf('全部已读') >= 0) {
      return 'markRead';
    }
    return 'list';
  }

  private static handleList(): SkillResult {
    const data = emptySkillResultData();
    const reminders: ReminderRecord[] = ReminderService.listReminders();
    if (reminders.length === 0) {
      return {
        success: true,
        data: data,
        message: '您目前没有提醒消息。',
        fallbackUsed: false
      };
    }
    const unreadCount: number = reminders.filter((r: ReminderRecord) => !r.read).length;
    const msg: string = ReminderManageSkill.buildReminderList(reminders, unreadCount);
    return {
      success: true,
      data: data,
      message: msg,
      fallbackUsed: false
    };
  }

  private static handleMarkRead(): SkillResult {
    const data = emptySkillResultData();
    const reminders: ReminderRecord[] = ReminderService.markAllRead();
    return {
      success: true,
      data: data,
      message: '已将 ' + reminders.length.toString() + ' 条提醒全部标记为已读。',
      fallbackUsed: false
    };
  }

  private static buildReminderList(reminders: ReminderRecord[], unreadCount: number): string {
    let msg: string = '您有 ' + unreadCount.toString() + ' 条未读提醒（共 ' + reminders.length.toString() + ' 条）：\n';
    const showCount: number = Math.min(5, reminders.length);
    for (let i = 0; i < showCount; i += 1) {
      const r: ReminderRecord = reminders[i];
      const readTag: string = r.read ? '' : ' [新]';
      msg += (i + 1).toString() + '. ' + r.title + readTag + '\n';
    }
    if (unreadCount > 0) {
      msg += '说"标记已读"可以全部标记为已读。';
    }
    return msg.trimEnd();
  }
}
