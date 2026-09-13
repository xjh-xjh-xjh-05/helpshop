import {
  AgentIntent,
  ConversationContext,
  ConversationTurn,
  emptyAgentIntent,
  emptyConversationContext,
  cloneAgentIntent,
  cloneConversationContext
} from './AgentModels';
import { AgentLogger } from './AgentLogger';
import { IntentEngine } from './IntentEngine';
import { TimeUtils } from '../utils/TimeUtils';

export class ConversationManager {
  private static context: ConversationContext = emptyConversationContext();

  static startConversation(sessionId: string): ConversationContext {
    ConversationManager.context = {
      sessionId: sessionId,
      turnIndex: 0,
      pendingIntent: emptyAgentIntent(),
      history: []
    };
    return ConversationManager.getContext();
  }

  static addUserTurn(text: string, roleType: string = 'elderly'): ConversationContext {
    const turn: ConversationTurn = {
      role: 'user',
      roleType: roleType,
      content: text,
      intent: emptyAgentIntent(),
      timestamp: TimeUtils.formatDateWithSeconds(new Date())
    };
    ConversationManager.context.history.push(turn);
    ConversationManager.context.turnIndex += 1;
    return ConversationManager.getContext();
  }

  static addAgentTurn(content: string, intent?: AgentIntent, roleType: string = 'elderly'): ConversationContext {
    const turn: ConversationTurn = {
      role: 'agent',
      roleType: roleType,
      content: content,
      intent: intent ? cloneAgentIntent(intent) : emptyAgentIntent(),
      timestamp: TimeUtils.formatDateWithSeconds(new Date())
    };
    ConversationManager.context.history.push(turn);
    ConversationManager.context.turnIndex += 1;
    return ConversationManager.getContext();
  }

  static getContext(): ConversationContext {
    return cloneConversationContext(ConversationManager.context);
  }

  static updatePendingIntent(intent: AgentIntent): void {
    ConversationManager.context.pendingIntent = cloneAgentIntent(intent);
  }

  static mergeSupplement(supplementText: string): AgentIntent {
    const pending: AgentIntent = cloneAgentIntent(ConversationManager.context.pendingIntent);
    if (pending.product.length === 0) {
      const emptyIntent: AgentIntent = emptyAgentIntent();
      emptyIntent.rawText = supplementText;
      return emptyIntent;
    }
    return IntentEngine.mergeSupplementIntent(pending, supplementText);
  }

  static clearContext(): void {
    ConversationManager.context = emptyConversationContext();
  }

  static hasPendingIntent(): boolean {
    return ConversationManager.context.pendingIntent.product.length > 0;
  }

  static getPendingIntent(): AgentIntent {
    return cloneAgentIntent(ConversationManager.context.pendingIntent);
  }
}
