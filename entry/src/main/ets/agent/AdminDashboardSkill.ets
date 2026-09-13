import {
  AgentIntent,
  ConversationContext,
  emptySkillResultData,
  IntentType,
  Skill,
  SkillResult
} from './AgentModels';
import { AdminDashboardBackendData } from '../models/BackendModels';
import { AppBackendService } from '../services/AppBackendService';

export class AdminDashboardSkill implements Skill {
  name: string = 'admin_dashboard';
  description: string = '管理员查询：查看用户统计、订单总览、系统数据';

  canHandle(intent: AgentIntent): boolean {
    return intent.type === IntentType.AdminQuery;
  }

  execute(intent: AgentIntent, context: ConversationContext): SkillResult {
    const data = emptySkillResultData();
    try {
      const dashboard: AdminDashboardBackendData = AppBackendService.getAdminDashboard().data
        ? AppBackendService.getAdminDashboard().data!
        : { totalAccounts: 0, elderlyCount: 0, childCount: 0, csCount: 0, adminCount: 0, totalOrders: 0, pendingOrders: 0, deletedCount: 0, recentAuditLogs: [] };

      const summary: string = '平台共 ' + dashboard.totalAccounts.toString() +
        ' 位用户（老人 ' + dashboard.elderlyCount.toString() +
        '、子女 ' + dashboard.childCount.toString() +
        '、客服 ' + dashboard.csCount.toString() +
        '、管理员 ' + dashboard.adminCount.toString() +
        '），累计 ' + dashboard.totalOrders.toString() +
        ' 笔订单，待处理 ' + dashboard.pendingOrders.toString() + ' 笔。';

      const payload: Record<string, Object> = {
        'dashboard': dashboard as Object,
        'summary': summary
      };
      data.payload = payload;

      return {
        success: true,
        data: data,
        message: summary,
        fallbackUsed: false
      };
    } catch (error) {
      return {
        success: false,
        data: data,
        message: '管理数据查询异常，请稍后重试。',
        fallbackUsed: true
      };
    }
  }
}
