import {
  AgentIntent,
  ConversationContext,
  emptySkillResultData,
  IntentType,
  Skill,
  SkillResult
} from './AgentModels';
import { CustomerServiceDashboardBackendData } from '../models/BackendModels';
import { AppBackendService } from '../services/AppBackendService';

export class CustomerServiceSkill implements Skill {
  name: string = 'customer_service';
  description: string = '客服问答：工单查询、订单问题排查、老人咨询协助';

  canHandle(intent: AgentIntent): boolean {
    return intent.type === IntentType.CSAsk;
  }

  execute(intent: AgentIntent, context: ConversationContext): SkillResult {
    const data = emptySkillResultData();
    try {
      const dashboard: CustomerServiceDashboardBackendData = AppBackendService.getCsDashboard().data
        ? AppBackendService.getCsDashboard().data!
        : { openTickets: 0, resolvedToday: 0, pendingTickets: [] };

      const summary: string = '当前 ' + dashboard.openTickets.toString() +
        ' 个待处理工单，今日已解决 ' + dashboard.resolvedToday.toString() + ' 个。' +
        (dashboard.openTickets > 0 ? '建议优先处理紧急工单。' : '暂无积压工单。');

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
        message: '客服数据查询异常，请稍后重试。',
        fallbackUsed: true
      };
    }
  }
}
