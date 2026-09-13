import {
  AgentIntent,
  ConversationContext,
  emptyAgentIntent,
  emptySkillResultData,
  emptyToolResult,
  IntentType,
  Skill,
  SkillResult,
  Tool,
  ToolParameter,
  ToolResult
} from './AgentModels';
import { ShoppingCompareSkill } from './ShoppingCompareSkill';
import { ProductSearchSkill } from './ProductSearchSkill';
import { OrderConfirmSkill } from './OrderConfirmSkill';
import { PaymentSkill } from './PaymentSkill';
import { VoiceInputSkill } from './VoiceInputSkill';
import { AdminDashboardSkill } from './AdminDashboardSkill';
import { CustomerServiceSkill } from './CustomerServiceSkill';
import { OrderQuerySkill } from './OrderQuerySkill';
import { AddressManageSkill } from './AddressManageSkill';
import { ReminderManageSkill } from './ReminderManageSkill';
import { FamilyBindSkill } from './FamilyBindSkill';

interface SkillToolAdapter extends Tool {
  skill: Skill;
}

class SkillToolWrapper implements SkillToolAdapter {
  name: string = '';
  description: string = '';
  parameters: ToolParameter[] = [];
  skill: Skill;

  constructor(skill: Skill, toolName: string, description: string, parameters: ToolParameter[]) {
    this.skill = skill;
    this.name = toolName;
    this.description = description;
    this.parameters = parameters;
  }

  canHandle(intent: AgentIntent): boolean {
    return this.skill.canHandle(intent);
  }

  execute(intent: AgentIntent, context: ConversationContext): SkillResult {
    return this.skill.execute(intent, context);
  }

  executeWithArgs(args: Record<string, string>, context: ConversationContext): ToolResult {
    const intent: AgentIntent = this.argsToIntent(args, context);
    const result: SkillResult = this.skill.execute(intent, context);
    return {
      success: result.success,
      data: JSON.stringify(result.data),
      message: result.message
    };
  }

  private argsToIntent(args: Record<string, string>, context: ConversationContext): AgentIntent {
    const intent: AgentIntent = emptyAgentIntent();
    intent.rawText = args.query ? args.query : (args.keyword ? args.keyword : '');
    intent.product = args.keyword ? args.keyword : (args.query ? args.query : '');
    intent.quantity = args.quantity ? parseInt(args.quantity, 10) : 1;
    if (isNaN(intent.quantity) || intent.quantity < 1) {
      intent.quantity = 1;
    }
    intent.confidence = 0.8;
    intent.type = this.inferIntentType();
    if (context.pendingIntent.product.length > 0 && intent.product.length === 0) {
      intent.product = context.pendingIntent.product;
    }
    return intent;
  }

  private inferIntentType(): IntentType {
    if (this.name === 'search_product') { return IntentType.Search; }
    if (this.name === 'compare_product') { return IntentType.Compare; }
    if (this.name === 'confirm_order') { return IntentType.OrderConfirm; }
    if (this.name === 'prepare_payment') { return IntentType.Pay; }
    if (this.name === 'query_order') { return IntentType.OrderQuery; }
    if (this.name === 'manage_address') { return IntentType.AddressManage; }
    if (this.name === 'set_reminder') { return IntentType.ReminderManage; }
    if (this.name === 'bind_family') { return IntentType.FamilyBind; }
    if (this.name === 'query_admin') { return IntentType.AdminQuery; }
    if (this.name === 'query_cs') { return IntentType.CSAsk; }
    return IntentType.Unknown;
  }
}

export class ToolRegistry {
  private static tools: Tool[] = [];
  private static initialized: boolean = false;

  static ensureInitialized(): void {
    if (ToolRegistry.initialized) {
      return;
    }
    ToolRegistry.initialized = true;

    ToolRegistry.tools.push(new SkillToolWrapper(
      new ProductSearchSkill(), 'search_product', '搜索商品：根据关键词搜索商品列表',
      [{ name: 'keyword', type: 'string', description: '商品关键词', required: true }]
    ));

    ToolRegistry.tools.push(new SkillToolWrapper(
      new ShoppingCompareSkill(), 'compare_product', '比价推荐：按需求进行商品比价和推荐',
      [{ name: 'query', type: 'string', description: '购物需求描述', required: true }]
    ));

    ToolRegistry.tools.push(new SkillToolWrapper(
      new OrderConfirmSkill(), 'confirm_order', '确认下单：生成订单预览',
      [
        { name: 'productId', type: 'string', description: '商品ID', required: false },
        { name: 'quantity', type: 'number', description: '数量', required: false }
      ]
    ));

    ToolRegistry.tools.push(new SkillToolWrapper(
      new PaymentSkill(), 'prepare_payment', '准备支付：检测支付方式和地址',
      [
        { name: 'productId', type: 'string', description: '商品ID', required: false },
        { name: 'quantity', type: 'number', description: '数量', required: false }
      ]
    ));

    ToolRegistry.tools.push(new SkillToolWrapper(
      new OrderQuerySkill(), 'query_order', '查询订单：查看我的订单列表',
      []
    ));

    ToolRegistry.tools.push(new SkillToolWrapper(
      new AddressManageSkill(), 'manage_address', '管理地址：查看、添加、设置默认、删除收货地址',
      [
        { name: 'action', type: 'string', description: '操作类型：list/add/setDefault/delete', required: true },
        { name: 'id', type: 'string', description: '地址ID（setDefault/delete时需要）', required: false },
        { name: 'receiver', type: 'string', description: '收货人（add时需要）', required: false },
        { name: 'phone', type: 'string', description: '电话（add时需要）', required: false },
        { name: 'detail', type: 'string', description: '详细地址（add时需要）', required: false }
      ]
    ));

    ToolRegistry.tools.push(new SkillToolWrapper(
      new ReminderManageSkill(), 'set_reminder', '设置提醒：查看提醒列表或标记已读',
      [{ name: 'action', type: 'string', description: '操作类型：list/markRead', required: true }]
    ));

    ToolRegistry.tools.push(new SkillToolWrapper(
      new FamilyBindSkill(), 'bind_family', '绑定家人：查看绑定关系或通过绑定码绑定老人',
      [
        { name: 'action', type: 'string', description: '操作类型：list/bind', required: true },
        { name: 'keyword', type: 'string', description: '绑定码（bind时需要）', required: false }
      ]
    ));

    ToolRegistry.tools.push(new SkillToolWrapper(
      new AdminDashboardSkill(), 'query_admin', '管理员查询：查看平台统计、用户列表、审计日志等',
      [{ name: 'query', type: 'string', description: '查询内容描述', required: true }]
    ));

    ToolRegistry.tools.push(new SkillToolWrapper(
      new CustomerServiceSkill(), 'query_cs', '客服查询：查看工单、退款、投诉等',
      [{ name: 'query', type: 'string', description: '查询内容描述', required: true }]
    ));
  }

  static findTool(name: string): Tool | undefined {
    ToolRegistry.ensureInitialized();
    for (let i = 0; i < ToolRegistry.tools.length; i += 1) {
      if (ToolRegistry.tools[i].name === name) {
        return ToolRegistry.tools[i];
      }
    }
    return undefined;
  }

  static executeToolByName(name: string, args: Record<string, string>, context: ConversationContext): ToolResult {
    ToolRegistry.ensureInitialized();
    const tool: Tool | undefined = ToolRegistry.findTool(name);
    if (!tool) {
      return {
        success: false,
        data: '',
        message: '工具 ' + name + ' 不存在'
      };
    }
    try {
      return tool.executeWithArgs(args, context);
    } catch (error) {
      return {
        success: false,
        data: '',
        message: '工具 ' + name + ' 执行异常'
      };
    }
  }

  static getToolDescriptions(): string {
    ToolRegistry.ensureInitialized();
    const parts: string[] = [];
    for (let i = 0; i < ToolRegistry.tools.length; i += 1) {
      const tool: Tool = ToolRegistry.tools[i];
      const paramParts: string[] = [];
      for (let j = 0; j < tool.parameters.length; j += 1) {
        const p: ToolParameter = tool.parameters[j];
        paramParts.push(p.name + '(' + (p.required ? '必填' : '可选') + ')');
      }
      const paramStr: string = paramParts.length > 0 ? ' 参数：' + paramParts.join(', ') : '';
      parts.push('- ' + tool.name + ': ' + tool.description + paramStr);
    }
    return parts.join('\n');
  }

  static listTools(): Tool[] {
    ToolRegistry.ensureInitialized();
    return ToolRegistry.tools.slice();
  }

  static findToolForIntent(intent: AgentIntent): Tool | undefined {
    ToolRegistry.ensureInitialized();
    for (let i = 0; i < ToolRegistry.tools.length; i += 1) {
      if (ToolRegistry.tools[i].canHandle(intent)) {
        return ToolRegistry.tools[i];
      }
    }
    return undefined;
  }

  static reset(): void {
    ToolRegistry.tools = [];
    ToolRegistry.initialized = false;
  }
}
