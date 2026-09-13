import {
  AgentIntent,
  ConversationContext,
  emptySkillResultData,
  IntentType,
  Skill,
  SkillResult
} from './AgentModels';
import { OrderDraft } from '../models/ShoppingModels';
import { OrderService } from '../services/OrderService';
import { OrderFacadeService } from '../services/OrderFacadeService';

export class OrderQuerySkill implements Skill {
  name: string = 'order_query';
  description: string = '订单查询：查看我的订单列表和物流状态';

  canHandle(intent: AgentIntent): boolean {
    return intent.type === IntentType.OrderQuery;
  }

  execute(intent: AgentIntent, context: ConversationContext): SkillResult {
    const data = emptySkillResultData();
    try {
      const orders: OrderDraft[] = OrderService.listOrders();
      if (orders.length === 0) {
        return {
          success: true,
          data: data,
          message: '您目前还没有订单。想要买点什么吗？我帮您搜索和比价。',
          fallbackUsed: false
        };
      }
      const summary: string = OrderQuerySkill.buildOrderSummary(orders);
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
        message: '订单查询暂时不可用，请稍后再试。',
        fallbackUsed: true
      };
    }
  }

  private static buildOrderSummary(orders: OrderDraft[]): string {
    const count: number = orders.length;
    let msg: string = '您共有 ' + count.toString() + ' 笔订单：\n';
    const showCount: number = Math.min(5, count);
    for (let i = 0; i < showCount; i += 1) {
      const order: OrderDraft = orders[i];
      const statusText: string = OrderQuerySkill.paymentStatusText(order.paymentStatus);
      msg += (i + 1).toString() + '. ' + order.product.name + ' x' + order.quantity.toString() +
        ' ￥' + order.totalPrice.toString() + ' ' + statusText + '\n';
    }
    if (count > showCount) {
      msg += '...还有 ' + (count - showCount).toString() + ' 笔订单';
    }
    return msg.trimEnd();
  }

  private static paymentStatusText(status: string): string {
    if (status === 'success') { return '已支付'; }
    if (status === 'pending') { return '待支付'; }
    if (status === 'failed') { return '支付失败'; }
    if (status === 'cancelled') { return '已取消'; }
    return status;
  }
}
