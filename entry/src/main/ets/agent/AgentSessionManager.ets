import {
  AgentIntent,
  AgentSession,
  AgentSessionStatus,
  ConversationContext,
  emptyAgentIntent,
  emptyAgentSession,
  emptyConversationContext,
  emptyProductCandidate,
  cloneAgentSession,
  cloneAgentIntent,
  cloneConversationContext,
  formatAgentTime,
  ThinkingStep,
  ThinkingChain,
  ExecutionStep,
  emptyThinkingChain,
  emptyExecutionStep
} from './AgentModels';
import { PaymentMethod, PaymentResult, ProductCandidate, ShoppingSessionStatus } from '../models/ShoppingModels';

export class AgentSessionManager {
  private static currentSession: AgentSession = AgentSessionManager.createEmptySession();
  private static thinkingChain: ThinkingChain = emptyThinkingChain();
  private static executionSteps: ExecutionStep[] = [];

  private static createEmptySession(): AgentSession {
    return emptyAgentSession();
  }

  static startShopping(query: string, role: string = 'elderly'): AgentSession {
    const now: string = formatAgentTime(new Date());
    AgentSessionManager.currentSession = {
      id: 'session-' + Date.now().toString(),
      status: AgentSessionStatus.Shopping,
      role: role,
      query: query,
      selectedProductId: '',
      selectedProduct: emptyProductCandidate(),
      quantity: 1,
      addressId: '',
      paymentMethod: PaymentMethod.HuaWeiPay,
      conversationContext: {
        sessionId: 'session-' + Date.now().toString(),
        turnIndex: 0,
        pendingIntent: emptyAgentIntent(),
        history: []
      },
      createdAt: now,
      updatedAt: now
    };
    return AgentSessionManager.getSession();
  }

  static moveToCompare(): AgentSession {
    AgentSessionManager.currentSession.status = AgentSessionStatus.Comparing;
    AgentSessionManager.currentSession.updatedAt = formatAgentTime(new Date());
    return AgentSessionManager.getSession();
  }

  static selectProduct(productId: string): AgentSession {
    AgentSessionManager.currentSession.status = AgentSessionStatus.WaitingConfirm;
    AgentSessionManager.currentSession.selectedProductId = productId;
    AgentSessionManager.currentSession.updatedAt = formatAgentTime(new Date());
    return AgentSessionManager.getSession();
  }

  static moveToWaitingConfirm(): AgentSession {
    AgentSessionManager.currentSession.status = AgentSessionStatus.WaitingConfirm;
    AgentSessionManager.currentSession.updatedAt = formatAgentTime(new Date());
    return AgentSessionManager.getSession();
  }

  static setSelectedProduct(product: ProductCandidate, quantity: number): AgentSession {
    AgentSessionManager.currentSession.selectedProduct = {
      id: product.id,
      platform: product.platform,
      name: product.name,
      price: product.price,
      rating: product.rating,
      sales: product.sales,
      shopName: product.shopName,
      description: product.description,
      tags: product.tags.slice(),
      recommendScore: product.recommendScore,
      imageKey: product.imageKey,
      imageUrl: product.imageUrl
    };
    AgentSessionManager.currentSession.selectedProductId = product.id;
    AgentSessionManager.currentSession.quantity = quantity;
    AgentSessionManager.currentSession.updatedAt = formatAgentTime(new Date());
    return AgentSessionManager.getSession();
  }

  static setAddress(addressId: string): AgentSession {
    AgentSessionManager.currentSession.addressId = addressId;
    AgentSessionManager.currentSession.updatedAt = formatAgentTime(new Date());
    return AgentSessionManager.getSession();
  }

  static setProduct(product: ProductCandidate): AgentSession {
    AgentSessionManager.currentSession.selectedProduct = product;
    AgentSessionManager.currentSession.selectedProductId = product.id;
    AgentSessionManager.currentSession.updatedAt = formatAgentTime(new Date());
    return AgentSessionManager.getSession();
  }

  static setQuantity(quantity: number): AgentSession {
    AgentSessionManager.currentSession.quantity = quantity;
    AgentSessionManager.currentSession.updatedAt = formatAgentTime(new Date());
    return AgentSessionManager.getSession();
  }

  static setPaymentMethod(method: PaymentMethod): AgentSession {
    AgentSessionManager.currentSession.paymentMethod = method;
    AgentSessionManager.currentSession.updatedAt = formatAgentTime(new Date());
    return AgentSessionManager.getSession();
  }

  static waitPayment(): AgentSession {
    AgentSessionManager.currentSession.status = AgentSessionStatus.WaitingPayment;
    AgentSessionManager.currentSession.updatedAt = formatAgentTime(new Date());
    return AgentSessionManager.getSession();
  }

  static complete(paymentResult?: PaymentResult): AgentSession {
    AgentSessionManager.currentSession.status = AgentSessionStatus.Completed;
    AgentSessionManager.currentSession.updatedAt = formatAgentTime(new Date());
    return AgentSessionManager.getSession();
  }

  static reset(): AgentSession {
    AgentSessionManager.currentSession = AgentSessionManager.createEmptySession();
    AgentSessionManager.thinkingChain = emptyThinkingChain();
    AgentSessionManager.executionSteps = [];
    return AgentSessionManager.getSession();
  }

  static getSession(): AgentSession {
    return cloneAgentSession(AgentSessionManager.currentSession);
  }

  static updateConversationContext(context: ConversationContext): AgentSession {
    AgentSessionManager.currentSession.conversationContext = cloneConversationContext(context);
    AgentSessionManager.currentSession.updatedAt = formatAgentTime(new Date());
    return AgentSessionManager.getSession();
  }

  static updatePendingIntent(intent: AgentIntent): AgentSession {
    AgentSessionManager.currentSession.conversationContext.pendingIntent = cloneAgentIntent(intent);
    AgentSessionManager.currentSession.updatedAt = formatAgentTime(new Date());
    return AgentSessionManager.getSession();
  }

  static addThinkingStep(step: ThinkingStep): void {
    const chain: ThinkingChain = AgentSessionManager.thinkingChain;
    chain.steps.push(step);
    chain.totalSteps = chain.steps.length;
  }

  static setThinkingChain(chain: ThinkingChain): void {
    AgentSessionManager.thinkingChain = chain;
  }

  static getThinkingChain(): ThinkingChain {
    return AgentSessionManager.thinkingChain;
  }

  static addExecutionStep(step: ExecutionStep): void {
    AgentSessionManager.executionSteps.push(step);
  }

  static getExecutionSteps(): ExecutionStep[] {
    return AgentSessionManager.executionSteps.slice();
  }

  static clearThinkingData(): void {
    AgentSessionManager.thinkingChain = emptyThinkingChain();
    AgentSessionManager.executionSteps = [];
  }

  static isActive(): boolean {
    return AgentSessionManager.currentSession.status !== AgentSessionStatus.Idle;
  }

  static getStatus(): AgentSessionStatus {
    return AgentSessionManager.currentSession.status;
  }

  static toShoppingSessionStatus(status: AgentSessionStatus): ShoppingSessionStatus {
    if (status === AgentSessionStatus.Shopping) {
      return ShoppingSessionStatus.Comparing;
    }
    if (status === AgentSessionStatus.Comparing) {
      return ShoppingSessionStatus.Comparing;
    }
    if (status === AgentSessionStatus.WaitingConfirm) {
      return ShoppingSessionStatus.WaitingConfirm;
    }
    if (status === AgentSessionStatus.WaitingPayment) {
      return ShoppingSessionStatus.WaitingPayment;
    }
    if (status === AgentSessionStatus.Completed) {
      return ShoppingSessionStatus.Completed;
    }
    return ShoppingSessionStatus.Idle;
  }
}
