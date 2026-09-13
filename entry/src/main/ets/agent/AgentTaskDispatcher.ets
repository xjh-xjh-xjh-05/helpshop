import {
  AgentActionType,
  AgentActionResult,
  AgentIntent,
  ConversationContext,
  emptyAgentIntent,
  emptySkillResultData,
  ExecutionStep,
  IntentType,
  SkillResult,
  SkillResultData,
  ThinkingStep,
  ToolResult
} from './AgentModels';
import { SkillRegistry } from './SkillRegistry';
import { ToolRegistry } from './ToolRegistry';
import { ConversationManager } from './ConversationManager';
import { AgentErrorHandler } from './AgentErrorHandler';
import { IntentEngine } from './IntentEngine';
import { AgentSessionManager } from './AgentSessionManager';
import { TimeUtils } from '../utils/TimeUtils';

export class AgentTaskDispatcher {
  static dispatch(intent: AgentIntent, context: ConversationContext): AgentActionResult {
    try {
      if (intent.type === IntentType.VoiceCommand) {
        const voiceResult: AgentActionResult = AgentTaskDispatcher.dispatchToSkill(intent, context);
        const normalizedText: string = voiceResult.skillResult.message;
        if (normalizedText.length > 0) {
          const reParsed: AgentIntent = IntentEngine.parse(normalizedText, context);
          if (reParsed.type !== IntentType.Unknown && reParsed.type !== IntentType.VoiceCommand) {
            return AgentTaskDispatcher.dispatch(reParsed, context);
          }
        }
        return voiceResult;
      }
      if (intent.type === IntentType.AdminQuery || intent.type === IntentType.CSAsk) {
        return AgentTaskDispatcher.dispatchToSkill(intent, context);
      }
      if (intent.type === IntentType.OrderQuery || intent.type === IntentType.AddressManage ||
          intent.type === IntentType.ReminderManage || intent.type === IntentType.FamilyBind) {
        return AgentTaskDispatcher.dispatchToSkill(intent, context);
      }
      if (intent.type === IntentType.Supplement) {
        const merged: AgentIntent = ConversationManager.mergeSupplement(intent.rawText);
        merged.type = IntentType.Compare;
        return AgentTaskDispatcher.dispatchToSkill(merged, context);
      }
      if (intent.type === IntentType.Unknown) {
        const fallbackResult: SkillResult = AgentErrorHandler.handleUnknownIntent(intent.rawText, context);
        return {
          action: AgentActionType.HandleError,
          skillResult: fallbackResult,
          supplementQuestions: ['请换个说法再试试，例如"我想买一双不累脚的鞋"。'],
          errorMessage: '无法识别您的意图'
        };
      }
      return AgentTaskDispatcher.dispatchToSkill(intent, context);
    } catch (error) {
      const fallbackResult: SkillResult = AgentErrorHandler.handle(
        new Error('调度异常'), intent, context
      );
      return {
        action: AgentActionType.HandleError,
        skillResult: fallbackResult,
        supplementQuestions: [],
        errorMessage: '处理过程中出现异常'
      };
    }
  }

  static dispatchThinkingChain(steps: ThinkingStep[], context: ConversationContext): AgentActionResult[] {
    const results: AgentActionResult[] = [];
    const actSteps: ThinkingStep[] = steps.filter(
      (s: ThinkingStep) => s.type === 'act' && s.toolName.length > 0
    );
    for (let i = 0; i < actSteps.length; i += 1) {
      const step: ThinkingStep = actSteps[i];
      const intent: AgentIntent = emptyAgentIntent();
      intent.rawText = step.content;
      intent.type = AgentTaskDispatcher.toolNameToIntentType(step.toolName);
      intent.confidence = 0.9;
      const toolResult: ToolResult = ToolRegistry.executeToolByName(step.toolName, step.toolArgs, context);
      const skillResult: SkillResult = AgentTaskDispatcher.toolResultToSkillResult(toolResult);
      results.push({
        action: AgentActionType.CallSkill,
        skillResult: skillResult,
        supplementQuestions: [],
        errorMessage: ''
      });
      ConversationManager.addAgentTurn(skillResult.message, intent);
      AgentSessionManager.updateConversationContext(ConversationManager.getContext());
    }
    return results;
  }

  static planMultiStep(intent: AgentIntent, context: ConversationContext): AgentActionResult[] {
    const results: AgentActionResult[] = [];
    const steps: AgentIntent[] = AgentTaskDispatcher.decomposeToSteps(intent);
    for (let i = 0; i < steps.length; i += 1) {
      const stepResult: AgentActionResult = AgentTaskDispatcher.dispatch(steps[i], context);
      results.push(stepResult);
      if (stepResult.skillResult.success) {
        ConversationManager.addAgentTurn(stepResult.skillResult.message, steps[i]);
        AgentSessionManager.updateConversationContext(ConversationManager.getContext());
        AgentTaskDispatcher.advanceSessionState(steps[i].type, stepResult.skillResult.success);
      } else {
        break;
      }
    }
    return results;
  }

  private static decomposeToSteps(intent: AgentIntent): AgentIntent[] {
    const steps: AgentIntent[] = [];
    if (intent.type === IntentType.Compare || intent.type === IntentType.Search) {
      steps.push(intent);
      const orderIntent: AgentIntent = emptyAgentIntent();
      orderIntent.type = IntentType.OrderConfirm;
      orderIntent.product = intent.product;
      orderIntent.quantity = intent.quantity;
      orderIntent.rawText = intent.rawText;
      orderIntent.confidence = 1.0;
      steps.push(orderIntent);
      return steps;
    }
    steps.push(intent);
    return steps;
  }

  private static advanceSessionState(type: IntentType, success: boolean): void {
    if (type === IntentType.Compare && success) {
      AgentSessionManager.moveToCompare();
    } else if (type === IntentType.OrderConfirm && success) {
      AgentSessionManager.moveToWaitingConfirm();
    } else if (type === IntentType.Pay && success) {
      AgentSessionManager.waitPayment();
    }
  }

  private static toolNameToIntentType(toolName: string): IntentType {
    if (toolName === 'search_product') { return IntentType.Search; }
    if (toolName === 'compare_product') { return IntentType.Compare; }
    if (toolName === 'confirm_order') { return IntentType.OrderConfirm; }
    if (toolName === 'prepare_payment') { return IntentType.Pay; }
    if (toolName === 'query_order') { return IntentType.OrderQuery; }
    if (toolName === 'manage_address') { return IntentType.AddressManage; }
    if (toolName === 'set_reminder') { return IntentType.ReminderManage; }
    if (toolName === 'bind_family') { return IntentType.FamilyBind; }
    if (toolName === 'query_admin') { return IntentType.AdminQuery; }
    if (toolName === 'query_cs') { return IntentType.CSAsk; }
    return IntentType.Unknown;
  }

  private static toolResultToSkillResult(toolResult: ToolResult): SkillResult {
    let data: SkillResultData = emptySkillResultData();
    if (toolResult.data.length > 0) {
      try {
        const parsed: SkillResultData = JSON.parse(toolResult.data) as SkillResultData;
        if (parsed) {
          data = parsed;
        }
      } catch (e) {
      }
    }
    return {
      success: toolResult.success,
      data: data,
      message: toolResult.message,
      fallbackUsed: !toolResult.success
    };
  }

  private static dispatchToSkill(intent: AgentIntent, context: ConversationContext): AgentActionResult {
    SkillRegistry.ensureInitialized();
    const skill = SkillRegistry.findSkill(intent);
    if (!skill) {
      const fallbackResult: SkillResult = AgentErrorHandler.handleUnknownIntent(intent.rawText, context);
      return {
        action: AgentActionType.HandleError,
        skillResult: fallbackResult,
        supplementQuestions: intent.supplementQuestions,
        errorMessage: '未找到匹配的处理能力'
      };
    }
    try {
      const result: SkillResult = skill.execute(intent, context);
      if (intent.needsSupplement && intent.supplementQuestions.length > 0) {
        return {
          action: AgentActionType.AskUser,
          skillResult: result,
          supplementQuestions: intent.supplementQuestions,
          errorMessage: ''
        };
      }
      return {
        action: AgentActionType.CallSkill,
        skillResult: result,
        supplementQuestions: [],
        errorMessage: ''
      };
    } catch (error) {
      const fallbackResult: SkillResult = AgentErrorHandler.handle(
        new Error('Skill 执行异常'), intent, context
      );
      return {
        action: AgentActionType.HandleError,
        skillResult: fallbackResult,
        supplementQuestions: [],
        errorMessage: '处理过程中出现异常'
      };
    }
  }
}
