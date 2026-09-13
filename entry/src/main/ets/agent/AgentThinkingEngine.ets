import {
  AgentIntent,
  ConversationContext,
  emptyAgentIntent,
  emptyThinkingChain,
  emptyThinkingStep,
  emptyToolResult,
  IntentType,
  ThinkingChain,
  ThinkingStep,
  ToolResult
} from './AgentModels';
import { LLMMessage, LLMService } from '../services/LLMService';
import { CopilotConfig } from '../config/AppConfig';
import { ToolRegistry } from './ToolRegistry';
import { IntentEngine } from './IntentEngine';
import { ConversationManager } from './ConversationManager';
import { TimeUtils } from '../utils/TimeUtils';

interface LLMToolCall {
  toolName: string;
  args: Record<string, string>;
  thought: string;
  isFinal: boolean;
  directReply: string;
}

export class AgentThinkingEngine {
  private static readonly MAX_STEPS: number = 6;
  private static readonly SYSTEM_PROMPT: string =
    '你是 HelpShop 银发购物助手的推理引擎。你可以调用以下工具来帮助老人完成购物：\n' +
    '- search_product(keyword): 搜索商品，keyword为搜索关键词\n' +
    '- compare_product(query): 比价推荐，query为购物需求描述\n' +
    '- confirm_order(productId, quantity): 确认下单\n' +
    '- prepare_payment(productId, quantity): 准备支付\n' +
    '- query_order(): 查询我的订单\n' +
    '- manage_address(action, id?, receiver?, phone?, detail?): 管理地址，action为list/add/setDefault/delete\n' +
    '- set_reminder(action): 设置提醒，action为list/markRead\n' +
    '- bind_family(action, keyword?): 绑定家人，action为list/bind\n' +
    '- query_admin(query): 管理员数据查询\n' +
    '- query_cs(query): 客服工单查询\n\n' +
    '请严格按以下JSON格式输出，不要输出任何其他文字：\n' +
    '{"thought":"你的分析和推理","toolCall":{"toolName":"工具名","args":{"参数名":"参数值"}},"isFinal":false}\n' +
    '如果不需调用工具，直接回复用户：\n' +
    '{"thought":"你的分析","directReply":"直接回复用户的文字","isFinal":true}\n\n' +
    '规则：1.每次只调用一个工具 2.观察工具结果后再决定下一步 3.最多6步必须给出最终回复 4.对老人用语要简洁温和';

  static isLLMAvailable(): boolean {
    return CopilotConfig.apiKey.trim().length > 0 &&
      CopilotConfig.baseUrl.trim().length > 0 &&
      CopilotConfig.model.trim().length > 0;
  }

  static async processWithThinking(
    input: string,
    context: ConversationContext,
    voiceContext?: AgentIntent
  ): Promise<ThinkingChain> {
    if (!AgentThinkingEngine.isLLMAvailable()) {
      return AgentThinkingEngine.fallbackChain(input);
    }

    const chain: ThinkingChain = emptyThinkingChain();
    const observation: string = AgentThinkingEngine.buildObservation(input, context);

    const observeStep: ThinkingStep = AgentThinkingEngine.createStep('observe', observation, '', {}, emptyToolResult(), false);
    chain.steps.push(observeStep);

    for (let i = 0; i < AgentThinkingEngine.MAX_STEPS; i += 1) {
      try {
        const toolCall: LLMToolCall = await AgentThinkingEngine.callLLMThink(chain);
        chain.llmCallsUsed += 1;

        const thinkStep: ThinkingStep = AgentThinkingEngine.createStep(
          'think',
          toolCall.thought,
          '',
          {},
          emptyToolResult(),
          false
        );
        chain.steps.push(thinkStep);

        if (toolCall.isFinal && toolCall.directReply.length > 0) {
          chain.finalResponse = toolCall.directReply;
          chain.totalSteps = chain.steps.length;
          return chain;
        }

        if (toolCall.toolName.length > 0) {
          const toolResult: ToolResult = ToolRegistry.executeToolByName(
            toolCall.toolName,
            toolCall.args,
            context
          );
          chain.toolsUsed.push(toolCall.toolName);

          const actStep: ThinkingStep = AgentThinkingEngine.createStep(
            'act',
            toolResult.message,
            toolCall.toolName,
            toolCall.args,
            toolResult,
            false
          );
          chain.steps.push(actStep);
        }
      } catch (error) {
        const reflectStep: ThinkingStep = AgentThinkingEngine.createStep(
          'reflect',
          'LLM推理异常，准备降级',
          '', {}, emptyToolResult(), false
        );
        chain.steps.push(reflectStep);
        chain.finalResponse = AgentThinkingEngine.generateFallbackResponse(input);
        chain.totalSteps = chain.steps.length;
        return chain;
      }
    }

    if (chain.finalResponse.length === 0) {
      chain.finalResponse = AgentThinkingEngine.generateFallbackResponse(input);
    }
    chain.totalSteps = chain.steps.length;
    return chain;
  }

  static async parseIntentWithLLM(text: string, context: ConversationContext): Promise<AgentIntent> {
    if (!AgentThinkingEngine.isLLMAvailable()) {
      return IntentEngine.parse(text, context);
    }

    const ruleIntent: AgentIntent = IntentEngine.parse(text, context);
    if (ruleIntent.confidence >= 0.6 && ruleIntent.type !== IntentType.Unknown) {
      return ruleIntent;
    }

    try {
      const toolDescriptions: string = ToolRegistry.getToolDescriptions();
      const userMsg: string =
        '请分析以下用户输入的意图，返回JSON格式：\n' +
        '{"type":"意图类型","product":"商品名","category":"分类","confidence":0.8}\n' +
        '意图类型可选：search,compare,order_confirm,pay,order_query,address_manage,reminder_manage,family_bind,admin_query,cs_ask,unknown\n\n' +
        '可用工具参考：\n' + toolDescriptions + '\n\n' +
        '用户输入："' + text + '"';

      const messages: LLMMessage[] = [
        new LLMMessage('system', '你是意图分析引擎，只输出JSON，不输出其他文字。'),
        new LLMMessage('user', userMsg)
      ];
      const llmResult: string = await LLMService.getInstance().chat(
        messages, 0.3, 128
      );
      if (llmResult.length === 0) {
        return ruleIntent;
      }
      const parsed: AgentIntent = AgentThinkingEngine.parseLLMIntent(llmResult, text);
      if (parsed.type !== IntentType.Unknown && parsed.confidence > ruleIntent.confidence) {
        parsed.rawText = text;
        return parsed;
      }
      return ruleIntent;
    } catch (error) {
      return ruleIntent;
    }
  }

  private static async callLLMThink(chain: ThinkingChain): Promise<LLMToolCall> {
    const messages: LLMMessage[] = [
      new LLMMessage('system', AgentThinkingEngine.SYSTEM_PROMPT)
    ];

    let lastRole: string = 'system';

    for (let i = 0; i < chain.steps.length; i += 1) {
      const step: ThinkingStep = chain.steps[i];
      if (step.type === 'observe') {
        messages.push(new LLMMessage('user', step.content));
        lastRole = 'user';
      } else if (step.type === 'act') {
        const resultText: string = step.toolName.length > 0
          ? '工具 ' + step.toolName + ' 的结果：' + step.result.message + '（数据：' + step.result.data + '）'
          : step.content;
        if (lastRole === 'user') {
          messages[messages.length - 1].content += '\n' + resultText;
        } else {
          messages.push(new LLMMessage('user', resultText));
          lastRole = 'user';
        }
      } else if (step.type === 'think') {
        const assistantContent: string = JSON.stringify({
          thought: step.content,
          isFinal: false
        });
        if (lastRole === 'assistant') {
          messages[messages.length - 1].content += '\n' + assistantContent;
        } else {
          messages.push(new LLMMessage('assistant', assistantContent));
          lastRole = 'assistant';
        }
      }
    }

    const llmResult: string = await LLMService.getInstance().chat(
      messages, 0.5, 512
    );
    return AgentThinkingEngine.parseToolCall(llmResult);
  }

  private static parseToolCall(llmOutput: string): LLMToolCall {
    const empty: LLMToolCall = {
      toolName: '',
      args: {},
      thought: 'LLM输出为空',
      isFinal: true,
      directReply: '抱歉，我暂时无法处理，请换个说法再试试。'
    };

    let jsonStr: string = llmOutput.trim();
    if (jsonStr.length === 0) {
      return empty;
    }

    const jsonStart: number = jsonStr.indexOf('{');
    const jsonEnd: number = jsonStr.lastIndexOf('}');
    if (jsonStart < 0 || jsonEnd < 0) {
      empty.directReply = jsonStr;
      empty.thought = 'LLM直接回复（非JSON格式）';
      return empty;
    }
    jsonStr = jsonStr.substring(jsonStart, jsonEnd + 1);

    try {
      const obj: Record<string, Object> = JSON.parse(jsonStr) as Record<string, Object>;
      const thought: string = obj.thought ? (obj.thought as string) : '';
      const isFinal: boolean = obj.isFinal === true;

      if (isFinal && obj.directReply) {
        return {
          toolName: '',
          args: {},
          thought: thought,
          isFinal: true,
          directReply: obj.directReply as string
        };
      }

      if (obj.toolCall) {
        const tc: Record<string, Object> = obj.toolCall as Record<string, Object>;
        const toolName: string = tc.toolName ? (tc.toolName as string) : '';
        const args: Record<string, string> = {};
        if (tc.args && typeof tc.args === 'object') {
          const argsObj: Record<string, Object> = tc.args as Record<string, Object>;
          const keys: string[] = Object.keys(argsObj);
          for (let i = 0; i < keys.length; i += 1) {
            args[keys[i]] = String(argsObj[keys[i]]);
          }
        }
        return {
          toolName: toolName,
          args: args,
          thought: thought,
          isFinal: false,
          directReply: ''
        };
      }

      if (!isFinal && thought.length > 0) {
        return {
          toolName: '',
          args: {},
          thought: thought,
          isFinal: true,
          directReply: thought
        };
      }

      return empty;
    } catch (error) {
      empty.directReply = llmOutput.trim();
      empty.thought = 'JSON解析失败，使用原始输出';
      return empty;
    }
  }

  private static parseLLMIntent(jsonStr: string, rawText: string): AgentIntent {
    const intent: AgentIntent = emptyAgentIntent();
    intent.rawText = rawText;
    try {
      const start: number = jsonStr.indexOf('{');
      const end: number = jsonStr.lastIndexOf('}');
      if (start < 0 || end < 0) {
        return intent;
      }
      const obj: Record<string, Object> = JSON.parse(jsonStr.substring(start, end + 1)) as Record<string, Object>;
      const typeStr: string = obj.type ? (obj.type as string) : 'unknown';
      intent.type = AgentThinkingEngine.mapIntentType(typeStr);
      intent.product = obj.product ? (obj.product as string) : '';
      intent.category = obj.category ? (obj.category as string) : '';
      intent.confidence = obj.confidence ? Number(obj.confidence) : 0.5;
      intent.needsSupplement = intent.confidence < 0.6;
    } catch (error) {
      intent.type = IntentType.Unknown;
      intent.confidence = 0;
    }
    return intent;
  }

  private static mapIntentType(typeStr: string): IntentType {
    if (typeStr === 'search') { return IntentType.Search; }
    if (typeStr === 'compare') { return IntentType.Compare; }
    if (typeStr === 'order_confirm') { return IntentType.OrderConfirm; }
    if (typeStr === 'pay') { return IntentType.Pay; }
    if (typeStr === 'order_query') { return IntentType.OrderQuery; }
    if (typeStr === 'address_manage') { return IntentType.AddressManage; }
    if (typeStr === 'reminder_manage') { return IntentType.ReminderManage; }
    if (typeStr === 'family_bind') { return IntentType.FamilyBind; }
    if (typeStr === 'admin_query') { return IntentType.AdminQuery; }
    if (typeStr === 'cs_ask') { return IntentType.CSAsk; }
    return IntentType.Unknown;
  }

  private static buildObservation(input: string, context: ConversationContext): string {
    let obs: string = '用户输入："' + input + '"';
    if (context.pendingIntent.product.length > 0) {
      obs += '\n之前讨论的商品：' + context.pendingIntent.product;
    }
    if (context.history.length > 0) {
      const recentCount: number = Math.min(4, context.history.length);
      const startIdx: number = context.history.length - recentCount;
      obs += '\n最近对话：';
      for (let i = startIdx; i < context.history.length; i += 1) {
        const turn = context.history[i];
        obs += '\n' + turn.role + '：' + turn.content.substring(0, 80);
      }
    }
    return obs;
  }

  private static fallbackChain(input: string): ThinkingChain {
    const chain: ThinkingChain = emptyThinkingChain();
    const step: ThinkingStep = AgentThinkingEngine.createStep(
      'observe', 'LLM不可用，使用规则引擎处理：' + input, '', {}, emptyToolResult(), true
    );
    chain.steps.push(step);
    chain.finalResponse = '';
    chain.totalSteps = 1;
    return chain;
  }

  private static generateFallbackResponse(input: string): string {
    if (input.length === 0) {
      return '请告诉我您想买什么？';
    }
    return '我来帮您处理"' + input + '"，请稍等。';
  }

  private static createStep(
    type: string, content: string, toolName: string,
    toolArgs: Record<string, string>, result: ToolResult, isFinal: boolean
  ): ThinkingStep {
    return {
      stepId: 'step-' + Date.now().toString() + '-' + Math.floor(Math.random() * 1000).toString(),
      type: type,
      content: content,
      toolName: toolName,
      toolArgs: toolArgs,
      result: result,
      isFinal: isFinal,
      timestamp: TimeUtils.formatDateWithSeconds(new Date())
    };
  }
}
