import {
  AgentActionType,
  AgentIntent,
  AgentLogEntry,
  AgentResponse,
  AgentSession,
  AgentSessionStatus,
  cloneAgentIntent,
  ConversationContext,
  emptyAgentIntent,
  emptyConversationContext,
  emptySkillResultData,
  emptyThinkingChain,
  IntentType,
  PaymentPreview,
  SkillResult,
  ThinkingChain,
  ThinkingStep,
  VoiceInputContext
} from './AgentModels';
import { ParsedIntent, PaymentMethod, PaymentResult, PaymentStatus, ProductCandidate, RecommendationResult } from '../models/ShoppingModels';
import { IntentEngine } from './IntentEngine';
import { AgentTaskDispatcher } from './AgentTaskDispatcher';
import { AgentSessionManager } from './AgentSessionManager';
import { ConversationManager } from './ConversationManager';
import { AgentLogger } from './AgentLogger';
import { SkillRegistry } from './SkillRegistry';
import { AgentThinkingEngine } from './AgentThinkingEngine';
import { PlatformProductGatewayService } from '../services/PlatformProductGatewayService';
import { agentIntentToParsedIntent, emptyProductCandidate, formatAgentTime } from './AgentModels';

export class ShoppingAgentOrchestrator {
  static process(input: string): AgentResponse {
    return ShoppingAgentOrchestrator.processWithVoice(input, undefined);
  }

  static processVoiceInput(text: string, confidence: number, partialText: string, language: string): AgentResponse {
    const voiceContext: VoiceInputContext = {
      isVoiceInput: true,
      confidence: confidence,
      partialText: partialText,
      language: language
    };
    return ShoppingAgentOrchestrator.processWithVoice(text, voiceContext);
  }

  static processWithVoice(input: string, voiceContext?: VoiceInputContext): AgentResponse {
    const startTime: number = Date.now();
    const sessionId: string = AgentSessionManager.isActive()
      ? AgentSessionManager.getSession().id
      : AgentSessionManager.startShopping(input).id;

    const context: ConversationContext = AgentSessionManager.getSession().conversationContext;
    if (context.sessionId.length === 0) {
      ConversationManager.startConversation(sessionId);
    }

    ConversationManager.addUserTurn(input);
    const intent: AgentIntent = IntentEngine.parse(input, ConversationManager.getContext(), voiceContext);
    ConversationManager.updatePendingIntent(intent);

    const dispatchResult = AgentTaskDispatcher.dispatch(intent, ConversationManager.getContext());

    let skillResult: SkillResult = dispatchResult.skillResult;
    if (!skillResult) {
      skillResult = {
        success: false,
        data: emptySkillResultData(),
        message: '处理失败',
        fallbackUsed: true
      };
    }

    ConversationManager.addAgentTurn(skillResult.message, intent);
    AgentSessionManager.updateConversationContext(ConversationManager.getContext());

    if (intent.type === IntentType.Compare && skillResult.success) {
      AgentSessionManager.moveToCompare();
    } else if (intent.type === IntentType.OrderConfirm && skillResult.success) {
      AgentSessionManager.moveToWaitingConfirm();
    } else if (intent.type === IntentType.Pay && skillResult.success) {
      AgentSessionManager.waitPayment();
    } else if (intent.type === IntentType.ProductSelect && skillResult.success) {
      AgentSessionManager.moveToWaitingConfirm();
    }

    const durationMs: number = Date.now() - startTime;
    const isVoice: boolean = voiceContext !== undefined && voiceContext.isVoiceInput;
    const logEntry: AgentLogEntry = AgentLogger.createEntry(
      sessionId,
      input,
      intent.type,
      dispatchResult.action,
      isVoice ? 'agent_voice_pipeline' : (skillResult.success ? 'agent_pipeline' : 'agent_fallback'),
      skillResult.message,
      durationMs,
      skillResult.fallbackUsed
    );
    AgentLogger.log(logEntry);

    return {
      intent: intent,
      action: dispatchResult.action,
      result: skillResult,
      session: AgentSessionManager.getSession(),
      supplementQuestions: dispatchResult.supplementQuestions,
      logEntry: logEntry,
      thinkingChain: emptyThinkingChain(),
      fallbackUsed: skillResult.fallbackUsed
    };
  }

  static async processWithThinking(input: string, voiceContext?: VoiceInputContext): Promise<AgentResponse> {
    const startTime: number = Date.now();
    const sessionId: string = AgentSessionManager.isActive()
      ? AgentSessionManager.getSession().id
      : AgentSessionManager.startShopping(input).id;

    let context: ConversationContext = AgentSessionManager.getSession().conversationContext;
    if (context.sessionId.length === 0) {
      ConversationManager.startConversation(sessionId);
      context = ConversationManager.getContext();
    }

    AgentSessionManager.clearThinkingData();

    let preIntent: AgentIntent = IntentEngine.parse(input, ConversationManager.getContext(), voiceContext);
    const isProductSelect: boolean = preIntent.type === IntentType.ProductSelect;

    if (!isProductSelect) {
      try {
        await PlatformProductGatewayService.refreshProductsFromPublicApi(input, 20);
      } catch (e) {
      }
    }

    let llmChain: ThinkingChain = emptyThinkingChain();
    let llmSuccess: boolean = false;

    if (AgentThinkingEngine.isLLMAvailable() && !isProductSelect) {
      try {
        llmChain = await AgentThinkingEngine.processWithThinking(input, context);
        AgentSessionManager.setThinkingChain(llmChain);
        if (llmChain.finalResponse.length > 0) {
          llmSuccess = true;
        }
      } catch (error) {
        AgentSessionManager.clearThinkingData();
      }
    }

    ConversationManager.addUserTurn(input);
    const intent: AgentIntent = IntentEngine.parse(input, ConversationManager.getContext(), voiceContext);
    ConversationManager.updatePendingIntent(intent);

    const dispatchResult = AgentTaskDispatcher.dispatch(intent, ConversationManager.getContext());
    let skillResult: SkillResult = dispatchResult.skillResult;
    if (!skillResult) {
      skillResult = {
        success: false,
        data: emptySkillResultData(),
        message: '处理失败',
        fallbackUsed: true
      };
    }

    ConversationManager.addAgentTurn(skillResult.message, intent);
    AgentSessionManager.updateConversationContext(ConversationManager.getContext());

    if (intent.type === IntentType.Compare && skillResult.success) {
      AgentSessionManager.moveToCompare();
    } else if (intent.type === IntentType.OrderConfirm && skillResult.success) {
      AgentSessionManager.moveToWaitingConfirm();
    } else if (intent.type === IntentType.Pay && skillResult.success) {
      AgentSessionManager.waitPayment();
    }

    const durationMs: number = Date.now() - startTime;
    const isVoice: boolean = voiceContext !== undefined && voiceContext.isVoiceInput;
    const logEntry: AgentLogEntry = AgentLogger.createEntry(
      sessionId, input, intent.type, dispatchResult.action,
      isVoice ? 'agent_voice_pipeline' : (llmSuccess ? 'agent_thinking' : (skillResult.success ? 'agent_pipeline' : 'agent_fallback')),
      skillResult.message, durationMs, skillResult.fallbackUsed
    );
    AgentLogger.log(logEntry);

    let finalMessage: string = skillResult.message;
    if (llmSuccess) {
      finalMessage = llmChain.finalResponse;
    }

    return {
      intent: intent,
      action: dispatchResult.action,
      result: {
        success: skillResult.success,
        data: skillResult.data,
        message: finalMessage,
        fallbackUsed: skillResult.fallbackUsed
      },
      session: AgentSessionManager.getSession(),
      supplementQuestions: dispatchResult.supplementQuestions,
      logEntry: logEntry,
      thinkingChain: llmChain,
      fallbackUsed: skillResult.fallbackUsed
    };
  }

  static processPayment(method?: PaymentMethod): AgentResponse {
    const startTime: number = Date.now();
    const sessionId: string = AgentSessionManager.getSession().id;
    const methodText: string = method ? ShoppingAgentOrchestrator.methodToText(method) : '华为支付';
    const input: string = method ? '使用' + methodText + '付款' : '付款';

    ConversationManager.addUserTurn(input);
    const intent: AgentIntent = emptyAgentIntent();
    intent.type = IntentType.Pay;
    intent.rawText = input;
    intent.confidence = 1.0;
    ConversationManager.updatePendingIntent(intent);

    if (method) {
      AgentSessionManager.setPaymentMethod(method);
    }

    const dispatchResult = AgentTaskDispatcher.dispatch(intent, ConversationManager.getContext());

    let skillResult: SkillResult = dispatchResult.skillResult;
    if (!skillResult) {
      skillResult = {
        success: false,
        data: emptySkillResultData(),
        message: '支付准备失败',
        fallbackUsed: true
      };
    }

    ConversationManager.addAgentTurn(skillResult.message, intent);
    AgentSessionManager.updateConversationContext(ConversationManager.getContext());

    if (skillResult.success) {
      AgentSessionManager.waitPayment();
    }

    const durationMs: number = Date.now() - startTime;
    const logEntry: AgentLogEntry = AgentLogger.createEntry(
      sessionId,
      input,
      IntentType.Pay,
      dispatchResult.action,
      'agent_payment',
      skillResult.message,
      durationMs,
      skillResult.fallbackUsed
    );
    AgentLogger.log(logEntry);

    return {
      intent: intent,
      action: dispatchResult.action,
      result: skillResult,
      session: AgentSessionManager.getSession(),
      supplementQuestions: dispatchResult.supplementQuestions,
      logEntry: logEntry,
      thinkingChain: emptyThinkingChain(),
      fallbackUsed: skillResult.fallbackUsed
    };
  }

  static getPaymentPreview(): PaymentPreview {
    const session: AgentSession = AgentSessionManager.getSession();
    const product: ProductCandidate = session.selectedProduct.id.length > 0
      ? session.selectedProduct
      : emptyProductCandidate();
    const quantity: number = session.quantity > 0 ? session.quantity : 1;
    return {
      product: product,
      quantity: quantity,
      totalPrice: product.price * quantity,
      availableMethods: [
        PaymentMethod.HuaWeiPay,
        PaymentMethod.Face,
        PaymentMethod.Fingerprint,
        PaymentMethod.Password
      ],
      recommendedMethod: session.paymentMethod,
      needsAddress: session.addressId.length === 0,
      ready: product.id.length > 0 && session.addressId.length > 0
    };
  }

  static parseIntent(input: string): ParsedIntent {
    const intent: AgentIntent = IntentEngine.parse(input);
    return agentIntentToParsedIntent(intent);
  }

  static compareProducts(intent: ParsedIntent): RecommendationResult {
    const agentIntent: AgentIntent = ShoppingAgentOrchestrator.parsedIntentToAgentIntent(intent);
    const context: ConversationContext = emptyConversationContext();
    SkillRegistry.ensureInitialized();
    const skill = SkillRegistry.findSkill(agentIntent);
    if (!skill) {
      return {
        intent: intent,
        bestProduct: {
          id: '', platform: '', name: '', price: 0, rating: 0, sales: 0,
          shopName: '', description: '', tags: [], recommendScore: 0
        },
        candidates: [],
        reason: '比价服务不可用',
        fallbackUsed: true
      };
    }
    const result: SkillResult = skill.execute(agentIntent, context);
    if (result.success && result.data.recommendation) {
      return result.data.recommendation;
    }
    return {
      intent: intent,
      bestProduct: {
        id: '', platform: '', name: '', price: 0, rating: 0, sales: 0,
        shopName: '', description: '', tags: [], recommendScore: 0
      },
      candidates: result.data.products,
      reason: result.message,
      fallbackUsed: true
    };
  }

  // 一键购物流水线：语音选择后自动串联选商品→确认地址→准备支付
  static processOneClickOrder(commandText: string): AgentResponse {
    const startTime: number = Date.now();
    const sessionId: string = AgentSessionManager.getSession().id;

    ConversationManager.addUserTurn(commandText);
    const intent: AgentIntent = IntentEngine.parse(commandText, ConversationManager.getContext());
    ConversationManager.updatePendingIntent(intent);

    // Step 1: 解析指令 → 选商品
    const candidates: ProductCandidate[] = AgentSessionManager.getSession().selectedProduct.id.length > 0
      ? [AgentSessionManager.getSession().selectedProduct]
      : [];
    const selectResult = AgentTaskDispatcher.dispatch(intent, ConversationManager.getContext());
    let skillResult: SkillResult = selectResult.skillResult
      ? selectResult.skillResult
      : { success: false, data: emptySkillResultData(), message: '指令解析失败', fallbackUsed: true };

    if (!skillResult.success) {
      return ShoppingAgentOrchestrator.buildResponse(startTime, sessionId, commandText, intent, selectResult.action, skillResult, false);
    }

    // Step 2: 自动确认订单（使用默认地址）
    const orderIntent: AgentIntent = emptyAgentIntent();
    orderIntent.type = IntentType.OrderConfirm;
    orderIntent.quantity = intent.quantity;
    orderIntent.rawText = commandText;
    orderIntent.confidence = 1.0;
    const orderResult = AgentTaskDispatcher.dispatch(orderIntent, ConversationManager.getContext());
    const orderSkillResult: SkillResult = orderResult.skillResult
      ? orderResult.skillResult
      : { success: false, data: emptySkillResultData(), message: '订单确认失败', fallbackUsed: true };

    ConversationManager.addAgentTurn(orderSkillResult.message, orderIntent);
    AgentSessionManager.updateConversationContext(ConversationManager.getContext());

    if (orderSkillResult.success) {
      AgentSessionManager.moveToWaitingConfirm();
    }

    // Step 3: 准备支付
    const payIntent: AgentIntent = emptyAgentIntent();
    payIntent.type = IntentType.Pay;
    payIntent.rawText = commandText;
    payIntent.confidence = 1.0;
    const payResult = AgentTaskDispatcher.dispatch(payIntent, ConversationManager.getContext());
    const paySkillResult: SkillResult = payResult.skillResult
      ? payResult.skillResult
      : { success: false, data: emptySkillResultData(), message: '支付准备失败', fallbackUsed: true };

    ConversationManager.addAgentTurn(paySkillResult.message, payIntent);
    AgentSessionManager.updateConversationContext(ConversationManager.getContext());

    if (paySkillResult.success) {
      AgentSessionManager.waitPayment();
    }

    return ShoppingAgentOrchestrator.buildResponse(startTime, sessionId, commandText, payIntent, payResult.action, paySkillResult, false);
  }

  private static buildResponse(
    startTime: number, sessionId: string, input: string,
    intent: AgentIntent, action: AgentActionType, skillResult: SkillResult, isVoice: boolean
  ): AgentResponse {
    const durationMs: number = Date.now() - startTime;
    const logEntry: AgentLogEntry = AgentLogger.createEntry(
      sessionId, input, intent.type, action,
      isVoice ? 'agent_voice_pipeline' : (skillResult.success ? 'agent_pipeline' : 'agent_fallback'),
      skillResult.message, durationMs, skillResult.fallbackUsed
    );
    AgentLogger.log(logEntry);
    return {
      intent: intent, action: action, result: skillResult,
      session: AgentSessionManager.getSession(),
      supplementQuestions: [], logEntry: logEntry,
      thinkingChain: emptyThinkingChain(),
      fallbackUsed: skillResult.fallbackUsed
    };
  }

  static getSupplementQuestions(input: string): string[] {
    const intent: AgentIntent = IntentEngine.parse(input);
    return intent.supplementQuestions.slice();
  }

  static getSession(): AgentSession {
    return AgentSessionManager.getSession();
  }

  static resetSession(): void {
    AgentSessionManager.reset();
    ConversationManager.clearContext();
  }

  static listLogs(sessionId: string): AgentLogEntry[] {
    return AgentLogger.listLogs(sessionId);
  }

  private static parsedIntentToAgentIntent(intent: ParsedIntent): AgentIntent {
    const agentIntent: AgentIntent = emptyAgentIntent();
    agentIntent.type = IntentType.Compare;
    agentIntent.product = intent.product;
    agentIntent.attributes = {
      color: '',
      size: '',
      material: '',
      features: intent.attributes,
      rawAttributes: []
    };
    agentIntent.quantity = intent.quantity;
    agentIntent.rawText = intent.rawText;
    agentIntent.confidence = 0.7;
    agentIntent.needsSupplement = false;
    agentIntent.supplementQuestions = [];
    return agentIntent;
  }

  private static methodToText(method: PaymentMethod): string {
    if (method === PaymentMethod.HuaWeiPay) {
      return '华为支付';
    }
    if (method === PaymentMethod.Face) {
      return '人脸支付';
    }
    if (method === PaymentMethod.Fingerprint) {
      return '指纹支付';
    }
    return '密码支付';
  }
}
